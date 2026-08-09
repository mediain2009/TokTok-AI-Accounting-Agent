<?php
// ═══════════════════════════════════════════════════════════════════════
//  kakao_relay / skill.php
//  Kakao OpenBuilder 스킬 서버 엔드포인트
//
//  카카오 채널봇에 메시지가 오면 OpenBuilder 가 이 URL 로 POST 요청을 보냅니다.
//  발화(utterance) 를 DB 에 저장하고 Flutter 앱이 폴링으로 수신합니다.
//
//  OpenBuilder 설정 방법:
//    1. 카카오 채널 파트너센터(center-pf.kakao.com) → 채널 개설
//    2. OGQ 마켓 → OpenBuilder → 스킬 추가
//    3. 스킬 URL: https://yourdomain.com/kakao_relay/skill.php
//    4. 블록에 스킬 연결 후 배포
// ═══════════════════════════════════════════════════════════════════════

require_once __DIR__ . '/config.php';

// ── OpenBuilder IP 화이트리스트 검증 (선택 사항, 보안 강화) ───────────
// Kakao OpenBuilder 서버 IP 목록 (필요 시 최신 목록으로 업데이트)
// 주석 해제 시 활성화됩니다.
// $allowedIps = ['110.76.143.', '219.249.231.', '175.126.99.'];
// $clientIp   = $_SERVER['REMOTE_ADDR'] ?? '';
// $allowed    = false;
// foreach ($allowedIps as $prefix) {
//     if (strpos($clientIp, $prefix) === 0) { $allowed = true; break; }
// }
// if (!$allowed) { http_response_code(403); echo json_encode(['error'=>'forbidden']); exit; }

// ── 요청 파싱 ──────────────────────────────────────────────────────────
$rawBody = file_get_contents('php://input');
$req     = json_decode($rawBody ?: '{}', true);

// 발화 내용 추출 (오픈빌더 표준 구조)
$utterance = $req['userRequest']['utterance']                              ?? '';
$userKey   = $req['userRequest']['user']['id']                             ?? '';
$userId    = $req['userRequest']['user']['properties']['plusfriendUserKey'] ?? '';

// ── 진단용: 파싱 성공/실패와 무관하게 모든 요청을 무조건 기록 ─────────
// 카카오 서버가 실제로 호출하는지, JSON 구조가 예상과 다른지 확인용.
$parseResult = 'empty_utterance';

// ── DB 저장 ──────────────────────────────────────────────────────────
$dbError = '';
if (!empty($utterance)) {
    try {
        $db = getDb();
        $db->prepare(
            "INSERT INTO kakao_messages (user_key, user_id, utterance, raw_json) VALUES (?,?,?,?)"
        )->execute([$userKey, $userId, $utterance, $rawBody]);
        $parseResult = 'saved:' . $db->lastInsertId();
    } catch (\Throwable $e) {
        // DB 저장 실패 시에도 OpenBuilder 에 정상 응답 반환 (재시도 방지)
        $dbError = $e->getMessage();
        $parseResult = 'db_error:' . $dbError;
        error_log('[kakao_relay/skill.php] DB error: ' . $dbError);
    }
}

// 웹훅 원본 로그 저장 (파싱 결과 무관, 항상 기록)
try {
    getDb()->prepare(
        "INSERT INTO webhook_log (method, remote_ip, raw_body, parse_result) VALUES (?,?,?,?)"
    )->execute([
        $_SERVER['REQUEST_METHOD'] ?? '',
        $_SERVER['REMOTE_ADDR']    ?? '',
        $rawBody,
        $parseResult,
    ]);
} catch (\Throwable $e) {
    error_log('[kakao_relay/skill.php] webhook_log error: ' . $e->getMessage());
}

// ── OpenBuilder 응답 (v2 포맷) ────────────────────────────────────────
// 사용자에게 즉시 응답, 실제 처리 결과는 Flutter → 카카오 메시지로 전달
// DB 오류 시에도 OpenBuilder 에는 정상 응답 (재시도 방지)
$responseText = empty($dbError)
    ? '요청을 받았습니다. 잠시 후 결과를 알려드리겠습니다. 🔔'
    : '요청을 받았습니다. 잠시 후 결과를 알려드리겠습니다. 🔔';
// DB 오류는 서버 error_log 에서 확인: tail -f /var/log/php_errors.log

echo json_encode([
    'version'  => '2.0',
    'template' => [
        'outputs' => [
            [
                'simpleText' => ['text' => $responseText],
            ],
        ],
    ],
], JSON_UNESCAPED_UNICODE);
