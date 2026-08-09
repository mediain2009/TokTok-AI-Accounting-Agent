import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../db_helper.dart';
import '../models.dart';
import 'ai_service.dart';
import 'kakao_play_mcp_service.dart';

/// openclaw 카카오톡 채널 릴레이 서비스
/// - 세션 생성 (페어링 코드 발급) → 사용자 /pair {code} 입력 → SSE로 메시지 수신
/// - 릴레이 서버: https://k.tess.dev (기본값)
/// - 카카오 채널: https://pf.kakao.com/_scexbC
class KakaoChannelService {
  static http.Client?        _client;
  static StreamSubscription? _sub;
  static bool                _running       = false;
  static Timer?              _reconnectTimer;

  // SSE 파싱 버퍼
  static String _curEvent = '';
  static String _curData  = '';

  /// UI 갱신 콜백 (main.dart에서 등록)
  static VoidCallback? onDocCreated;
  static VoidCallback? onInvoiceCreated;

  // ─── 세션 생성 (페어링 시작) ─────────────────────────────────────────
  /// 릴레이 서버에 세션을 생성하고 페어링 코드를 반환합니다.
  /// 반환: {sessionToken, pairingCode, expiresIn, status}
  static Future<Map<String, dynamic>> createSession(String relayUrl) async {
    final res = await http.post(
      Uri.parse('${_base(relayUrl)}/v1/sessions/create'),
      headers: {'Content-Type': 'application/json'},
    ).timeout(const Duration(seconds: 15));

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(body['error'] ?? '세션 생성 실패 (${res.statusCode})');
    }
    return body;
  }

  // ─── 세션 상태 확인 ─────────────────────────────────────────────────
  /// 반환: {status: "pending_pairing"|"paired"|"expired", pairedAt?, kakaoUserId?, accountId?}
  static Future<Map<String, dynamic>> getSessionStatus(
      String relayUrl, String sessionToken) async {
    final res = await http.get(
      Uri.parse('${_base(relayUrl)}/v1/sessions/$sessionToken/status'),
    ).timeout(const Duration(seconds: 10));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // ─── SSE 연결 시작 ───────────────────────────────────────────────────
  static Future<void> start() async {
    if (_running) return;
    _running = true;
    _connect();
  }

  static void stop() {
    _running = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _sub?.cancel();
    _sub = null;
    _client?.close();
    _client = null;
  }

  static bool get isRunning => _running;

  // ─── 내부: SSE 연결 ─────────────────────────────────────────────────
  static Future<void> _connect() async {
    if (!_running) return;

    final settings = await DbHelper.getMessengerSettings();
    if (settings == null ||
        !settings.kakaoEnabled ||
        settings.kakaoRelayToken.isEmpty) {
      _running = false;
      return;
    }

    final relayUrl = _base(settings.kakaoRelayUrl);
    final token    = settings.kakaoRelayToken;

    try {
      _client?.close();
      _client = http.Client();

      final request = http.Request('GET', Uri.parse('$relayUrl/v1/events'));
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept']        = 'text/event-stream';
      request.headers['Cache-Control'] = 'no-cache';

      final response = await _client!.send(request);

      if (response.statusCode == 401) {
        // 토큰 만료 → 중지 (재페어링 필요)
        _running = false;
        _client?.close();
        return;
      }
      if (response.statusCode != 200) {
        _scheduleReconnect();
        return;
      }

      _curEvent = '';
      _curData  = '';

      _sub = response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            _onLine,
            onDone:     _scheduleReconnect,
            onError:    (_) => _scheduleReconnect(),
            cancelOnError: false,
          );
    } catch (_) {
      _scheduleReconnect();
    }
  }

  static void _scheduleReconnect() {
    if (!_running) return;
    _sub?.cancel();
    _sub = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 15), _connect);
  }

  // ─── SSE 라인 파싱 ──────────────────────────────────────────────────
  static void _onLine(String line) {
    if (line.isEmpty) {
      // 빈 줄 = 이벤트 완성
      if (_curData.isNotEmpty) {
        _processEvent(_curEvent, _curData);
      }
      _curEvent = '';
      _curData  = '';
      return;
    }
    if (line.startsWith('event:')) {
      _curEvent = line.substring(6).trim();
    } else if (line.startsWith('data:')) {
      _curData = line.substring(5).trim();
    }
    // ': ping' 등 comment 라인 무시
  }

  // ─── 이벤트 처리 ────────────────────────────────────────────────────
  static void _processEvent(String eventType, String data) {
    if (eventType == 'message') {
      try {
        final map = jsonDecode(data) as Map<String, dynamic>;
        _handleMessage(map);
      } catch (_) {}
    }
    // connected, pairing_complete, pairing_expired 등은 무시
  }

  // ─── 메시지 처리 ────────────────────────────────────────────────────
  static Future<void> _handleMessage(Map<String, dynamic> eventData) async {
    final messageId = eventData['id'] as String?;
    if (messageId == null) return;

    // 카카오 페이로드에서 사용자 발화 추출
    String text = '';
    final raw = eventData['kakaoPayload'];
    Map<String, dynamic>? kakaoPayload;

    if (raw is Map<String, dynamic>) {
      kakaoPayload = raw;
    } else if (raw is String && raw.isNotEmpty) {
      try { kakaoPayload = jsonDecode(raw) as Map<String, dynamic>; } catch (_) {}
    }

    if (kakaoPayload != null) {
      text = kakaoPayload['userRequest']?['utterance'] as String? ?? '';
    }
    if (text.isEmpty) return;

    // 설정 재로드
    final settings = await DbHelper.getMessengerSettings();
    if (settings == null) return;
    final relayUrl = _base(settings.kakaoRelayUrl);
    final token    = settings.kakaoRelayToken;

    // /start, /help 커맨드
    if (text == '/start' || text == '/help' || text.startsWith('/pair')) {
      await _reply(relayUrl, token, messageId,
        '👋 톡톡AI,간편회계 봇입니다!\n\n'
        '자연어로 명령하시면 자동 처리됩니다.\n\n'
        '📝 예시:\n'
        '• "네오 모니터 2개 50만원 견적서 작성"\n'
        '• "ABC회사 컴퓨터 3대 200만원 거래명세표"\n'
        '• "오늘 매출 알려줘"\n\n'
        '⚙️ AI가 내용을 분석해 자동 등록합니다.',
      );
      return;
    }

    // AI 설정 확인
    final aiSettings = await DbHelper.getAiSettings();
    if (aiSettings == null ||
        (aiSettings.apiKey.isEmpty && aiSettings.provider != 'ollama')) {
      await _reply(relayUrl, token, messageId,
          '⚠️ AI 설정이 필요합니다.\n앱 → 기초설정 → AI 설정에서 API 키를 등록하세요.');
      return;
    }

    // 처리 중 메시지
    await _reply(relayUrl, token, messageId, '⏳ AI가 분석 중입니다...');

    try {
      final systemPrompt = AiService.buildSystemPrompt('카카오톡 채널');
      final aiResponse = await AiService.chat(
        settings:     aiSettings,
        history:      [AiMessage(role: 'user', content: text)],
        systemPrompt: systemPrompt,
      );

      final match = RegExp(r'\{[\s\S]*\}').firstMatch(aiResponse);
      if (match == null) {
        await _reply(relayUrl, token, messageId, aiResponse);
        return;
      }

      final data   = jsonDecode(match.group(0)!) as Map<String, dynamic>;
      final action = data['action'] as String?;

      switch (action) {
        case 'create_doc':
          await _handleCreateDoc(data, relayUrl, token, messageId);
          break;
        case 'answer':
          await _reply(relayUrl, token, messageId,
              (data['text'] as String?) ?? aiResponse);
          break;
        case 'register_invoice':
          await _handleRegisterInvoice(data, relayUrl, token, messageId);
          break;
        default:
          await _reply(relayUrl, token, messageId, aiResponse);
      }
    } catch (e) {
      await _reply(relayUrl, token, messageId, '❌ 처리 오류: $e');
    }
  }

  // ─── 문서 생성 ──────────────────────────────────────────────────────
  static Future<void> _handleCreateDoc(Map<String, dynamic> data,
      String relayUrl, String token, String messageId) async {
    final docType      = data['docType']      as String? ?? '견적서';
    final customerName = data['customerName'] as String? ?? '';
    final rawItems =
        (data['items'] as List? ?? []).cast<Map<String, dynamic>>();

    final docNo = await DbHelper.nextDocNo(docType);
    final today = DateTime.now().toString().substring(0, 10);

    final docItems = rawItems.map((it) {
      final qty    = (it['qty']   as num?)?.toInt() ?? 1;
      final price  = (it['price'] as num?)?.toInt() ?? 0;
      final supply = qty * price;
      final tax    = (supply * 0.1).round();
      return DocumentItem(
        docId: 0, itemName: (it['name'] as String?) ?? '',
        quantity: qty, unitPrice: price,
        supplyAmount: supply, taxAmount: tax,
      );
    }).toList();

    await DbHelper.insertDocument(
      Document(
        docType: docType, docNo: docNo,
        docDate: today,  customerName: customerName,
      ),
      docItems,
    );
    onDocCreated?.call();

    final supply    = docItems.fold(0, (s, i) => s + i.supplyAmount);
    final tax       = docItems.fold(0, (s, i) => s + i.taxAmount);
    final itemLines = docItems
        .map((i) => '  • ${i.itemName} ${i.quantity}개 × ${_fmt(i.unitPrice)}원')
        .join('\n');

    final replyMsg =
      '✅ $docType 등록 완료!\n\n'
      '📄 문서번호: $docNo\n'
      '🏢 거래처: ${customerName.isEmpty ? "(없음)" : customerName}\n'
      '📦 품목:\n$itemLines\n\n'
      '💰 공급가액: ${_fmt(supply)}원\n'
      '💵 합계: ${_fmt(supply + tax)}원\n\n'
      '앱 → 견적관리 → $docType 에서 확인하세요.';

    await _reply(relayUrl, token, messageId, replyMsg);

    // PlayMCP 나와의 채팅방 알림
    KakaoPlayMcpService.sendNotification(replyMsg).catchError((_) {});
  }

  // ─── 세금계산서 등록 ────────────────────────────────────────────────
  static Future<void> _handleRegisterInvoice(Map<String, dynamic> data,
      String relayUrl, String token, String messageId) async {
    final docNo     = data['docNo']     as String? ?? '';
    final direction = data['direction'] as String? ?? '매출';
    try {
      final srcDoc = await DbHelper.getDocumentByNo(docNo);
      if (srcDoc == null) {
        await _reply(relayUrl, token, messageId,
            '❌ 문서번호 $docNo 를 찾을 수 없습니다.');
        return;
      }
      final srcItems = await DbHelper.getDocumentItems(srcDoc.id!);

      int? partnerId;
      if (srcDoc.customerName.isNotEmpty) {
        final partners = await DbHelper.getPartners();
        final found    = partners.where((p) =>
            p.name.contains(srcDoc.customerName) ||
            srcDoc.customerName.contains(p.name)).toList();
        partnerId = found.isNotEmpty
            ? found.first.id
            : await DbHelper.insertPartner(Partner(
                name:       srcDoc.customerName,
                businessNo: srcDoc.customerBizNo,
                address:    srcDoc.customerAddress,
                phone:      srcDoc.customerContact,
              ));
      }

      await DbHelper.insertInvoice(
        Invoice(
          invoiceDate: srcDoc.docDate,
          direction:   direction,
          type:        '과세',
          partnerId:   partnerId,
          billType:    '영수',
          issueType:   '미발행',
          memo:        srcDoc.note,
        ),
        srcItems.map((di) => InvoiceItem(
          invoiceId:    0,
          itemName:     di.itemName,
          quantity:     di.quantity,
          unitPrice:    di.unitPrice,
          supplyAmount: di.supplyAmount,
          taxAmount:    di.taxAmount,
        )).toList(),
      );
      onInvoiceCreated?.call();

      final invoiceMsg =
        '✅ $direction 세금계산서 등록 완료!\n'
        '📄 원본: $docNo\n'
        '🏢 거래처: ${srcDoc.customerName}\n'
        '💵 합계: ${_fmt(srcDoc.totalAmount)}원\n\n'
        '앱 → 계산서 → 발행 → 미발행 에서 확인하세요.';

      await _reply(relayUrl, token, messageId, invoiceMsg);

      // PlayMCP 나와의 채팅방 알림
      KakaoPlayMcpService.sendNotification(invoiceMsg).catchError((_) {});
    } catch (e) {
      await _reply(relayUrl, token, messageId, '❌ 등록 오류: $e');
    }
  }

  // ─── 응답 전송 (카카오 simpleText) ──────────────────────────────────
  static Future<void> _reply(
      String relayUrl, String token, String messageId, String text) async {
    try {
      await http.post(
        Uri.parse('$relayUrl/openclaw/reply'),
        headers: {
          'Content-Type':  'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'messageId': messageId,
          'response': {
            'version': '2.0',
            'template': {
              'outputs': [
                {'simpleText': {'text': text}}
              ]
            }
          },
        }),
      ).timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  // ─── 유틸 ─────────────────────────────────────────────────────────
  static String _base(String url) {
    url = url.trim();
    if (url.isEmpty) return 'https://k.tess.dev';
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  static String _fmt(int n) {
    if (n == 0) return '0';
    final s   = n.abs().toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return (n < 0 ? '-' : '') + buf.toString();
  }
}
