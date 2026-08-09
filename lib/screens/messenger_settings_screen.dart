import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../db_helper.dart';
import '../models.dart';
import '../services/telegram_service.dart';
import '../services/kakao_direct_service.dart';
import '../services/kakao_php_service.dart';

class MessengerSettingsScreen extends StatefulWidget {
  const MessengerSettingsScreen({super.key});

  @override
  State<MessengerSettingsScreen> createState() => _MessengerSettingsScreenState();
}

class _MessengerSettingsScreenState extends State<MessengerSettingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  // ── Telegram ──────────────────────────────────────────────────────
  final _tgTokenC  = TextEditingController();
  final _tgChatC   = TextEditingController();
  bool _tgEnabled  = false;
  bool _tgTesting  = false;
  String _tgStatus = '';

  // ── KakaoTalk 직접 연결 (자체 채널 + REST API) ─────────────────────
  final _directTokenC       = TextEditingController();
  final _directPortC        = TextEditingController(text: '18080');
  final _directRestApiKeyC  = TextEditingController();  // REST API 키 (토큰 발급용)
  final _directCodeC        = TextEditingController();  // 인가 코드 입력
  String _directAccessToken  = '';
  String _directRefreshToken = '';
  bool   _directNotify       = false;
  bool   _directBotEnabled   = false;
  bool   _directTesting      = false;
  bool   _directIssuing      = false;   // 토큰 발급 중
  String _directStatus       = '';

  // ── KakaoTalk PHP 릴레이 서버 ────────────────────────────────────────
  final _phpServerUrlC   = TextEditingController();
  final _phpApiKeyC      = TextEditingController();
  final _phpRestApiKeyC  = TextEditingController();  // 토큰 발급용 REST API 키
  final _phpCodeC        = TextEditingController();  // OAuth 코드 교환용
  final _phpSendUserIdC  = TextEditingController();  // 특정 1명 UUID
  bool   _phpEnabled     = false;
  bool   _phpTesting     = false;
  bool   _phpExchanging  = false;
  String _phpServerStatus = '';   // 서버 연결 설정 카드 상태
  String _phpTokenStatus  = '';   // 토큰 발급 카드 상태
  String _phpSendStatus   = '';   // 발신 카드 상태

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
    _directTokenC.dispose();
    _directPortC.dispose();
    _directRestApiKeyC.dispose();
    _directCodeC.dispose();
    _phpServerUrlC.dispose();
    _phpApiKeyC.dispose();
    _phpRestApiKeyC.dispose();
    _phpCodeC.dispose();
    _phpSendUserIdC.dispose();
    // 주의: 앱 전역(main.dart)에서 관리하는 백그라운드 폴링이므로
    // 이 화면을 나간다고 정지시키면 안 됨(카톡 수신이 끊기는 버그의 원인이었음).
    // 사용자가 토글을 꺼서 저장한 경우에만 _save()에서 stopPolling() 호출됨.
    super.dispose();
  }

  Future<void> _load() async {
    final s = await DbHelper.getMessengerSettings();
    if (s == null) return;
    setState(() {
      _tgTokenC.text    = s.telegramBotToken;
      _tgChatC.text     = s.telegramChatId;
      _tgEnabled        = s.telegramEnabled;
      // 직접 연결
      _directAccessToken  = s.kakaoDirectAccessToken;
      _directRefreshToken = s.kakaoDirectRefreshToken;
      _directNotify       = s.kakaoDirectNotify;
      _directBotEnabled   = s.kakaoDirectBotEnabled;
      _directPortC.text   = s.kakaoDirectPort.toString();
      if (_directAccessToken.isNotEmpty) {
        _directTokenC.text = _directAccessToken;
      }
      // PHP 릴레이
      _phpServerUrlC.text = s.kakaoPhpServerUrl;
      _phpApiKeyC.text    = s.kakaoPhpApiKey;
      _phpEnabled         = s.kakaoPhpEnabled;
      _phpSendUserIdC.text = s.kakaoPhpSendUserId;
    });
    // PHP 서비스 초기화
    final s2 = await DbHelper.getMessengerSettings();
    if (s2 != null && s2.kakaoPhpServerUrl.isNotEmpty) {
      KakaoPhpService().init(
        serverUrl: s2.kakaoPhpServerUrl,
        apiKey:    s2.kakaoPhpApiKey,
        enabled:   s2.kakaoPhpEnabled,
      );
      if (s2.kakaoPhpEnabled) KakaoPhpService().startPolling();
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await DbHelper.saveMessengerSettings(MessengerSettings(
        telegramBotToken:        _tgTokenC.text.trim(),
        telegramChatId:          _tgChatC.text.trim(),
        telegramEnabled:         _tgEnabled,
        kakaoDirectAccessToken:   _directAccessToken,
        kakaoDirectRefreshToken:  _directRefreshToken,
        kakaoDirectNotify:        _directNotify,
        kakaoDirectBotEnabled:    _directBotEnabled,
        kakaoDirectPort:          int.tryParse(_directPortC.text.trim()) ?? 18080,
        kakaoPhpServerUrl:        _phpServerUrlC.text.trim(),
        kakaoPhpApiKey:           _phpApiKeyC.text.trim(),
        kakaoPhpEnabled:          _phpEnabled,
        kakaoPhpSendUserId:       _phpSendUserIdC.text.trim(),
      ));
      // PHP 서비스 재초기화
      KakaoPhpService().init(
        serverUrl: _phpServerUrlC.text.trim(),
        apiKey:    _phpApiKeyC.text.trim(),
        enabled:   _phpEnabled,
      );
      if (_phpEnabled) {
        KakaoPhpService().startPolling();
      } else {
        KakaoPhpService().stopPolling();
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장 완료'), backgroundColor: Colors.green),
        );
      }
    } finally {
      setState(() => _saving = false);
    }
  }

  // ── Telegram 연결 테스트 ────────────────────────────────────────────
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
        body: jsonEncode({'chat_id': chatId, 'text': '✅ [톡톡AI,간편회계] 텔레그램 연결 테스트 성공!'}),
      ).timeout(const Duration(seconds: 15));
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (body['ok'] == true) {
        setState(() => _tgStatus = '✅ 연결 성공! 텔레그램에서 메시지를 확인하세요.');
      } else {
        final desc = body['description'] as String? ?? '';
        String hint = '';
        if (desc.contains('chat not found')) {
          hint = '\n\n💡 봇(@봇이름)에게 /start 를 보낸 후 [Chat ID 자동 조회]를 클릭하세요.';
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
          '① Telegram에서 생성한 봇(@봇이름)을 검색\n'
          '② 봇과의 채팅창에서 /start 전송\n'
          '③ 이 버튼을 다시 클릭');
        return;
      }
      String? chatId;
      String? chatName;
      for (final upd in results.reversed) {
        final chat = upd['message']?['chat'] ?? upd['callback_query']?['message']?['chat'];
        if (chat == null) continue;
        final type = chat['type'] as String? ?? '';
        final id   = chat['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        if (type == 'private' || type == 'group' || type == 'supergroup') {
          chatId   = id;
          chatName = chat['first_name'] as String? ?? chat['title'] as String? ?? id;
          break;
        }
      }
      if (chatId != null) {
        setState(() {
          _tgChatC.text = chatId!;
          _tgStatus = '✅ Chat ID 조회 성공!\nID: $chatId  (${chatName ?? ''})\n\n[테스트 메시지 전송]으로 확인하세요.';
        });
      } else {
        setState(() => _tgStatus = '⚠️ 개인/그룹 채팅을 찾을 수 없습니다.\n봇(@봇이름)에게 /start 를 보낸 후 다시 시도하세요.');
      }
    } catch (e) {
      setState(() => _tgStatus = '❌ 조회 실패: $e');
    } finally {
      setState(() => _tgTesting = false);
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // REMOVED: _startPairing, _cancelPairing, _disconnectKakao,
  //          _connectPlayMcp, _testPlayMcp, _disconnectPlayMcp
  // ─────────────────────────────────────────────────────────────────

  // ─────────────────────────────────────────────────────────────────
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
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [_buildTelegramTab(), _buildKakaoTab()],
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

  // ── Telegram 탭 ────────────────────────────────────────────────────
  Widget _buildTelegramTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _infoBox(
          color: const Color(0xFF0088CC),
          icon: Icons.info_outline,
          title: 'Telegram Bot 설정 방법',
          steps: [
            '@BotFather 에서 /newbot 명령으로 봇 생성',
            'Bot Token 복사 후 아래에 입력',
            '내 Telegram에서 생성한 봇(@봇이름)을 검색 → /start 전송',
            '[Chat ID 자동 조회] 버튼 클릭',
          ],
          tip: '내 Chat ID 확인: Telegram에서 @userinfobot 검색 → /start 전송',
        ),
        const SizedBox(height: 24),
        _sectionCard('기본 설정', [
          Row(children: [
            const Text('Telegram 알림 활성화', style: TextStyle(fontWeight: FontWeight.w500)),
            const Spacer(),
            Switch(
              value: _tgEnabled,
              onChanged: (v) => setState(() => _tgEnabled = v),
              activeColor: const Color(0xFF0088CC),
            ),
          ]),
        ]),
        const SizedBox(height: 16),
        _sectionCard('Bot Token', [
          _field('Bot Token', _tgTokenC,
              hint: '예) 7123456789:AAFxxxxxxxxxxxxxxxxxxxxxxxx', obscure: true),
        ]),
        const SizedBox(height: 16),
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
            _statusBox(_tgStatus),
          ],
        ]),
        const SizedBox(height: 24),
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
        _sectionCard('지원 명령어', [
          _notifyItem(Icons.edit_document,  '견적서 작성',     '"네오 모니터 2개 50만원 견적서 작성"'),
          _notifyItem(Icons.local_shipping, '거래명세표 작성', '"ABC 컴퓨터 3대 200만원 거래명세표"'),
          _notifyItem(Icons.savings,        '입금표 작성',     '"입금표 등록해줘"'),
          _notifyItem(Icons.receipt_long,   '세금계산서 등록', '"DLV-xxx 매출작성에 등록해줘"'),
        ]),
      ]),
    );
  }

  // ── 카카오톡 탭 ──────────────────────────────────────────────────────
  Widget _buildKakaoTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // 직접 연결 섹션 (REST API + 내장 서버)
        _sectionLabel(Icons.api, '🔗 카카오 REST API 직접 연결', '카카오 공식 API로 직접 입출력 연결',
            const Color(0xFF3F51B5)),
        const SizedBox(height: 10),
        _buildDirectSection(),
        const SizedBox(height: 28),

        // PHP 릴레이 서버 섹션
        _sectionLabel(Icons.dns, '🌐 PHP 릴레이 서버 (VPS)', 'VPS 경유 1:1 카카오 메시지 송수신',
            const Color(0xFF2E7D32)),
        const SizedBox(height: 10),
        _buildPhpSection(),
        const SizedBox(height: 20),
      ]),
    );
  }

  Widget _sectionLabel(IconData icon, String title, String sub, Color color) {
    return Row(children: [
      Container(width: 3, height: 36, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
      const SizedBox(width: 10),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: color)),
        Text(sub, style: const TextStyle(fontSize: 11, color: Color(0xFF6C757D))),
      ]),
    ]);
  }

  // ── 직접 연결 섹션 ────────────────────────────────────────────────────
  Widget _buildDirectSection() {
    final bool hasToken = _directAccessToken.isNotEmpty;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // 안내 박스
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFE8EAF6),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF3F51B5).withOpacity(0.3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.api, size: 14, color: Color(0xFF3F51B5)),
            SizedBox(width: 6),
            Text('카카오 REST API 직접 연결 준비',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF3F51B5))),
          ]),
          const SizedBox(height: 8),
          _step('1', 'developers.kakao.com → 앱 생성 → REST API 키 확인'),
          _step('2', '카카오 로그인 활성화 → 동의항목: "카카오톡 나에게 보내기" 설정'),
          _step('3', '[도구] > [REST API 테스트] → 액세스 토큰 발급'),
          _step('4', '아래에 액세스 토큰 입력 후 저장'),
          const SizedBox(height: 6),
          const Text(
            '수신(채팅봇)은 자체 카카오 채널 + OpenBuilder + 포트포워딩이 추가로 필요합니다.',
            style: TextStyle(fontSize: 11, color: Color(0xFF5C6BC0)),
          ),
        ]),
      ),
      const SizedBox(height: 12),

      // ── 카카오 로그인 (토큰 발급) 카드 ──────────────────────────────
      _sectionCard('🔑 카카오 로그인 (액세스 토큰 발급)', [
        // REST API 키 입력
        TextField(
          controller: _directRestApiKeyC,
          decoration: InputDecoration(
            labelText: 'REST API 키',
            hintText: 'developers.kakao.com → 앱 → 플랫폼 키',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 12),

        // 1단계: 브라우저로 로그인
        Row(children: [
          Expanded(
            child: FilledButton.icon(
              onPressed: () async {
                final key = _directRestApiKeyC.text.trim();
                if (key.isEmpty) {
                  setState(() => _directStatus = '❌ REST API 키를 입력하세요.');
                  return;
                }
                final url = KakaoDirectService.buildAuthUrl(key);
                try {
                  await KakaoDirectService.openBrowser(url);
                  setState(() => _directStatus =
                    '✅ 브라우저가 열렸습니다.\n\n'
                    '카카오 계정으로 로그인 후 리다이렉트된\n'
                    'URL(https://localhost?code=...)에서\n'
                    '"code=" 뒤의 값을 복사하여 아래에 붙여넣으세요.');
                } catch (e) {
                  // 브라우저 열기 실패 시 URL 직접 표시
                  setState(() => _directStatus =
                    '아래 URL을 브라우저에 직접 붙여넣으세요:\n\n$url');
                }
              },
              icon: const Icon(Icons.open_in_browser, size: 16),
              label: const Text('① 브라우저에서 카카오 로그인'),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFFBF00),
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ]),
        const SizedBox(height: 10),

        // 2단계: 인가 코드 입력 + 토큰 발급
        Row(children: [
          Expanded(
            child: TextField(
              controller: _directCodeC,
              decoration: InputDecoration(
                labelText: '② 인가 코드 입력 (code=... 뒤의 값)',
                hintText: '예) 3GQRzE3p_xxxxxxxxxxxxxxxxxxxxxxxx',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _directIssuing ? null : () async {
              final key  = _directRestApiKeyC.text.trim();
              final code = _directCodeC.text.trim();
              if (key.isEmpty || code.isEmpty) {
                setState(() => _directStatus = '❌ REST API 키와 인가 코드를 모두 입력하세요.');
                return;
              }
              setState(() { _directIssuing = true; _directStatus = '토큰 발급 중...'; });
              try {
                final tokens = await KakaoDirectService.exchangeCode(
                  restApiKey: key, code: code,
                );
                setState(() {
                  _directAccessToken  = tokens.accessToken;
                  _directRefreshToken = tokens.refreshToken;
                  _directNotify       = true;
                  _directTokenC.text  = tokens.accessToken;
                  _directCodeC.clear();
                  _directStatus = '✅ 액세스 토큰 발급 성공!\n저장 버튼을 눌러 저장하세요.';
                });
                await _save();
              } catch (e) {
                setState(() => _directStatus = '❌ 발급 실패: $e');
              } finally {
                setState(() => _directIssuing = false);
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF3F51B5),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            child: _directIssuing
                ? const SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('③ 토큰 발급'),
          ),
        ]),

        if (_directStatus.isNotEmpty) ...[
          const SizedBox(height: 10),
          _statusBox(_directStatus),
        ],
      ]),
      const SizedBox(height: 12),

      // 발신 설정 카드
      _sectionCard('📤 발신 설정 (나에게 메시지 보내기)', [
        // 연결 상태
        Row(children: [
          _statusDot(hasToken ? Colors.green : Colors.grey),
          const SizedBox(width: 8),
          Expanded(child: Text(
            hasToken ? '액세스 토큰 설정됨 — 나에게 보내기 준비' : '미설정',
            style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w500,
              color: hasToken ? Colors.green.shade700 : Colors.grey,
            ),
          )),
          if (hasToken)
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _directAccessToken  = '';
                  _directRefreshToken = '';
                  _directNotify       = false;
                  _directTokenC.clear();
                  _directStatus       = '';
                });
                _save();
              },
              icon: const Icon(Icons.link_off, size: 14, color: Colors.red),
              label: const Text('해제', style: TextStyle(color: Colors.red, fontSize: 12)),
              style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
            ),
        ]),
        const Divider(height: 20),

        // 알림 ON/OFF (연결됐을 때만)
        if (hasToken) ...[
          Row(children: [
            const Text('이벤트 알림 전송', style: TextStyle(fontWeight: FontWeight.w500)),
            const Spacer(),
            Switch(
              value: _directNotify,
              onChanged: (v) { setState(() => _directNotify = v); _save(); },
              activeColor: const Color(0xFF3F51B5),
            ),
          ]),
          const Text('문서·계산서 등록 시 나와의 채팅방으로 자동 알림',
              style: TextStyle(fontSize: 11, color: Colors.grey)),
          const Divider(height: 20),
        ],

        // 액세스 토큰 입력
        TextField(
          controller: _directTokenC,
          obscureText: true,
          decoration: InputDecoration(
            labelText: '카카오 OAuth 액세스 토큰',
            hintText: 'developers.kakao.com에서 발급한 액세스 토큰',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 12),

        // 저장 + 테스트 버튼
        Row(children: [
          FilledButton.icon(
            onPressed: _directTesting ? null : () async {
              final token = _directTokenC.text.trim();
              if (token.isEmpty) {
                setState(() => _directStatus = '❌ 액세스 토큰을 입력하세요.');
                return;
              }
              setState(() {
                _directAccessToken = token;
                _directNotify      = true;
                _directStatus      = '';
              });
              await _save();
              setState(() => _directStatus = '✅ 토큰이 저장되었습니다.');
            },
            icon: const Icon(Icons.save, size: 16),
            label: const Text('토큰 저장'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF3F51B5),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
          ),
          const SizedBox(width: 8),
          if (hasToken)
            OutlinedButton.icon(
              onPressed: _directTesting ? null : _testDirectSend,
              icon: _directTesting
                  ? const SizedBox(width: 12, height: 12,
                        child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.send, size: 14),
              label: Text(_directTesting ? '전송 중...' : '테스트 전송'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF3F51B5),
                side: const BorderSide(color: Color(0xFF3F51B5)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              ),
            ),
        ]),

        if (_directStatus.isNotEmpty) ...[
          const SizedBox(height: 10),
          _statusBox(_directStatus),
        ],
      ]),
      const SizedBox(height: 12),

      // 수신 설정 카드 (내장 HTTP 서버)
      _sectionCard('📥 수신 설정 (채팅봇 내장 서버)', [
        // 서버 상태
        Row(children: [
          _statusDot(KakaoDirectService.isRunning ? Colors.green : Colors.grey),
          const SizedBox(width: 8),
          Expanded(child: Text(
            KakaoDirectService.isRunning
                ? '서버 실행 중 (포트 ${KakaoDirectService.serverPort ?? '?'})'
                : (_directBotEnabled ? '채팅봇 시작 중...' : '서버 중지됨'),
            style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w500,
              color: KakaoDirectService.isRunning ? Colors.green.shade700 : Colors.grey,
            ),
          )),
        ]),
        const Divider(height: 20),

        // 채팅봇 ON/OFF
        Row(children: [
          const Text('채팅봇 활성화 (내장 HTTP 서버)', style: TextStyle(fontWeight: FontWeight.w500)),
          const Spacer(),
          Switch(
            value: _directBotEnabled,
            onChanged: hasToken ? (v) async {
              setState(() => _directBotEnabled = v);
              await _save();
              if (v) {
                KakaoDirectService.stop();
                KakaoDirectService.start();
              } else {
                KakaoDirectService.stop();
              }
              setState(() {});
            } : null,
            activeColor: const Color(0xFF3F51B5),
          ),
        ]),
        const SizedBox(height: 8),

        // 포트 설정
        Row(children: [
          const Text('서버 포트:', style: TextStyle(fontSize: 13)),
          const SizedBox(width: 10),
          SizedBox(
            width: 100,
            child: TextField(
              controller: _directPortC,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
            ),
          ),
          const SizedBox(width: 10),
          const Text('(기본: 18080)', style: TextStyle(fontSize: 12, color: Colors.grey)),
        ]),
        const SizedBox(height: 12),

        // 수신 안내
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.info_outline, size: 13, color: Colors.blue),
              SizedBox(width: 4),
              Text('채팅봇 수신 설정 방법',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Colors.blue)),
            ]),
            const SizedBox(height: 6),
            _step('1', '카카오 채널 파트너센터(center-pf.kakao.com)에서 채널 개설'),
            _step('2', 'OpenBuilder → 스킬 서버 URL 등록:'),
            const Padding(
              padding: EdgeInsets.only(left: 18, top: 2, bottom: 2),
              child: SelectableText(
                'http://{내 IP}:{포트}/kakao-webhook',
                style: TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            _step('3', '포트포워딩(공유기) 또는 ngrok으로 외부 접근 가능하게 설정'),
            const SizedBox(height: 4),
            const Text('포트포워딩 설정 없이도 발신(나에게 보내기)은 즉시 사용 가능합니다.',
                style: TextStyle(fontSize: 11, color: Color(0xFF1565C0))),
          ]),
        ),
      ]),
    ]);
  }

  Future<void> _testDirectSend() async {
    if (_directAccessToken.isEmpty) return;
    setState(() { _directTesting = true; _directStatus = '테스트 메시지 전송 중...'; });
    try {
      await KakaoDirectService.testSend(_directAccessToken);
      setState(() => _directStatus = '✅ 테스트 전송 완료! 카카오톡 나와의 채팅방을 확인하세요.');
    } catch (e) {
      setState(() => _directStatus = '❌ 전송 실패: $e\n\n액세스 토큰이 만료되었거나 올바르지 않습니다.\n새 토큰을 발급 후 재입력하세요.');
    } finally {
      setState(() => _directTesting = false);
    }
  }

  // ── PHP 릴레이 서버 섹션 ─────────────────────────────────────────────
  Widget _buildPhpSection() {
    final svc = KakaoPhpService();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

      // ── 안내 박스 ────────────────────────────────────────────────────
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFE8F5E9),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF2E7D32).withOpacity(0.3)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Row(children: [
            Icon(Icons.dns, size: 14, color: Color(0xFF2E7D32)),
            SizedBox(width: 6),
            Text('PHP 릴레이 서버 설정 순서',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF2E7D32))),
          ]),
          const SizedBox(height: 8),
          _step('1', 'VPS 에 kakao_relay/ 폴더 업로드'),
          _step('2', 'MySQL 에서 setup.sql 실행'),
          _step('3', 'config.php — DB 정보·API_KEY 수정'),
          _step('4', '아래에 서버 URL·API 키 입력 후 저장'),
          _step('5', '토큰 발급 후 활성화'),
          const SizedBox(height: 6),
          const Text(
            '수신: OpenBuilder 스킬 URL → https://yourdomain.com/kakao_relay/skill.php',
            style: TextStyle(fontSize: 11, color: Color(0xFF1B5E20)),
          ),
        ]),
      ),
      const SizedBox(height: 12),

      // ── 서버 설정 카드 ────────────────────────────────────────────────
      _sectionCard('⚙️ 서버 연결 설정', [
        _field('PHP 서버 URL', _phpServerUrlC,
            hint: '예) https://yourdomain.com/kakao_relay'),
        const SizedBox(height: 10),
        _field('API 키', _phpApiKeyC,
            hint: 'config.php 의 API_KEY 와 동일', obscure: true),
        const SizedBox(height: 12),

        // 활성화 스위치
        Row(children: [
          const Text('PHP 릴레이 활성화', style: TextStyle(fontWeight: FontWeight.w500)),
          const Spacer(),
          Switch(
            value: _phpEnabled,
            onChanged: (v) => setState(() => _phpEnabled = v),
            activeColor: const Color(0xFF2E7D32),
          ),
        ]),
        const Text('활성화 시 5초마다 수신 메시지를 자동 폴링합니다.',
            style: TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 12),

        // 저장 + 연결 테스트
        Row(children: [
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save, size: 16),
            label: const Text('저장'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            ),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            onPressed: _phpTesting ? null : () async {
              final url = _phpServerUrlC.text.trim();
              final key = _phpApiKeyC.text.trim();
              if (url.isEmpty || key.isEmpty) {
                setState(() => _phpServerStatus = '❌ 서버 URL과 API 키를 입력하세요.');
                return;
              }
              setState(() { _phpTesting = true; _phpServerStatus = '연결 확인 중...'; });
              try {
                KakaoPhpService().init(serverUrl: url, apiKey: key);
                final info = await KakaoPhpService().testConnection();
                final hasToken = info['has_token'] == true;
                final preview  = info['token_preview'] ?? '';
                final exp      = info['expires_at']    ?? '';
                setState(() => _phpServerStatus = hasToken
                  ? '✅ 연결 성공!\n토큰: $preview  만료: $exp'
                  : '✅ 서버 연결 성공 (토큰 미발급)');
              } catch (e) {
                final msg = e.toString();
                final hint = msg.contains('Unauthorized')
                  ? '\n\n💡 config.php 의 API_KEY 값과 위에 입력한 API 키가 일치하는지 확인하세요.'
                  : '';
                setState(() => _phpServerStatus = '❌ 연결 실패: $msg$hint');
              } finally {
                setState(() => _phpTesting = false);
              }
            },
            icon: _phpTesting
                ? const SizedBox(width: 12, height: 12,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.wifi_tethering, size: 14),
            label: Text(_phpTesting ? '확인 중...' : '연결 테스트'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2E7D32),
              side: const BorderSide(color: Color(0xFF2E7D32)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
        ]),
        if (_phpServerStatus.isNotEmpty) ...[
          const SizedBox(height: 10),
          _statusBox(_phpServerStatus),
        ],
      ]),
      const SizedBox(height: 12),

      // ── 토큰 발급 카드 ────────────────────────────────────────────────
      _sectionCard('🔑 OAuth 토큰 발급 (PHP 서버 경유)', [
        const Text(
          'PHP 서버가 client_secret 을 포함해 토큰을 교환합니다.\n'
          '브라우저에서 카카오 로그인 후 code= 뒤의 값을 입력하세요.',
          style: TextStyle(fontSize: 12, color: Color(0xFF6C757D)),
        ),
        const SizedBox(height: 10),

        // REST API 키 (토큰 발급용)
        TextField(
          controller: _phpRestApiKeyC,
          decoration: InputDecoration(
            labelText: 'Kakao REST API 키 (토큰 발급용)',
            hintText: 'developers.kakao.com → 앱 → 앱 키 → REST API 키',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
        ),
        const SizedBox(height: 10),

        // 브라우저 열기
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () async {
              // PHP 섹션 전용 REST API 키 우선, 없으면 직접연결 섹션 키 사용
              final restKey = _phpRestApiKeyC.text.trim().isNotEmpty
                  ? _phpRestApiKeyC.text.trim()
                  : _directRestApiKeyC.text.trim();
              if (restKey.isEmpty) {
                setState(() => _phpTokenStatus = '❌ REST API 키를 위에 입력하세요.');
                return;
              }
              final url = KakaoDirectService.buildAuthUrl(restKey);
              try {
                await KakaoDirectService.openBrowser(url);
                setState(() => _phpTokenStatus =
                  '✅ 브라우저가 열렸습니다.\n\n'
                  '카카오 로그인 후 리다이렉트 URL(https://localhost?code=...)의\n'
                  '"code=" 뒤 값을 아래 입력란에 붙여넣으세요.');
              } catch (e) {
                setState(() => _phpTokenStatus = '브라우저 열기 실패. 직접 URL 복사:\n$url');
              }
            },
            icon: const Icon(Icons.open_in_browser, size: 14),
            label: const Text('① 브라우저에서 카카오 로그인'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2E7D32),
              side: const BorderSide(color: Color(0xFF2E7D32)),
            ),
          ),
        ),
        const SizedBox(height: 8),

        // 코드 입력 + 교환 버튼
        Row(children: [
          Expanded(
            child: TextField(
              controller: _phpCodeC,
              decoration: InputDecoration(
                labelText: '② 인가 코드 (code= 뒤의 값)',
                hintText: '예) 3GQRzE3p_xxxxxxxx',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _phpExchanging ? null : () async {
              final code = _phpCodeC.text.trim();
              final url  = _phpServerUrlC.text.trim();
              final key  = _phpApiKeyC.text.trim();
              if (code.isEmpty) {
                setState(() => _phpTokenStatus = '❌ 인가 코드를 입력하세요.');
                return;
              }
              if (url.isEmpty || key.isEmpty) {
                setState(() => _phpTokenStatus = '❌ 위 "서버 연결 설정"에서 서버 URL과 API 키를 먼저 저장하세요.');
                return;
              }
              setState(() { _phpExchanging = true; _phpTokenStatus = 'PHP 서버에서 토큰 교환 중...'; });
              try {
                KakaoPhpService().init(serverUrl: url, apiKey: key);
                await KakaoPhpService().exchangeCode(code);
                _phpCodeC.clear();
                setState(() => _phpTokenStatus = '✅ 토큰 발급 완료! PHP 서버 DB에 저장되었습니다.');
              } catch (e) {
                final msg = e.toString();
                final hint = msg.contains('Unauthorized')
                  ? '\n\n💡 config.php 의 API_KEY 값과 "서버 연결 설정"의 API 키가 일치하는지 확인하세요.'
                  : '';
                setState(() => _phpTokenStatus = '❌ 토큰 교환 실패: $msg$hint');
              } finally {
                setState(() => _phpExchanging = false);
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            child: _phpExchanging
                ? const SizedBox(width: 14, height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('③ 토큰 발급'),
          ),
        ]),
        if (_phpTokenStatus.isNotEmpty) ...[
          const SizedBox(height: 10),
          _statusBox(_phpTokenStatus),
        ],
      ]),
      const SizedBox(height: 12),

      // ── 발신 카드 ─────────────────────────────────────────────────────
      _sectionCard('📤 발신 설정', [
        // 폴링 상태 표시
        Row(children: [
          _statusDot(svc.isPolling ? Colors.green : Colors.grey),
          const SizedBox(width: 8),
          Text(
            svc.isPolling ? '폴링 중 (5초 간격)' : '폴링 중지',
            style: TextStyle(
              fontSize: 13, fontWeight: FontWeight.w500,
              color: svc.isPolling ? Colors.green.shade700 : Colors.grey,
            ),
          ),
        ]),
        const Divider(height: 20),

        // 나에게 보내기 테스트
        FilledButton.icon(
          onPressed: _phpTesting ? null : () async {
            final url = _phpServerUrlC.text.trim();
            final key = _phpApiKeyC.text.trim();
            if (url.isEmpty || key.isEmpty) {
              setState(() => _phpSendStatus = '❌ 서버 URL과 API 키를 먼저 저장하세요.');
              return;
            }
            setState(() { _phpTesting = true; _phpSendStatus = '나에게 보내기 테스트 중...'; });
            try {
              KakaoPhpService().init(serverUrl: url, apiKey: key);
              await KakaoPhpService().sendToSelf('[톡톡AI] PHP 릴레이 테스트 ✅');
              setState(() => _phpSendStatus = '✅ 전송 완료! 카카오톡 나와의 채팅방을 확인하세요.');
            } catch (e) {
              setState(() => _phpSendStatus = '❌ 전송 실패: $e\n\nPHP 서버에 토큰이 발급되었는지 확인하세요.');
            } finally {
              setState(() => _phpTesting = false);
            }
          },
          icon: _phpTesting
              ? const SizedBox(width: 14, height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send, size: 16),
          label: Text(_phpTesting ? '전송 중...' : '나에게 보내기 테스트'),
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF2E7D32),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
        ),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),

        // 특정 1명에게 보내기
        const Text('특정 1명에게 보내기', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 4),
        const Text(
          '카카오 친구 목록 API로 조회한 수신자의 UUID 를 입력합니다.\n'
          '(카카오 앱에서 "친구 목록" 동의항목 활성화 필요)',
          style: TextStyle(fontSize: 11, color: Color(0xFF6C757D)),
        ),
        const SizedBox(height: 8),
        _field('수신자 UUID (receiver_uuid)', _phpSendUserIdC,
            hint: '예) abcdef1234...'),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () async {
            final uuid = _phpSendUserIdC.text.trim();
            final url  = _phpServerUrlC.text.trim();
            final key  = _phpApiKeyC.text.trim();
            if (uuid.isEmpty || url.isEmpty || key.isEmpty) {
              setState(() => _phpSendStatus = '❌ 수신자 UUID·서버 URL·API 키를 입력하세요.');
              return;
            }
            setState(() { _phpTesting = true; _phpSendStatus = '1:1 전송 중...'; });
            try {
              KakaoPhpService().init(serverUrl: url, apiKey: key);
              await KakaoPhpService().sendToUser(uuid, '[톡톡AI] PHP 릴레이 1:1 테스트 ✅');
              setState(() => _phpSendStatus = '✅ 1:1 전송 완료!');
            } catch (e) {
              setState(() => _phpSendStatus = '❌ 전송 실패: $e');
            } finally {
              setState(() => _phpTesting = false);
            }
          },
          icon: const Icon(Icons.person_outline, size: 14),
          label: const Text('1:1 테스트 전송'),
          style: OutlinedButton.styleFrom(
            foregroundColor: const Color(0xFF2E7D32),
            side: const BorderSide(color: Color(0xFF2E7D32)),
          ),
        ),
        if (_phpSendStatus.isNotEmpty) ...[
          const SizedBox(height: 10),
          _statusBox(_phpSendStatus),
        ],
      ]),
      const SizedBox(height: 12),

      // ── 수신 안내 카드 ────────────────────────────────────────────────
      _sectionCard('📥 수신 설정 (OpenBuilder 스킬 서버)', [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.info_outline, size: 13, color: Color(0xFF2E7D32)),
              SizedBox(width: 4),
              Text('카카오 채널봇 → PHP 서버 수신 설정',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: Color(0xFF2E7D32))),
            ]),
            const SizedBox(height: 6),
            _step('1', '카카오 채널 파트너센터(center-pf.kakao.com) → 채널 개설'),
            _step('2', 'OGQ 마켓 → OpenBuilder → 스킬 추가'),
            _step('3', '스킬 URL 등록:'),
            Container(
              margin: const EdgeInsets.only(left: 18, top: 3, bottom: 3),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.green.shade200),
              ),
              child: SelectableText(
                'https://yourdomain.com/kakao_relay/skill.php',
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
            _step('4', '블록에 스킬 연결 → 배포'),
            _step('5', '앱에서 "PHP 릴레이 활성화" ON → 저장'),
            const SizedBox(height: 4),
            const Text('사용자가 채널봇에 메시지를 보내면 → skill.php → DB 저장 → 앱이 5초마다 자동 수신',
                style: TextStyle(fontSize: 11, color: Color(0xFF1B5E20))),
          ]),
        ),
      ]),
    ]);
  }

  // ── 공통 헬퍼 위젯 ───────────────────────────────────────────────────
  Widget _statusDot(Color color) => Container(
    width: 10, height: 10,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );

  Widget _tokenBox(String token, VoidCallback onCopy) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.grey.shade100, borderRadius: BorderRadius.circular(4),
    ),
    child: Row(children: [
      const Icon(Icons.vpn_key, size: 14, color: Colors.grey),
      const SizedBox(width: 6),
      Expanded(child: Text(
        '토큰: ${token.length > 16 ? '${token.substring(0, 8)}...${token.substring(token.length - 8)}' : token}',
        style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.grey),
      )),
      IconButton(
        icon: const Icon(Icons.copy, size: 14, color: Colors.grey),
        tooltip: '토큰 복사', padding: EdgeInsets.zero,
        constraints: const BoxConstraints(), onPressed: onCopy,
      ),
    ]),
  );


  // ── 헬퍼 위젯 ────────────────────────────────────────────────────────
  Widget _infoBox({
    required Color color,
    required IconData icon,
    required String title,
    required List<String> steps,
    String? tip,
    bool tipBold = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: color)),
        ]),
        const SizedBox(height: 8),
        ...steps.asMap().entries.map((e) => _guideStep('${e.key + 1}', e.value, color)),
        if (tip != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.6),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(children: [
              Icon(Icons.lightbulb_outline, size: 14, color: color),
              const SizedBox(width: 6),
              Expanded(child: Text(tip,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: tipBold ? FontWeight.w600 : FontWeight.normal,
                  ))),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _guideStep(String n, String text, Color color) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        width: 18, height: 18,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Text(n, style: const TextStyle(color: Colors.white, fontSize: 10,
            fontWeight: FontWeight.bold)),
      ),
      const SizedBox(width: 8),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
    ]),
  );

  Widget _step(String n, String text) => Padding(
    padding: const EdgeInsets.only(top: 3),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('$n. ', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
      Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
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
      Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13,
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
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      );

  Widget _statusBox(String msg) => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: msg.startsWith('✅') ? Colors.green.shade50 : Colors.orange.shade50,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(
        color: msg.startsWith('✅') ? Colors.green.shade300 : Colors.orange.shade300,
      ),
    ),
    child: Text(msg, style: const TextStyle(fontSize: 13)),
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
