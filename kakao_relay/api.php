<?php
// ═══════════════════════════════════════════════════════════════════════
//  kakao_relay / api.php
//  Flutter 앱 ↔ PHP 릴레이 서버 REST API
//
//  ┌─────────────────────────────────────────────────────────────┐
//  │  엔드포인트 목록 (모두 X-Api-Key 헤더 필요)                    │
//  │  GET  ?action=token_info          토큰 상태 확인             │
//  │  POST ?action=exchange            OAuth 코드 → 토큰 교환    │
//  │  POST ?action=send_self           나에게 보내기              │
//  │  POST ?action=send_user           특정 1명에게 보내기        │
//  │  GET  ?action=poll[&since_id=N]   수신 메시지 폴링          │
//  │  POST ?action=mark_read           메시지 읽음 처리          │
//  │  GET  ?action=webhook_log[&limit=20]  웹훅 진단 로그 조회   │
//  └─────────────────────────────────────────────────────────────┘
// ═══════════════════════════════════════════════════════════════════════

require_once __DIR__ . '/config.php';

requireApiKey();  // 모든 요청에 API 키 필수

$action = trim($_GET['action'] ?? '');

switch ($action) {
    case 'token_info':  handleTokenInfo();  break;
    case 'exchange':    handleExchange();   break;
    case 'send_self':   handleSendSelf();   break;
    case 'send_user':   handleSendUser();   break;
    case 'poll':        handlePoll();       break;
    case 'mark_read':   handleMarkRead();   break;
    case 'webhook_log': handleWebhookLog(); break;
    default:
        jsonError("Unknown action: '$action'. Valid: token_info, exchange, send_self, send_user, poll, mark_read, webhook_log");
}

// ────────────────────────────────────────────────────────────────────
//  [GET] ?action=token_info
//  현재 저장된 액세스 토큰 상태를 반환합니다.
// ────────────────────────────────────────────────────────────────────
function handleTokenInfo(): void {
    $db  = getDb();
    $row = $db->query("SELECT access_token, expires_in, updated_at FROM kakao_tokens LIMIT 1")->fetch();

    if (!$row || empty($row['access_token'])) {
        jsonOk(['has_token' => false]);
    }

    $expiresAt  = strtotime($row['updated_at']) + (int)$row['expires_in'];
    $remaining  = $expiresAt - time();
    $preview    = substr($row['access_token'], 0, 8) . '...';

    jsonOk([
        'has_token'      => true,
        'token_preview'  => $preview,
        'expires_in_sec' => max(0, $remaining),
        'expires_at'     => date('Y-m-d H:i:s', $expiresAt),
    ]);
}

// ────────────────────────────────────────────────────────────────────
//  [POST] ?action=exchange
//  Body: { "code": "인가코드" }
//  카카오 인증 서버에서 액세스 토큰을 발급받아 DB에 저장합니다.
//  client_secret 은 PHP 서버에서 처리하므로 Flutter 앱에 노출되지 않습니다.
// ────────────────────────────────────────────────────────────────────
function handleExchange(): void {
    $input = jsonBody();
    $code  = trim($input['code'] ?? '');
    if (!$code) jsonError('code 필드가 필요합니다.');

    // file_get_contents 대신 cURL 사용 (allow_url_fopen=Off 환경 대응)
    $ch = curl_init('https://kauth.kakao.com/oauth/token');
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POST           => true,
        CURLOPT_HTTPHEADER     => ['Content-Type: application/x-www-form-urlencoded'],
        CURLOPT_POSTFIELDS     => http_build_query([
            'grant_type'    => 'authorization_code',
            'client_id'     => KAKAO_REST_API_KEY,
            'client_secret' => KAKAO_CLIENT_SECRET,
            'redirect_uri'  => KAKAO_REDIRECT_URI,
            'code'          => $code,
        ]),
        CURLOPT_TIMEOUT        => 15,
        CURLOPT_SSL_VERIFYPEER => true,
    ]);
    $res      = curl_exec($ch);
    $httpCode = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $curlErr  = curl_error($ch);
    curl_close($ch);

    if ($res === false || $res === '') {
        jsonError('카카오 서버 연결 실패: ' . ($curlErr ?: 'cURL 오류'));
    }

    $data = json_decode($res, true) ?: [];

    if (empty($data['access_token'])) {
        $msg = $data['error_description'] ?? $data['error'] ?? '토큰 발급 실패';
        jsonError($msg . " (HTTP $httpCode)");
    }

    saveTokens($data);

    jsonOk([
        'message'       => '토큰 발급 성공. DB에 저장되었습니다.',
        'expires_in'    => $data['expires_in'] ?? 21599,
        'token_preview' => substr($data['access_token'], 0, 8) . '...',
    ]);
}

