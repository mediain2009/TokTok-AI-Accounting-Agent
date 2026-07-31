import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../db_helper.dart';
import '../models.dart';
import 'ai_service.dart';

/// 텔레그램 봇 폴링 서비스
/// 앱 실행 중 5초 간격으로 새 메시지를 확인하고 처리합니다.
class TelegramService {
  static Timer?        _timer;
  static int           _offset   = 0;
  static bool          _running  = false;

  /// UI 갱신 콜백 (main.dart에서 등록)
  static VoidCallback? onDocCreated;
  static VoidCallback? onInvoiceCreated;

  // ── 시작 / 중지 ───────────────────────────────────────────────────
  static Future<void> start() async {
    if (_running) return;
    _running = true;
    _timer   = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
    _poll(); // 즉시 첫 번째 폴링
  }

  static void stop() {
    _timer?.cancel();
    _timer   = null;
    _running = false;
  }

  static bool get isRunning => _running;

  // ── 폴링 ─────────────────────────────────────────────────────────
  static Future<void> _poll() async {
    final settings = await DbHelper.getMessengerSettings();
    if (settings == null ||
        !settings.telegramEnabled ||
        settings.telegramBotToken.isEmpty) return;

    try {
      final url = Uri.parse(
        'https://api.telegram.org/bot${settings.telegramBotToken}/getUpdates'
        '?offset=$_offset&timeout=0&limit=10',
      );
      final res  = await http.get(url).timeout(const Duration(seconds: 8));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['ok'] != true) return;

      final updates = (body['result'] as List).cast<Map<String, dynamic>>();
      for (final upd in updates) {
        _offset = (upd['update_id'] as int) + 1;
        await _processUpdate(upd, settings);
      }
    } catch (_) {
      // 네트워크 오류 → 조용히 무시, 다음 주기에 재시도
    }
  }

  // ── 업데이트 처리 ─────────────────────────────────────────────────
  static Future<void> _processUpdate(
      Map<String, dynamic> upd, MessengerSettings settings) async {
    final message = upd['message'] as Map<String, dynamic>?;
    if (message == null) return;

    final text   = message['text'] as String?;
    final chatId = message['chat']?['id']?.toString();
    if (text == null || chatId == null || text.isEmpty) return;

    // 인증된 Chat ID만 처리
    if (settings.telegramChatId.isNotEmpty &&
        chatId != settings.telegramChatId) {
      await _send(settings.telegramBotToken, chatId,
          '⚠️ 인증되지 않은 사용자입니다.');
      return;
    }

    await _handleText(text.trim(), chatId, settings.telegramBotToken);
  }

  // ── 메시지 처리 ───────────────────────────────────────────────────
  static Future<void> _handleText(
      String text, String chatId, String token) async {
    // /start, /help 커맨드
    if (text == '/start' || text == '/help') {
      await _send(token, chatId,
        '👋 톡톡AI,간편회계 봇입니다!\n\n'
        '자연어로 명령하시면 자동 처리됩니다.\n\n'
        '📝 예시:\n'
        '• "네오 모니터 2개 50만원 견적서 작성"\n'
        '• "ABC회사 컴퓨터 3대 200만원 거래명세표"\n'
        '• "오늘 매출 알려줘"\n\n'
        '⚙️ AI가 내용을 분석해 견적서/거래명세표/입금표를 자동 등록합니다.',
      );
      return;
    }

    // AI 설정 확인
    final aiSettings = await DbHelper.getAiSettings();
    if (aiSettings == null ||
        (aiSettings.apiKey.isEmpty && aiSettings.provider != 'ollama')) {
      await _send(token, chatId,
          '⚠️ AI 설정이 필요합니다.\n앱 → 기초설정 → AI 설정에서 API 키를 등록하세요.');
      return;
    }

    // 처리 중 메시지
    await _send(token, chatId, '⏳ AI가 분석 중입니다...');

    try {
      final systemPrompt = AiService.buildSystemPrompt('텔레그램 봇');
      final response = await AiService.chat(
        settings:     aiSettings,
        history:      [AiMessage(role: 'user', content: text)],
        systemPrompt: systemPrompt,
      );

      // JSON 추출
      final match = RegExp(r'\{[\s\S]*\}').firstMatch(response);
      if (match == null) {
        await _send(token, chatId, response);
        return;
      }

      final data   = jsonDecode(match.group(0)!) as Map<String, dynamic>;
      final action = data['action'] as String?;

      switch (action) {
        case 'create_doc':
          await _handleCreateDoc(data, token, chatId);
          break;
        case 'answer':
          await _send(token, chatId,
              (data['text'] as String?) ?? response);
          break;
        case 'navigate':
          await _send(token, chatId,
              '📱 앱에서 화면을 이동하려면 직접 탭해주세요.');
          break;
        case 'register_invoice':
          await _handleRegisterInvoice(data, token, chatId);
          break;
        default:
          await _send(token, chatId, response);
      }
    } catch (e) {
      await _send(token, chatId, '❌ 처리 오류: $e');
    }
  }

  // ── 문서 생성 ─────────────────────────────────────────────────────
  static Future<void> _handleCreateDoc(
      Map<String, dynamic> data, String token, String chatId) async {
    final docType      = data['docType']      as String? ?? '견적서';
    final customerName = data['customerName'] as String? ?? '';
    final rawItems     = (data['items'] as List? ?? [])
        .cast<Map<String, dynamic>>();

    final docNo = await DbHelper.nextDocNo(docType);
    final today = DateTime.now().toString().substring(0, 10);

    final docItems = rawItems.map((it) {
      final qty    = (it['qty']   as num?)?.toInt() ?? 1;
      final price  = (it['price'] as num?)?.toInt() ?? 0;
      final supply = qty * price;
      final tax    = (supply * 0.1).round();
      return DocumentItem(
        docId:        0,
        itemName:     (it['name'] as String?) ?? '',
        quantity:     qty,
        unitPrice:    price,
        supplyAmount: supply,
        taxAmount:    tax,
      );
    }).toList();

    final doc = Document(
      docType:      docType,
      docNo:        docNo,
      docDate:      today,
      customerName: customerName,
    );

    await DbHelper.insertDocument(doc, docItems);

    // UI 갱신 알림
    onDocCreated?.call();

    final supply = docItems.fold(0, (s, i) => s + i.supplyAmount);
    final tax    = docItems.fold(0, (s, i) => s + i.taxAmount);

    final itemLines = docItems
        .map((i) => '  • ${i.itemName} ${i.quantity}개 × ${_fmt(i.unitPrice)}원')
        .join('\n');

    await _send(token, chatId,
      '✅ $docType 등록 완료!\n\n'
      '📄 문서번호: $docNo\n'
      '🏢 거래처: ${customerName.isEmpty ? "(없음)" : customerName}\n'
      '📦 품목:\n$itemLines\n\n'
      '💰 공급가액: ${_fmt(supply)}원\n'
      '🧾 세액: ${_fmt(tax)}원\n'
      '💵 합계: ${_fmt(supply + tax)}원\n\n'
      '앱 → 견적관리 → $docType 에서 확인하세요.',
    );
  }

  // ── 세금계산서 등록 ───────────────────────────────────────────────
  static Future<void> _handleRegisterInvoice(
      Map<String, dynamic> data, String token, String chatId) async {
    final docNo     = data['docNo']     as String? ?? '';
    final direction = data['direction'] as String? ?? '매출';

    try {
      final srcDoc = await DbHelper.getDocumentByNo(docNo);
      if (srcDoc == null) {
        await _send(token, chatId, '❌ 문서번호 $docNo 를 찾을 수 없습니다.');
        return;
      }
      final srcItems = await DbHelper.getDocumentItems(srcDoc.id!);

      int? partnerId;
      if (srcDoc.customerName.isNotEmpty) {
        final partners = await DbHelper.getPartners();
        final found    = partners.where(
          (p) => p.name.contains(srcDoc.customerName) ||
                 srcDoc.customerName.contains(p.name),
        ).toList();
        if (found.isNotEmpty) {
          partnerId = found.first.id;
        } else {
          partnerId = await DbHelper.insertPartner(Partner(
            name:       srcDoc.customerName,
            businessNo: srcDoc.customerBizNo,
            address:    srcDoc.customerAddress,
            phone:      srcDoc.customerContact,
          ));
        }
      }

      final invoice = Invoice(
        invoiceDate: srcDoc.docDate,
        direction:   direction,
        type:        '과세',
        partnerId:   partnerId,
        billType:    '영수',
        issueType:   '미발행',
        txStatus:    '',
        memo:        srcDoc.note,
      );

      final invoiceItems = srcItems.map((di) => InvoiceItem(
        invoiceId:    0,
        itemName:     di.itemName,
        quantity:     di.quantity,
        unitPrice:    di.unitPrice,
        supplyAmount: di.supplyAmount,
        taxAmount:    di.taxAmount,
      )).toList();

      await DbHelper.insertInvoice(invoice, invoiceItems);
      onInvoiceCreated?.call();

      await _send(token, chatId,
        '✅ $direction 세금계산서 등록 완료!\n'
        '📄 원본: $docNo\n'
        '🏢 거래처: ${srcDoc.customerName}\n'
        '💵 합계: ${_fmt(srcDoc.totalAmount)}원\n\n'
        '앱 → 계산서 → 발행 → 미발행 에서 확인하세요.',
      );
    } catch (e) {
      await _send(token, chatId, '❌ 등록 오류: $e');
    }
  }

  // ── 메시지 전송 ───────────────────────────────────────────────────
  static Future<void> _send(
      String token, String chatId, String text) async {
    try {
      await http.post(
        Uri.parse('https://api.telegram.org/bot$token/sendMessage'),
        headers: {'content-type': 'application/json'},
        body: jsonEncode({'chat_id': chatId, 'text': text}),
      ).timeout(const Duration(seconds: 10));
    } catch (_) {}
  }

  // ── 숫자 포맷 ─────────────────────────────────────────────────────
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
