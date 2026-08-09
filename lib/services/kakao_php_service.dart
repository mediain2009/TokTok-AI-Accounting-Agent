import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

// ─── 수신 메시지 모델 ──────────────────────────────────────────────────
class KakaoPhpMessage {
  final int      id;
  final String   userKey;
  final String   userId;
  final String   utterance;
  final DateTime receivedAt;

  const KakaoPhpMessage({
    required this.id,
    required this.userKey,
    required this.userId,
    required this.utterance,
    required this.receivedAt,
  });

  factory KakaoPhpMessage.fromMap(Map<String, dynamic> m) => KakaoPhpMessage(
    id:         (m['id'] as num).toInt(),
    userKey:    (m['user_key']  as String?) ?? '',
    userId:     (m['user_id']   as String?) ?? '',
    utterance:  (m['utterance'] as String?) ?? '',
    receivedAt: DateTime.tryParse(m['received_at'] as String? ?? '')?.toLocal()
                ?? DateTime.now(),
  );

  @override
  String toString() => '[KakaoPhp #$id] $utterance';
}

// ─── PHP 릴레이 서비스 ────────────────────────────────────────────────
class KakaoPhpService {
  // ── 싱글톤 ─────────────────────────────────────────────────────────
  static final KakaoPhpService _instance = KakaoPhpService._();
  factory KakaoPhpService() => _instance;
  KakaoPhpService._();

  // ── 설정 ────────────────────────────────────────────────────────────
  String _serverUrl = '';   // 예) https://yourdomain.com/kakao_relay
  String _apiKey    = '';   // config.php 의 API_KEY 와 동일

  // ── 상태 ────────────────────────────────────────────────────────────
  Timer? _pollTimer;
  int    _lastMsgId = 0;
  bool   _enabled   = false;

  // ── 콜백 ─────────────────────────────────────────────────────────────
  // 새 메시지 수신 시 호출됩니다.
  void Function(KakaoPhpMessage msg)? onMessage;

  // ── Getter ────────────────────────────────────────────────────────────
  bool get isPolling     => _pollTimer?.isActive == true;
  bool get isConfigured  => _serverUrl.isNotEmpty && _apiKey.isNotEmpty;

  // ────────────────────────────────────────────────────────────────────
  //  초기화 / 재설정
  // ────────────────────────────────────────────────────────────────────
  void init({
    required String serverUrl,
    required String apiKey,
    bool enabled = false,
  }) {
    _serverUrl = serverUrl.trimRight().replaceAll(RegExp(r'/+$'), '');
    _apiKey    = apiKey;
    _enabled   = enabled;
  }

  // ────────────────────────────────────────────────────────────────────
  //  폴링 시작 / 중지
  // ────────────────────────────────────────────────────────────────────
  void startPolling() {
    stopPolling();
    if (!_enabled || !isConfigured) return;
    _poll();  // 즉시 1회 실행
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _poll());
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  // ────────────────────────────────────────────────────────────────────
  //  OAuth 코드 교환 (PHP 서버가 client_secret 포함하여 처리)
  //  반환: 성공 시 true, 실패 시 예외
  // ────────────────────────────────────────────────────────────────────
  Future<void> exchangeCode(String code) async {
    final res = await _post('exchange', {'code': code});
    if (res['ok'] != true) {
      throw Exception(res['error'] ?? '토큰 발급 실패');
    }
  }

  // ────────────────────────────────────────────────────────────────────
  //  토큰 상태 확인
  // ────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> tokenInfo() async {
    final res = await _get('token_info');
    return res;
  }

  // ────────────────────────────────────────────────────────────────────
  //  나에게 보내기
  // ────────────────────────────────────────────────────────────────────
  Future<void> sendToSelf(String message) async {
    final res = await _post('send_self', {'message': message});
    if (res['ok'] != true) {
      throw Exception(res['error'] ?? '전송 실패');
    }
  }

  // ────────────────────────────────────────────────────────────────────
  //  특정 1명에게 보내기
  //  receiverUuid: 카카오 사용자 UUID (친구 목록 API로 조회한 값)
  // ────────────────────────────────────────────────────────────────────
  Future<void> sendToUser(String receiverUuid, String message) async {
    final res = await _post('send_user', {
      'receiver_uuid': receiverUuid,
      'message':       message,
    });
    if (res['ok'] != true) {
      throw Exception(res['error'] ?? '전송 실패');
    }
  }

  // ────────────────────────────────────────────────────────────────────
  //  서버 연결 테스트
  //  성공 시 has_token 상태 반환, 실패 시 예외
  // ────────────────────────────────────────────────────────────────────
  Future<Map<String, dynamic>> testConnection() async {
    if (!isConfigured) throw Exception('서버 URL과 API 키를 먼저 설정하세요.');
    return await _get('token_info');
  }

  // ────────────────────────────────────────────────────────────────────
  //  내부: 수신 메시지 폴링
  // ────────────────────────────────────────────────────────────────────
  Future<void> _poll() async {
    if (!isConfigured) return;
    try {
      final uri = Uri.parse('$_serverUrl/api.php')
          .replace(queryParameters: {
        'action':   'poll',
        'since_id': '$_lastMsgId',
        'limit':    '20',
      });

      final res = await http.get(uri, headers: _headers)
          .timeout(const Duration(seconds: 10));

      if (res.statusCode != 200) return;
      final body = _decode(res);
      if (body['ok'] != true) return;

      final msgs = (body['messages'] as List?)?.cast<Map<String, dynamic>>() ?? [];
      for (final m in msgs) {
        final msg = KakaoPhpMessage.fromMap(m);
        _lastMsgId = msg.id;
        onMessage?.call(msg);
      }
    } catch (_) {
      // 네트워크 오류는 조용히 무시 (다음 주기에 재시도)
    }
  }

  // ────────────────────────────────────────────────────────────────────
  //  내부 HTTP 헬퍼
  // ────────────────────────────────────────────────────────────────────
  Map<String, String> get _headers => {
    'Content-Type': 'application/json; charset=utf-8',
    'X-Api-Key':    _apiKey,
  };

  Future<Map<String, dynamic>> _get(String action) async {
    if (!isConfigured) throw Exception('서버 URL과 API 키가 설정되지 않았습니다.');
    final uri = Uri.parse('$_serverUrl/api.php?action=$action');
    final res = await http.get(uri, headers: _headers)
        .timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  Future<Map<String, dynamic>> _post(String action, Map<String, dynamic> body) async {
    if (!isConfigured) throw Exception('서버 URL과 API 키가 설정되지 않았습니다.');
    final uri = Uri.parse('$_serverUrl/api.php?action=$action');
    final res = await http.post(uri,
      headers: _headers,
      body:    jsonEncode(body),
    ).timeout(const Duration(seconds: 15));
    return _decode(res);
  }

  Map<String, dynamic> _decode(http.Response res) {
    try {
      return jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      return {'ok': false, 'error': 'JSON 파싱 오류 (${res.statusCode})'};
    }
  }
}