// ────────────────────────────────────────────────────────────────────
//  [POST] ?action=send_self
//  Body: { "message": "보낼 내용" }
//  카카오 나에게 보내기 (v2/api/talk/memo/default/send)
// ────────────────────────────────────────────────────────────────────
function handleSendSelf(): void {
    $input   = jsonBody();
    $message = trim($input['message'] ?? '');
    if (!$message) jsonError('message 필드가 필요합니다.');

    $token = getAccessToken();
    if (!$token) jsonError('저장된 액세스 토큰이 없습니다. ?action=exchange 로 먼저 토큰을 발급하세요.', 401);

    $templateObj = json_encode([
        'object_type' => 'text',
        'text'        => $message,
        'link'        => ['web_url' => '', 'mobile_web_url' => ''],
    ], JSON_UNESCAPED_UNICODE);

    $result = kakaoPost(
        'https://kapi.kakao.com/v2/api/talk/memo/default/send',
        ['template_object' => $templateObj],
        $token
    );

    saveSendLog('self', '', $message, $result['code'] === 200 ? 'ok' : 'error',
        $result['code'] !== 200 ? $result['body'] : '');

    if ($result['code'] === 200) {
        jsonOk(['message' => '나에게 보내기 성공']);
    } else {
        $err = json_decode($result['body'], true);
        $msg = $err['msg'] ?? $err['message'] ?? $result['body'];
        jsonError("카카오 API 오류: $msg", $result['code'] ?: 500);
    }
}

// ────────────────────────────────────────────────────────────────────
//  [POST] ?action=send_user
//  Body: { "receiver_uuid": "카카오UUID", "message": "보낼 내용" }
//  카카오 친구에게 보내기 (v1/api/talk/friends/message/default/send)
//  ※ 카카오 앱에서 '친구 목록' 동의항목이 필요합니다.
//  ※ receiver_uuid 는 카카오 사용자 UUID (친구 목록 API로 조회)
// ────────────────────────────────────────────────────────────────────
function handleSendUser(): void {
    $input        = jsonBody();
    $message      = trim($input['message']       ?? '');
    $receiverUuid = trim($input['receiver_uuid'] ?? '');

    if (!$message)      jsonError('message 필드가 필요합니다.');
    if (!$receiverUuid) jsonError('receiver_uuid 필드가 필요합니다.');

    $token = getAccessToken();
    if (!$token) jsonError('저장된 액세스 토큰이 없습니다.', 401);

    $templateObj = json_encode([
        'object_type' => 'text',
        'text'        => $message,
        'link'        => ['web_url' => '', 'mobile_web_url' => ''],
    ], JSON_UNESCAPED_UNICODE);

    $result = kakaoPost(
        'https://kapi.kakao.com/v1/api/talk/friends/message/default/send',
        [
            'receiver_uuids'  => json_encode([$receiverUuid]),
            'template_object' => $templateObj,
        ],
        $token
    );

    saveSendLog('user', $receiverUuid, $message, $result['code'] === 200 ? 'ok' : 'error',
        $result['code'] !== 200 ? $result['body'] : '');

    if ($result['code'] === 200) {
        jsonOk(['message' => '1:1 전송 성공', 'receiver_uuid' => $receiverUuid]);
    } else {
        $err = json_decode($result['body'], true);
        $msg = $err['msg'] ?? $err['message'] ?? $result['body'];
        // 친구 동의항목 오류 힌트
        if ($result['code'] === 403) {
            $msg .= ' (카카오 앱에서 "친구 목록" 동의항목을 선택 동의로 설정했는지 확인하세요.)';
        }
        jsonError("카카오 API 오류: $msg", $result['code'] ?: 500);
    }
}

