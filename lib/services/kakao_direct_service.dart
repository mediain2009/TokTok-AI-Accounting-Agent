import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../db_helper.dart';
import '../models.dart';
import 'ai_service.dart';

/// 카카오톡 직접 연결 서비스
///
/// 외부 릴레이(k.tess.dev) 없이 카카오 공식 API를 직접 사용합니다.
///
/// [발신] 카카오 REST API — 나에게 메시지 보내기
///   POST https://kapi.kakao.com/v2/api/talk/memo/default/send
///   Authorization: Bearer {ACCESS_TOKEN}
///
/// [수신] 앱 내 내장 HTTP 서버 — 카카오 채널 OpenBuilder 스킬 서버 역할
///   카카오 채널 파트너센터 > OpenBuilder > 스킬 서버 URL을
///   http://{내 IP 또는 도메인}:{port}/kakao-webhook 으로 등록하면 수신 가능.
///   (포트포워딩 또는 ngrok 설정 필요)
///
/// 사전 준비:
///   1. developers.kakao.com 앱 등록 → REST API 키 발급
///   2. 카카오 로그인 동의항목: "카카오톡 나에게 보내기" 활성화
///   3. OAuth 인증 코드로 액세스 토큰 발급 후 앱에 입력
///   4. (수신 원할 시) 카카오 채널 개설 → OpenBuilder 스킬 서버 등록 → 포트포워딩
class KakaoDirectService {
  static const _sendMemoUrl =
      'https://kapi.kakao.com/v2/api/talk/memo/default/send';
  static const _refreshUrl =
      'https://kauth.kakao.com/oauth/token';

  static HttpServer? _server;
  static bool        _running = false;

  /// UI 갱신 콜백 (main.dart에서 등록)
  static VoidCallback? onDocCreated;
  static VoidCallback? onInvoiceCreated;

