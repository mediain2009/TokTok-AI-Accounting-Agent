import 'dart:convert';
import 'package:http/http.dart' as http;
import '../db_helper.dart';
import '../models.dart';

/// 카카오 PlayMCP 서비스
/// - playmcp.kakao.com MCP 게이트웨이를 통해 카카오톡 나와의 채팅방으로 알림 전송
/// - 연동 흐름: PlayMCP 도구함 → "OpenClaw와 연결" → OTT 발급 → exchangeOtt() → 토큰 저장
/// - MCP 엔드포인트: https://playmcp.kakao.com/mcp  (Bearer 인증)
class KakaoPlayMcpService {
  static const _mcpUrl     = 'https://playmcp.kakao.com/mcp';
  static const _ottUrl     = 'https://playmcp.kakao.com/api/v1/auths/otts:exchange';
  static const _refreshUrl = 'https://playmcp.kakao.com/api/v1/auths/tokens:refresh';

  // 세션 캐시 (앱 수명 동안 유지)
  static String? _sessionId;
  static String? _memoToolName;  // 나와의 채팅방 도구 이름 캐시
  static int     _idCounter = 10;

  // ─── OTT 교환 ─────────────────────────────────────────────────────
  /// PlayMCP 도구함에서 발급한 One Time Token을 access/refresh 토큰으로 교환합니다.
  ///
  /// 사용자가 playmcp.kakao.com/toolbox → "OpenClaw와 연결" 버튼으로 OTT 발급 후 이 메소드 호출.
  /// 반환: (accessToken, refreshToken)
  static Future<({String accessToken, String refreshToken})> exchangeOtt(
      String ott) async {
    final res = await http.post(
      Uri.parse(_ottUrl),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'tokenValue': ott.trim()}),
    ).timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) {
      final msg = _parseErrorBody(res.body) ?? 'HTTP ${res.statusCode}';
      throw Exception('OTT 교환 실패: $msg');
    }

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final at   = body['accessToken']?['tokenValue']  as String?;
    final rt   = body['refreshToken']?['tokenValue'] as String?;

    if (at == null || at.isEmpty) {
      throw Exception('서버에서 액세스 토큰을 받지 못했습니다.');
    }

    resetSession();
    return (accessToken: at, refreshToken: rt ?? '');
  }

  // ─── 토큰 갱신 ───────────────────────────────────────────────────
  static Future<({String accessToken, String refreshToken})> refreshTokens(
      String refreshTok) async {
    final res = await http.post(
      Uri.parse(_refreshUrl),
      headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
      body: jsonEncode({'refreshToken': refreshTok}),
    ).timeout(const Duration(seconds: 15));

    if (res.statusCode != 200) throw Exception('토큰 갱신 실패 (${res.statusCode})');

    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final at   = body['accessToken']?['tokenValue']  as String?;
    final rt   = body['refreshToken']?['tokenValue'] as String?;

    if (at == null) throw Exception('갱신된 액세스 토큰이 없습니다.');
    resetSession();
    return (accessToken: at, refreshToken: rt ?? refreshTok);
  }

  // ─── 나와의 채팅방 메시지 전송 ──────────────────────────────────
  /// [accessToken]을 사용해 카카오톡 나와의 채팅방으로 [message]를 전송합니다.
  ///
  /// 내부적으로 MCP initialize → tools/list → tools/call 순서로 처리합니다.
  /// 첫 호출 후 도구 이름과 세션 ID는 캐시되어 이후 호출이 빠릅니다.
  static Future<void> sendToMyChat(String accessToken, String message) async {
    final toolName = await _getOrFetchMemoTool(accessToken);
    await _post(accessToken, {
      'jsonrpc': '2.0',
      'id':      _nextId(),
      'method':  'tools/call',
      'params':  {
        'name':      toolName,
        'arguments': {'text': message},
      },
    });
  }

  // ─── DB 설정 로드 후 알림 전송 ──────────────────────────────────
  /// 앱 이벤트 발생 시 호출. PlayMCP 알림이 활성화된 경우에만 전송.
  static Future<void> sendNotification(String message) async {
    final settings = await DbHelper.getMessengerSettings();
    if (settings == null) return;
    if (!settings.kakaoPlayMcpNotify) return;
    if (settings.kakaoPlayMcpAccessToken.isEmpty) return;

    try {
      await sendToMyChat(settings.kakaoPlayMcpAccessToken, message);
    } catch (e) {
      // 401 → refresh 시도
      if (e.toString().contains('401') &&
          settings.kakaoPlayMcpRefreshToken.isNotEmpty) {
        final newTokens = await refreshTokens(settings.kakaoPlayMcpRefreshToken);
        await DbHelper.saveMessengerSettings(MessengerSettings(
          id:                      settings.id,
          telegramBotToken:        settings.telegramBotToken,
          telegramChatId:          settings.telegramChatId,
          telegramEnabled:         settings.telegramEnabled,
          kakaoRelayUrl:           settings.kakaoRelayUrl,
          kakaoRelayToken:         settings.kakaoRelayToken,
          kakaoEnabled:            settings.kakaoEnabled,
          kakaoPlayMcpAccessToken:  newTokens.accessToken,
          kakaoPlayMcpRefreshToken: newTokens.refreshToken,
          kakaoPlayMcpNotify:       settings.kakaoPlayMcpNotify,
        ));
        await sendToMyChat(newTokens.accessToken, message);
      } else {
        rethrow;
      }
    }
  }

  // ─── 사용 가능한 도구 목록 조회 ─────────────────────────────────
  /// 연결 테스트 및 도구 확인 용도
  static Future<List<String>> getAvailableTools(String accessToken) async {
    final tools = await _fetchToolsList(accessToken);
    return tools
        .map((t) => t['name'] as String? ?? '')
        .where((n) => n.isNotEmpty)
        .toList();
  }

  // ─── 내부: 도구 이름 조회 ────────────────────────────────────────
  static int _nextId() => _idCounter++;

  static Future<String> _getOrFetchMemoTool(String accessToken) async {
    if (_memoToolName != null) return _memoToolName!;

    final tools = await _fetchToolsList(accessToken);

    // 나와의 채팅방 관련 도구 탐색
    const keywords = ['me', 'memo', '나와의', 'my_chat', 'mymessage', 'talk_me', 'send_me'];
    for (final tool in tools) {
      final name = (tool['name'] as String? ?? '').toLowerCase();
      final desc = (tool['description'] as String? ?? '').toLowerCase();
      if (keywords.any((k) => name.contains(k) || desc.contains(k))) {
        _memoToolName = tool['name'] as String;
        return _memoToolName!;
      }
    }

    // fallback: 첫 번째 도구
    if (tools.isNotEmpty) {
      final fallback = tools.first['name'] as String? ?? '';
      if (fallback.isNotEmpty) {
        _memoToolName = fallback;
        return _memoToolName!;
      }
    }

    throw Exception(
      '나와의 채팅방 도구를 찾을 수 없습니다.\n'
      'PlayMCP 도구함에 카카오톡 서버가 추가되어 있는지 확인하세요.',
    );
  }

  static Future<List<Map<String, dynamic>>> _fetchToolsList(
      String accessToken) async {
    await _initialize(accessToken);
    final result = await _post(accessToken, {
      'jsonrpc': '2.0',
      'id':      _nextId(),
      'method':  'tools/list',
    });
    if (result == null) return [];
    final tools = result['tools'] as List?;
    return (tools ?? []).cast<Map<String, dynamic>>();
  }

  static Future<void> _initialize(String accessToken) async {
    if (_sessionId != null) return;  // 이미 초기화됨

    final res = await _post(accessToken, {
      'jsonrpc': '2.0',
      'id':      1,
      'method':  'initialize',
      'params':  {
        'protocolVersion': '2025-03-26',
        'clientInfo':      {'name': 'TokTokAI', 'version': '1.0.0'},
        'capabilities':    {},
      },
    });

    if (res != null) {
      // initialized notification (응답 없음)
      try {
        await http.post(
          Uri.parse(_mcpUrl),
          headers: {
            'Content-Type':  'application/json',
            'Authorization': 'Bearer $accessToken',
            if (_sessionId != null) 'Mcp-Session-Id': _sessionId!,
          },
          body: jsonEncode({'jsonrpc': '2.0', 'method': 'notifications/initialized'}),
        ).timeout(const Duration(seconds: 5));
      } catch (_) {}
    }
  }

  // ─── HTTP 헬퍼 ──────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> _post(
    String accessToken,
    Map<String, dynamic> body,
  ) async {
    final headers = <String, String>{
      'Content-Type':  'application/json',
      'Accept':        'application/json',
      'Authorization': 'Bearer $accessToken',
    };
    if (_sessionId != null) headers['Mcp-Session-Id'] = _sessionId!;

    final res = await http.post(
      Uri.parse(_mcpUrl),
      headers: headers,
      body:    jsonEncode(body),
    ).timeout(const Duration(seconds: 20));

    // 세션 ID 저장
    final sid = res.headers['mcp-session-id'];
    if (sid != null && sid.isNotEmpty) _sessionId = sid;

    if (res.statusCode == 401) throw Exception('401: 액세스 토큰이 만료되었습니다.');
    if (res.statusCode == 202) return null;  // notification 응답 (no body expected)
    if (res.statusCode != 200) {
      final snippet = res.body.length > 150 ? res.body.substring(0, 150) : res.body;
      throw Exception('MCP 오류 (${res.statusCode}): $snippet');
    }

    if (res.body.isEmpty) return null;

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    if (json.containsKey('error')) {
      final err = json['error'];
      if (err is Map) {
        throw Exception('MCP 오류: ${err['message'] ?? err}');
      }
      throw Exception('MCP 오류: $err');
    }

    return json['result'] as Map<String, dynamic>?;
  }

  static String? _parseErrorBody(String body) {
    try {
      final j = jsonDecode(body) as Map<String, dynamic>;
      return j['message'] as String? ??
          j['error'] as String? ??
          j['detail'] as String?;
    } catch (_) {
      return body.isNotEmpty
          ? body.substring(0, body.length.clamp(0, 100))
          : null;
    }
  }

  // ─── 세션 캐시 초기화 ─────────────────────────────────────────
  static void resetSession() {
    _sessionId    = null;
    _memoToolName = null;
    _idCounter    = 10;
  }
}