// ────────────────────────────────────────────────────────────────────
//  [GET] ?action=poll[&since_id=N][&limit=20]
//  since_id 보다 큰 id 의 수신 메시지를 반환하고 읽음 처리합니다.
//  Flutter 앱은 5초마다 이 엔드포인트를 호출합니다.
// ────────────────────────────────────────────────────────────────────
function handlePoll(): void {
    $sinceId = max(0, (int)($_GET['since_id'] ?? 0));
    $limit   = min(100, max(1, (int)($_GET['limit'] ?? 20)));

    $db   = getDb();
    $stmt = $db->prepare(
        "SELECT id, user_key, user_id, utterance, received_at
         FROM kakao_messages
         WHERE id > ?
         ORDER BY id ASC
         LIMIT ?"
    );
    $stmt->execute([$sinceId, $limit]);
    $rows = $stmt->fetchAll();

    // 조회된 메시지 읽음 처리
    if (!empty($rows)) {
        $ids = implode(',', array_map('intval', array_column($rows, 'id')));
        $db->exec("UPDATE kakao_messages SET is_read=1 WHERE id IN ($ids)");
    }

    $lastId = !empty($rows) ? (int)end($rows)['id'] : $sinceId;

    jsonOk([
        'messages' => $rows,
        'count'    => count($rows),
        'last_id'  => $lastId,
    ]);
}

// ────────────────────────────────────────────────────────────────────
//  [POST] ?action=mark_read
//  Body: { "up_to_id": N }
//  N 이하의 메시지를 모두 읽음 처리합니다.
// ────────────────────────────────────────────────────────────────────
function handleMarkRead(): void {
    $input   = jsonBody();
    $upToId  = (int)($input['up_to_id'] ?? 0);
    if ($upToId <= 0) jsonError('up_to_id 필드가 필요합니다.');

    $db = getDb();
    $db->prepare("UPDATE kakao_messages SET is_read=1 WHERE id <= ?")->execute([$upToId]);
    jsonOk(['marked' => true, 'up_to_id' => $upToId]);
}

// ────────────────────────────────────────────────────────────────────
//  [GET] ?action=webhook_log[&limit=20]
//  skill.php 에 실제로 들어온 요청(원본 raw_body) 을 최근순으로 반환합니다.
//  카카오 서버가 실제로 요청을 보내는지, JSON 구조가 예상과 다른지 진단용.
// ────────────────────────────────────────────────────────────────────
function handleWebhookLog(): void {
    $limit = min(50, max(1, (int)($_GET['limit'] ?? 20)));
    $db    = getDb();
    $rows  = $db->query(
        "SELECT id, method, remote_ip, raw_body, parse_result, created_at
         FROM webhook_log ORDER BY id DESC LIMIT $limit"
    )->fetchAll();
    jsonOk(['logs' => $rows, 'count' => count($rows)]);
}

// ─── 내부 헬퍼 ───────────────────────────────────────────────────────
function jsonBody(): array {
    $raw = file_get_contents('php://input');
    return json_decode($raw ?: '{}', true) ?: [];
}

function saveSendLog(string $target, string $receiver, string $message,
                     string $status, string $error = ''): void {
    try {
        getDb()->prepare(
            "INSERT INTO send_log (target, receiver, message, status, error) VALUES (?,?,?,?,?)"
        )->execute([$target, $receiver, $message, $status, substr($error, 0, 500)]);
    } catch (\Throwable $e) { /* 로그 실패는 무시 */ }
}