  // ─── 발신: 나에게 메시지 보내기 ────────────────────────────────────
  /// 카카오 REST API로 나와의 채팅방에 메시지 전송
  /// [accessToken]: 유효한 OAuth 액세스 토큰
  static Future<void> sendToMyChat(String accessToken, String text) async {
    // 카카오 나에게 보내기 — text 타입 메시지
    final templateObj = jsonEncode({
      'object_type': 'text',
      'text': text,
      'link': {
        'web_url': 'https://kakao.com',
        'mobile_web_url': 'https://kakao.com',
      },
    });

    final res = await http.post(
      Uri.parse(_sendMemoUrl),
      headers: {
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {'template_object': templateObj},
    ).timeout(const Duration(seconds: 15));

    if (res.statusCode == 401) {
      throw Exception('401: 토큰 만료');
    }
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body);
      throw Exception('카카오 API 오류: ${body['msg'] ?? res.statusCode}');
    }
  }

  /// DB 설정을 읽어 조건부 알림 전송 (401 시 토큰 갱신 자동 시도)
  static Future<void> sendNotification(String message) async {
    final settings = await DbHelper.getMessengerSettings();
    if (settings == null ||
        !settings.kakaoDirectNotify ||
        settings.kakaoDirectAccessToken.isEmpty) return;

    try {
      await sendToMyChat(settings.kakaoDirectAccessToken, message);
    } on Exception catch (e) {
      if (e.toString().contains('401') &&
          settings.kakaoDirectRefreshToken.isNotEmpty) {
        // 토큰 갱신 시도
        try {
          final tokens = await _refreshTokens(settings.kakaoDirectRefreshToken);
          final updated = MessengerSettings(
            id:                        settings.id,
            telegramBotToken:          settings.telegramBotToken,
            telegramChatId:            settings.telegramChatId,
            telegramEnabled:           settings.telegramEnabled,
            kakaoRelayUrl:             settings.kakaoRelayUrl,
            kakaoRelayToken:           settings.kakaoRelayToken,
            kakaoEnabled:              settings.kakaoEnabled,
            kakaoPlayMcpAccessToken:   settings.kakaoPlayMcpAccessToken,
            kakaoPlayMcpRefreshToken:  settings.kakaoPlayMcpRefreshToken,
            kakaoPlayMcpNotify:        settings.kakaoPlayMcpNotify,
            kakaoDirectAccessToken:    tokens.accessToken,
            kakaoDirectRefreshToken:   tokens.refreshToken.isNotEmpty
                                           ? tokens.refreshToken
                                           : settings.kakaoDirectRefreshToken,
            kakaoDirectNotify:         settings.kakaoDirectNotify,
            kakaoDirectBotEnabled:     settings.kakaoDirectBotEnabled,
            kakaoDirectPort:           settings.kakaoDirectPort,
          );
          await DbHelper.saveMessengerSettings(updated);
          await sendToMyChat(tokens.accessToken, message);
        } catch (_) {}
      }
    }
  }

  // ─── 수신: 내장 HTTP 서버 (채널 webhook) ────────────────────────────
  static Future<void> start() async {
    if (_running) return;
    _running = true;
    await _startServer();
  }

  static Future<void> stop() async {
    _running = false;
    await _server?.close(force: true);
    _server = null;
  }

  static bool get isRunning => _running;
  static int?  get serverPort => _server?.port;

  static Future<void> _startServer() async {
    if (!_running) return;

    final settings = await DbHelper.getMessengerSettings();
    if (settings == null ||
        !settings.kakaoDirectBotEnabled) {
      _running = false;
      return;
    }

    final port = settings.kakaoDirectPort;
    try {
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);
      _server!.listen(
        _handleRequest,
        onError: (e) async {
          await _server?.close(force: true);
          _server = null;
          if (_running) {
            await Future.delayed(const Duration(seconds: 10));
            await _startServer();
          }
        },
        cancelOnError: false,
      );
    } catch (e) {
      _running = false;
    }
  }

  // ─── HTTP 요청 처리 ─────────────────────────────────────────────────
  static Future<void> _handleRequest(HttpRequest req) async {
    // CORS / 메서드 필터
    if (req.method == 'GET' && req.uri.path == '/health') {
      req.response
        ..statusCode = 200
        ..write('OK')
        ..close();
      return;
    }
    if (req.method != 'POST') {
      req.response
        ..statusCode = 405
        ..close();
      return;
    }

    // 카카오 OpenBuilder 스킬 서버: POST /kakao-webhook
    try {
      final body = await utf8.decoder.bind(req).join();
      final Map<String, dynamic> payload =
          jsonDecode(body) as Map<String, dynamic>;
      final utterance =
          payload['userRequest']?['utterance'] as String? ?? '';

      if (utterance.isEmpty) {
        _writeResponse(req.response, '명령을 인식하지 못했습니다.');
        return;
      }

      // 처리 중 응답 먼저 반환 (카카오 5초 타임아웃 대응)
      // 실제 처리는 비동기로
      _writeResponse(req.response, '⏳ AI가 분석 중입니다...');

      // 비동기 처리
      _processUtterance(utterance);
    } catch (e) {
      _writeResponse(req.response, '❌ 요청 처리 오류: $e');
    }
  }

  static void _writeResponse(HttpResponse res, String text) {
    final body = jsonEncode({
      'version': '2.0',
      'template': {
        'outputs': [
          {
            'simpleText': {'text': text}
          }
        ],
      },
    });
    res
      ..statusCode = 200
      ..headers.contentType = ContentType.json
      ..write(body)
      ..close();
  }

  // ─── 발화 처리 공개 진입점 (PHP 릴레이 서비스 등 외부에서 호출) ────────
  static Future<void> processUtterance(String text, [String userId = '']) =>
      _processUtterance(text);

  // ─── 발화 처리 (AI + 문서 등록) ────────────────────────────────────
  static Future<void> _processUtterance(String text) async {
    final settings    = await DbHelper.getMessengerSettings();
    final aiSettings  = await DbHelper.getAiSettings();
    if (settings == null || aiSettings == null) return;

    final accessToken = settings.kakaoDirectAccessToken;

    // /start, /help 커맨드
    if (text == '/start' || text == '/help') {
      if (accessToken.isNotEmpty) {
        await sendToMyChat(accessToken,
          '👋 톡톡AI,간편회계 봇입니다!\n\n'
          '자연어로 명령하시면 자동 처리됩니다.\n\n'
          '📝 예시:\n'
          '• "네오 모니터 2개 50만원 견적서 작성"\n'
          '• "ABC회사 컴퓨터 3대 200만원 거래명세표"\n'
          '• "오늘 매출 알려줘"\n\n'
          '⚙️ AI가 내용을 분석해 자동 등록합니다.',
        );
      }
      return;
    }

    // AI 키 확인
    if (aiSettings.apiKey.isEmpty && aiSettings.provider != 'ollama') {
      if (accessToken.isNotEmpty) {
        await sendToMyChat(accessToken,
            '⚠️ AI 설정이 필요합니다.\n앱 → 기초설정 → AI 설정에서 API 키를 등록하세요.');
      }
      return;
    }

    try {
      final systemPrompt = AiService.buildSystemPrompt('카카오톡 직접');
      final aiResponse = await AiService.chat(
        settings:     aiSettings,
        history:      [AiMessage(role: 'user', content: text)],
        systemPrompt: systemPrompt,
      );

      final match = RegExp(r'\{[\s\S]*\}').firstMatch(aiResponse);
      if (match == null) {
        if (accessToken.isNotEmpty) {
          await sendToMyChat(accessToken, aiResponse);
        }
        return;
      }

      final data   = jsonDecode(match.group(0)!) as Map<String, dynamic>;
      final action = data['action'] as String?;

      switch (action) {
        case 'create_doc':
          await _handleCreateDoc(data, accessToken);
          break;
        case 'answer':
          if (accessToken.isNotEmpty) {
            await sendToMyChat(
                accessToken, (data['text'] as String?) ?? aiResponse);
          }
          break;
        case 'register_invoice':
          await _handleRegisterInvoice(data, accessToken);
          break;
        default:
          if (accessToken.isNotEmpty) {
            await sendToMyChat(accessToken, aiResponse);
          }
      }
    } catch (e) {
      if (settings.kakaoDirectAccessToken.isNotEmpty) {
        await sendToMyChat(settings.kakaoDirectAccessToken, '❌ 처리 오류: $e');
      }
    }
  }

  // ─── 문서 생성 ──────────────────────────────────────────────────────
  static Future<void> _handleCreateDoc(
      Map<String, dynamic> data, String accessToken) async {
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
        docId: 0,
        itemName: (it['name'] as String?) ?? '',
        quantity: qty,
        unitPrice: price,
        supplyAmount: supply,
        taxAmount: tax,
      );
    }).toList();

    await DbHelper.insertDocument(
      Document(
        docType: docType,
        docNo: docNo,
        docDate: today,
        customerName: customerName,
      ),
      docItems,
    );
    onDocCreated?.call();

    final supply    = docItems.fold(0, (s, i) => s + i.supplyAmount);
    final tax       = docItems.fold(0, (s, i) => s + i.taxAmount);
    final itemLines = docItems
        .map((i) => '  • ${i.itemName} ${i.quantity}개 × ${_fmt(i.unitPrice)}원')
        .join('\n');

    final msg =
      '✅ $docType 등록 완료!\n\n'
      '📄 문서번호: $docNo\n'
      '🏢 거래처: ${customerName.isEmpty ? "(없음)" : customerName}\n'
      '📦 품목:\n$itemLines\n\n'
      '💰 공급가액: ${_fmt(supply)}원\n'
      '💵 합계: ${_fmt(supply + tax)}원\n\n'
      '앱 → 견적관리 → $docType 에서 확인하세요.';

    if (accessToken.isNotEmpty) {
      await sendToMyChat(accessToken, msg).catchError((_) {});
    }
  }

  // ─── 세금계산서 등록 ────────────────────────────────────────────────
  static Future<void> _handleRegisterInvoice(
      Map<String, dynamic> data, String accessToken) async {
    final docNo     = data['docNo']     as String? ?? '';
    final direction = data['direction'] as String? ?? '매출';
    try {
      final srcDoc = await DbHelper.getDocumentByNo(docNo);
      if (srcDoc == null) {
        if (accessToken.isNotEmpty) {
          await sendToMyChat(
              accessToken, '❌ 문서번호 $docNo 를 찾을 수 없습니다.');
        }
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

      final msg =
        '✅ $direction 세금계산서 등록 완료!\n'
        '📄 원본: $docNo\n'
        '🏢 거래처: ${srcDoc.customerName}\n'
        '💵 합계: ${_fmt(srcDoc.totalAmount)}원\n\n'
        '앱 → 계산서 → 발행 → 미발행 에서 확인하세요.';

      if (accessToken.isNotEmpty) {
        await sendToMyChat(accessToken, msg).catchError((_) {});
      }
    } catch (e) {
      if (accessToken.isNotEmpty) {
        await sendToMyChat(accessToken, '❌ 등록 오류: $e').catchError((_) {});
      }
    }
  }

  // ─── 토큰 갱신 ──────────────────────────────────────────────────────
  /// 카카오 OAuth 리프레시 토큰으로 액세스 토큰 갱신
  /// [refreshToken]: 기존 리프레시 토큰
  /// 반환: (accessToken, refreshToken) — 새 리프레시 토큰이 없으면 빈 문자열
  static Future<({String accessToken, String refreshToken})> _refreshTokens(
      String refreshToken) async {
    // REST API 키는 DB에서 읽을 수 없으므로 앱에서 관리
    // (현재 구현에서는 토큰 갱신을 지원하려면 REST API 키도 저장해야 하나,
    //  간단 구현으로 리프레시 실패 시 사용자에게 재발급 안내)
    throw Exception('토큰 갱신 미지원: 앱에서 새 토큰을 재입력하세요.');
  }

  /// 인가 코드 → 액세스 토큰 발급 (OAuth 2.0 Authorization Code Flow)
  /// [restApiKey]: 카카오 developers.kakao.com REST API 키
  /// [code]: 카카오 로그인 후 리다이렉트 URL에서 추출한 인가 코드
  static Future<({String accessToken, String refreshToken})> exchangeCode({
    required String restApiKey,
    required String code,
    String redirectUri = 'https://localhost',
  }) async {
    final res = await http.post(
      Uri.parse('https://kauth.kakao.com/oauth/token'),
      headers: {'Content-Type': 'application/x-www-form-urlencoded;charset=utf-8'},
      body: {
        'grant_type':   'authorization_code',
        'client_id':    restApiKey,
        'redirect_uri': redirectUri,
        'code':         code,
      },
    ).timeout(const Duration(seconds: 15));

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception('토큰 발급 실패: ${body['error_description'] ?? body['error'] ?? res.statusCode}');
    }
    return (
      accessToken:  body['access_token']  as String,
      refreshToken: body['refresh_token'] as String? ?? '',
    );
  }

  /// 리프레시 토큰으로 액세스 토큰 갱신
  static Future<({String accessToken, String refreshToken})> refreshWithKey({
    required String restApiKey,
    required String refreshToken,
  }) async {
    final res = await http.post(
      Uri.parse(_refreshUrl),
      headers: {'Content-Type': 'application/x-www-form-urlencoded;charset=utf-8'},
      body: {
        'grant_type':    'refresh_token',
        'client_id':     restApiKey,
        'refresh_token': refreshToken,
      },
    ).timeout(const Duration(seconds: 15));

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception('갱신 실패: ${body['error_description'] ?? body['error'] ?? res.statusCode}');
    }
    return (
      accessToken:  body['access_token']  as String,
      refreshToken: body['refresh_token'] as String? ?? '',
    );
  }

  /// 카카오 OAuth 로그인 URL 생성
  static String buildAuthUrl(String restApiKey) {
    return 'https://kauth.kakao.com/oauth/authorize'
        '?client_id=$restApiKey'
        '&redirect_uri=https://localhost'
        '&response_type=code'
        '&scope=talk_message';
  }

  /// Windows/macOS/Linux 기본 브라우저로 URL 열기
  static Future<void> openBrowser(String url) async {
    // Windows cmd에서 &가 명령 구분자로 처리되므로 URL을 따옴표로 감쌈
    if (Platform.isWindows) {
      await Process.run('rundll32', ['url.dll,FileProtocolHandler', url]);
    } else if (Platform.isMacOS) {
      await Process.start('open', [url]);
    } else {
      await Process.start('xdg-open', [url]);
    }
  }

  // ─── 연결 테스트 (나에게 테스트 메시지) ────────────────────────────
  static Future<void> testSend(String accessToken) async {
    await sendToMyChat(
        accessToken, '✅ 톡톡AI,간편회계 연결 테스트 성공!\n카카오톡 직접 연결이 작동합니다.');
  }

  // ─── 유틸 ─────────────────────────────────────────────────────────
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
