import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../db_helper.dart';
import '../models.dart';
import '../services/telegram_service.dart';

class MessengerSettingsScreen extends StatefulWidget {
  const MessengerSettingsScreen({super.key});

  @override
  State<MessengerSettingsScreen> createState() => _MessengerSettingsScreenState();
}

class _MessengerSettingsScreenState extends State<MessengerSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  // Telegram
  final _tgTokenC  = TextEditingController();
  final _tgChatC   = TextEditingController();
  bool _tgEnabled  = false;
  bool _tgTesting  = false;
  String _tgStatus = '';

  // KakaoTalk
  final _kkApiC    = TextEditingController();
  final _kkSenderC = TextEditingController();
  final _kkPhoneC  = TextEditingController();
  bool _kkEnabled  = false;
  bool _kkTesting  = false;
  String _kkStatus = '';

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _tgTokenC.dispose(); _tgChatC.dispose();
    _kkApiC.dispose();   _kkSenderC.dispose(); _kkPhoneC.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final s = await DbHelper.getMessengerSettings();
    if (s == null) return;
    setState(() {
      _tgTokenC.text  = s.telegramBotToken;
      _tgChatC.text   = s.telegramChatId;
      _tgEnabled      = s.telegramEnabled;
      _kkApiC.text    = s.kakaoApiKey;
      _kkSenderC.text = s.kakaoSenderKey;
      _kkPhoneC.text  = s.kakaoPhoneNo;
      _kkEnabled      = s.kakaoEnabled;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await DbHelper.saveMessengerSettings(MessengerSettings(
        telegramBotToken: _tgTokenC.text.trim(),
        telegramChatId:   _tgChatC.text.trim(),
        telegramEnabled:  _tgEnabled,
        kakaoApiKey:      _kkApiC.text.trim(),
        kakaoSenderKey:   _kkSenderC.text.trim(),
        kakaoPhoneNo:     _kkPhoneC.text.trim(),
        kakaoEnabled:     _kkEnabled,
      ));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장 완료'), backgroundColor: Colors.green),
        );
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  // ── Telegram 연결 테스트 ─────────────────────────────────────────
  Future<void> _testTelegram() async {
    final token  = _tgTokenC.text.trim();
    final chatId = _tgChatC.text.trim();
    if (token.isEmpty || chatId.isEmpty) {
      setState(() => _tgStatus = '❌ Bot Token과 Chat ID를 입력하세요.');
      return;
    }
    setState(() { _tgTesting = true; _tgStatus = ''; });
    try {
      final url = Uri.parse('https://api.telegram.org/bot$token/sendMessage');
      final res = await http.post(url,
        headers: {'content-type': 'application/json'},
        body: jsonEncode({
          'chat_id': chatId,
          'text':    '✅ [톡톡AI,간편회계] 텔레그램 연결 테스트 성공!',
        }),
      ).timeout(const Duration(seconds: 15));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['ok'] == true) {
        setState(() => _tgStatus = '✅ 연결 성공! 텔레그램에서 메시지를 확인하세요.');
      } else {
        final desc = body['description'] as String? ?? '';
        String hint = '';
        if (desc.contains('bot') && desc.contains('send messages to the bot')) {
          hint = '\n\n💡 해결 방법: Chat ID가 봇 계정을 가리키고 있습니다.\n'
              '① 아래 [Chat ID 자동 조회]를 눌러 내 개인 Chat ID를 다시 가져오거나\n'
              '② Telegram에서 @userinfobot 에게 /start 를 보내면 내 ID를 알 수 있습니다.';
        } else if (desc.contains('chat not found')) {
          hint = '\n\n💡 해결 방법: 먼저 만든 봇(@봇이름)에게 /start 메시지를 보낸 후\n'
              '[Chat ID 자동 조회]를 클릭하세요.';
        } else if (desc.contains('Unauthorized') || desc.contains('token')) {
          hint = '\n\n💡 Bot Token이 올바르지 않습니다. @BotFather에서 다시 확인하세요.';
        }
        setState(() => _tgStatus = '❌ 오류: $desc$hint');
      }
    } catch (e) {
      setState(() => _tgStatus = '❌ 연결 실패: $e');
    } finally {
      setState(() => _tgTesting = false);
    }
  }

  // ── Chat ID 자동 조회 ────────────────────────────────────────────
  Future<void> _fetchChatId() async {
    final token = _tgTokenC.text.trim();
    if (token.isEmpty) {
      setState(() => _tgStatus = '❌ Bot Token을 먼저 입력하세요.');
      return;
    }
    setState(() { _tgTesting = true; _tgStatus = 'getUpdates 조회 중...'; });
    try {
      final url  = Uri.parse('https://api.telegram.org/bot$token/getUpdates?limit=20');
      final res  = await http.get(url).timeout(const Duration(seconds: 10));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['ok'] != true) {
        setState(() => _tgStatus = '❌ 오류: ${body['description']}');
        return;
      }

      final results = (body['result'] as List).cast<Map<String, dynamic>>();
      if (results.isEmpty) {
        setState(() => _tgStatus =
          '⚠️ 업데이트가 없습니다.\n\n'
          '① Telegram 앱에서 생성한 봇(@봇이름)을 검색\n'
          '② 봇과의 채팅창에서 /start 전송\n'
          '③ 이 버튼을 다시 클릭');
        return;
      }

      // 사람(user) 발신 메시지에서 chat.id 추출 (봇 제외)
      String? chatId;
      String? chatName;
      for (final upd in results.reversed) {
        final chat = upd['message']?['chat']
                  ?? upd['callback_query']?['message']?['chat'];
        if (chat == null) continue;
        final type = chat['type'] as String? ?? '';
        final id   = chat['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        // private = 개인 채팅, group = 그룹
        if (type == 'private' || type == 'group' || type == 'supergroup') {
          chatId   = id;
          chatName = chat['first_name'] as String?
                  ?? chat['title'] as String?
                  ?? id;
          break;
        }
      }

      if (chatId != null) {
        setState(() {
          _tgChatC.text = chatId!;
          _tgStatus = '✅ Chat ID 조회 성공!\nID: $chatId  (${chatName ?? ''})\n\n[테스트 메시지 전송]으로 확인하세요.';
        });
      } else {
        setState(() => _tgStatus =
          '⚠️ 개인/그룹 채팅을 찾을 수 없습니다.\n\n'
          '봇(@봇이름)에게 직접 /start 를 보낸 후 다시 시도하세요.\n'
          '또는 @userinfobot 에게 /start 를 보내 내 ID를 직접 확인할 수 있습니다.');
      }
    } catch (e) {
      setState(() => _tgStatus = '❌ 조회 실패: $e');
    } finally {
      setState(() => _tgTesting = false);
    }
  }

  // ── 카카오 연결 테스트 (카카오 알림톡 REST API) ──────────────────
  Future<void> _testKakao() async {
    setState(() { _kkTesting = true; _kkStatus = '카카오 API는 인증 토큰 발급 후 사용 가능합니다.'; });
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      _kkStatus = '⚠️ 카카오 알림톡은 비즈니스 채널 승인이 필요합니다.\n'
          'business.kakao.com 에서 채널 개설 후 사용하세요.';
      _kkTesting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('메신저 설정',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Telegram / 카카오톡 연동 설정',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              const SizedBox(height: 16),
              TabBar(
                controller: _tabCtrl,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                tabs: const [
                  Tab(icon: Icon(Icons.telegram, size: 18), text: 'Telegram'),
                  Tab(icon: Icon(Icons.chat_bubble, size: 18), text: '카카오톡'),
                ],
              ),
            ]),
          ),

          const Divider(height: 1),

          // 탭 내용
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildTelegramTab(),
                _buildKakaoTab(),
              ],
            ),
          ),

          // 저장 버튼
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                FilledButton.icon(
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(width: 14, height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.save, size: 16),
                  label: Text(_saving ? '저장 중...' : '저장'),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF0D6EFD),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Telegram 탭 ──────────────────────────────────────────────────
  Widget _buildTelegramTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 안내
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFF0088CC).withOpacity(0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF0088CC).withOpacity(0.3)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.info_outline, size: 16, color: Color(0xFF0088CC)),
              SizedBox(width: 6),
              Text('Telegram Bot 설정 방법',
                  style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF0088CC))),
            ]),
            const SizedBox(height: 8),
            _guideStep('1', '@BotFather 에서 /newbot 명령으로 봇 생성'),
            _guideStep('2', 'Bot Token 복사 후 아래에 입력'),
            _guideStep('3', '내 Telegram에서 생성한 봇(@봇이름)을 검색 → /start 전송'),
            _guideStep('4', '[Chat ID 자동 조회] 버튼 클릭'),
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Row(children: [
                Icon(Icons.lightbulb_outline, size: 14, color: Color(0xFF0088CC)),
                SizedBox(width: 6),
                Expanded(child: Text(
                  '내 Chat ID 확인: Telegram에서 @userinfobot 검색 → /start 전송',
                  style: TextStyle(fontSize: 12),
                )),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 24),

        // 활성화 스위치
        _sectionCard('기본 설정', [
          Row(children: [
            const Text('Telegram 알림 활성화',
                style: TextStyle(fontWeight: FontWeight.w500)),
            const Spacer(),
            Switch(
              value: _tgEnabled,
              onChanged: (v) => setState(() => _tgEnabled = v),
              activeColor: const Color(0xFF0088CC),
            ),
          ]),
        ]),
        const SizedBox(height: 16),

        // Bot Token
        _sectionCard('Bot Token', [
          _field('Bot Token', _tgTokenC,
              hint: '예) 7123456789:AAFxxxxxxxxxxxxxxxxxxxxxxxx',
              obscure: true),
        ]),
        const SizedBox(height: 16),

        // Chat ID
        _sectionCard('Chat ID', [
          _field('Chat ID', _tgChatC, hint: '예) 123456789 (숫자)'),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _tgTesting ? null : _fetchChatId,
            icon: const Icon(Icons.search, size: 16),
            label: const Text('Chat ID 자동 조회'),
          ),
        ]),
        const SizedBox(height: 16),

        // 테스트
        _sectionCard('연결 테스트', [
          FilledButton.icon(
            onPressed: _tgTesting ? null : _testTelegram,
            icon: _tgTesting
                ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send, size: 16),
            label: Text(_tgTesting ? '테스트 중...' : '테스트 메시지 전송'),
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF0088CC)),
          ),
          if (_tgStatus.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _tgStatus.startsWith('✅')
                    ? Colors.green.shade50
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: _tgStatus.startsWith('✅')
                      ? Colors.green.shade300
                      : Colors.orange.shade300,
                ),
              ),
              child: Text(_tgStatus, style: const TextStyle(fontSize: 13)),
            ),
          ],
        ]),

        const SizedBox(height: 24),
        // 폴링 상태
        _sectionCard('봇 수신 상태', [
          Row(children: [
            Container(
              width: 10, height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: TelegramService.isRunning ? Colors.green : Colors.grey,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              TelegramService.isRunning ? '수신 중 (5초 간격 폴링)' : '중지됨',
              style: TextStyle(
                fontSize: 13,
                color: TelegramService.isRunning ? Colors.green.shade700 : Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
          ]),
          const SizedBox(height: 8),
          const Text(
            '앱이 실행 중이면 텔레그램 메시지를 자동으로 수신합니다.\n'
            '"견적서 작성", "거래명세표 등록" 등 자연어로 입력하면\n'
            'AI가 분석해 앱에 자동 등록합니다.',
            style: TextStyle(fontSize: 12, color: Color(0xFF6C757D)),
          ),
        ]),
        const SizedBox(height: 16),

        // 알림 설정 안내
        _sectionCard('지원 명령어', [
          _notifyItem(Icons.edit_document,   '견적서 작성',     '"네오 모니터 2개 50만원 견적서 작성"'),
          _notifyItem(Icons.local_shipping,  '거래명세표 작성', '"ABC 컴퓨터 3대 200만원 거래명세표"'),
          _notifyItem(Icons.savings,         '입금표 작성',     '"입금표 등록해줘"'),
          _notifyItem(Icons.receipt_long,    '세금계산서 등록', '"DLV-xxx 매출작성에 등록해줘"'),
        ]),
      ]),
    );
  }

  // ── 카카오톡 탭 ──────────────────────────────────────────────────
  Widget _buildKakaoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFE812).withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFFFFE812).withOpacity(0.5)),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.warning_amber_outlined, size: 16, color: Color(0xFF846B00)),
              SizedBox(width: 6),
              Text('카카오 알림톡 설정 방법',
                  style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF846B00))),
            ]),
            const SizedBox(height: 8),
            _guideStep('1', 'business.kakao.com → 카카오톡 채널 개설'),
            _guideStep('2', '알림톡 발신 프로필 등록 및 비즈니스 인증'),
            _guideStep('3', 'kakao developers.kakao.com → 앱 생성 후 REST API 키 발급'),
            _guideStep('4', '발신 프로필 키(Sender Key)와 전화번호 입력'),
          ]),
        ),
        const SizedBox(height: 24),

        _sectionCard('기본 설정', [
          Row(children: [
            const Text('카카오톡 알림 활성화',
                style: TextStyle(fontWeight: FontWeight.w500)),
            const Spacer(),
            Switch(
              value: _kkEnabled,
              onChanged: (v) => setState(() => _kkEnabled = v),
              activeColor: const Color(0xFFFFE812),
            ),
          ]),
        ]),
        const SizedBox(height: 16),

        _sectionCard('API 정보', [
          _field('REST API 키', _kkApiC,
              hint: 'Kakao Developers에서 발급받은 REST API 키', obscure: true),
          const SizedBox(height: 12),
          _field('발신 프로필 키 (Sender Key)', _kkSenderC,
              hint: '알림톡 발신 프로필 키'),
          const SizedBox(height: 12),
          _field('발신 전화번호', _kkPhoneC,
              hint: '예) 01012345678 (하이픈 없이)'),
        ]),
        const SizedBox(height: 16),

        _sectionCard('연결 테스트', [
          FilledButton.icon(
            onPressed: _kkTesting ? null : _testKakao,
            icon: const Icon(Icons.chat_bubble, size: 16),
            label: Text(_kkTesting ? '테스트 중...' : '연결 테스트'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFFFE812),
              foregroundColor: Colors.black87,
            ),
          ),
          if (_kkStatus.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.yellow.shade50,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.yellow.shade400),
              ),
              child: Text(_kkStatus, style: const TextStyle(fontSize: 13)),
            ),
          ],
        ]),
      ]),
    );
  }

  // ── 헬퍼 위젯들 ──────────────────────────────────────────────────
  Widget _guideStep(String n, String text) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 18, height: 18,
        decoration: const BoxDecoration(
          color: Color(0xFF0088CC), shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(n,
            style: const TextStyle(color: Colors.white, fontSize: 10,
                fontWeight: FontWeight.bold)),
      ),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
    ]),
  );

  Widget _sectionCard(String title, List<Widget> children) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.grey.shade200),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13,
              color: Color(0xFF495057))),
      const SizedBox(height: 12),
      ...children,
    ]),
  );

  Widget _field(String label, TextEditingController ctrl,
      {String hint = '', bool obscure = false}) =>
      TextField(
        controller: ctrl,
        obscureText: obscure,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          suffixIcon: obscure
              ? IconButton(
                  icon: const Icon(Icons.content_copy, size: 16),
                  tooltip: '복사',
                  onPressed: () {},
                )
              : null,
        ),
      );

  Widget _notifyItem(IconData icon, String title, String sub) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(children: [
      Icon(icon, size: 18, color: const Color(0xFF0088CC)),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        Text(sub, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
      ]),
    ]),
  );
}
