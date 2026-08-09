<?php
// ═══════════════════════════════════════════════════════════════════════
//  kakao_relay / config.php
//  VPS에 이 디렉토리를 올린 후 아래 값을 실제 환경에 맞게 수정하세요.
// ═══════════════════════════════════════════════════════════════════════

// ─── Kakao API 설정 ────────────────────────────────────────────────────
define('KAKAO_REST_API_KEY',  '7773ad19371a49bc1d6ee0b8125a6a79');   // 카카오 REST API 키
define('KAKAO_CLIENT_SECRET', '3z99uf2PBzgU8JJREoLn7D1xk1ke5wCA');  // 클라이언트 시크릿
define('KAKAO_REDIRECT_URI',  'https://localhost');                   // 등록된 Redirect URI

// ─── MySQL DB 설정 ─────────────────────────────────────────────────────
define('DB_HOST',    'localhost');
define('DB_NAME',    'kakao_relay');
define('DB_USER',    'kakao_user');          // ← 실제 DB 유저로 변경
define('DB_PASS',    'your_db_password');    // ← 실제 DB 비밀번호로 변경
define('DB_CHARSET', 'utf8mb4');

// ─── Flutter 앱 인증 키 ────────────────────────────────────────────────
// Flutter 앱에서 API 호출 시 헤더 X-Api-Key 또는 쿼리스트링 api_key 로 전달
define('API_KEY', 'a3f9c2d8e7b14f06a521d30c9b874e12f6a9c3d4');  // ← 반드시 변경!

// ─── CORS / 공통 헤더 ──────────────────────────────────────────────────
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, X-Api-Key');
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    http_response_code(204);
    exit;
}
header('Content-Type: application/json; charset=utf-8');

// ─── DB 연결 (싱글톤) ─────────────────────────────────────────────────
function getDb(): PDO {
    static $pdo = null;
    if ($pdo === null) {
        $pdo = new PDO(
            'mysql:host=' . DB_HOST . ';dbname=' . DB_NAME . ';charset=' . DB_CHARSET,
            DB_USER,
            DB_PASS,
            [
                PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
                PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
                PDO::ATTR_EMULATE_PREPARES   => false,
            ]
        );
    }
    return $pdo;
}

// ─── 액세스 토큰 조회 (만료 시 자동 갱신) ──────────────────────────────
function getAccessToken(): string {
    $db  = getDb();
    $row = $db->query("SELECT * FROM kakao_tokens ORDER BY id DESC LIMIT 1")->fetch();
    if (!$row || empty($row['access_token'])) return '';

    // 만료 5분 전이면 갱신
    $expiresAt = strtotime($row['updated_at']) + (int)$row['expires_in'] - 300;
    if (time() > $expiresAt && !empty($row['refresh_token'])) {
        $newToken = refreshAccessToken($row['refresh_token']);
        return $newToken ?: $row['access_token'];
    }
    return $row['access_token'];
}

// ─── 토큰 저장 ────────────────────────────────────────────────────────
function saveTokens(array $data): void {
    $db = getDb();
    // TRUNCATE 는 DROP 권한이 필요 → DELETE FROM 으로 대체 (DELETE 권한만 필요)
    $db->exec("DELETE FROM kakao_tokens");
    $db->prepare(
        "INSERT INTO kakao_tokens (access_token, refresh_token, expires_in) VALUES (?,?,?)"
    )->execute([
        $data['access_token'],
        $data['refresh_token'] ?? '',
        $data['expires_in']    ?? 21599,
    ]);
}

// ─── 리프레시 토큰으로 액세스 토큰 갱신 ──────────────────────────────
// file_get_contents 대신 cURL 사용 (allow_url_fopen=Off 환경 대응)
function refreshAccessToken(string $refreshToken): string {
    $ch = curl_init('https://kauth.kakao.com/oauth/token');
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POST           => true,
        CURLOPT_HTTPHEADER     => ['Content-Type: application/x-www-form-urlencoded'],
        CURLOPT_POSTFIELDS     => http_build_query([
            'grant_type'    => 'refresh_token',
            'client_id'     => KAKAO_REST_API_KEY,
            'client_secret' => KAKAO_CLIENT_SECRET,
            'refresh_token' => $refreshToken,
        ]),
        CURLOPT_TIMEOUT        => 10,
        CURLOPT_SSL_VERIFYPEER => true,
    ]);
    $res = curl_exec($ch);
    curl_close($ch);

    $data = json_decode($res ?: '{}', true) ?: [];

    if (!empty($data['access_token'])) {
        // 새 refresh_token 이 내려오면 교체, 없으면 기존 유지
        $db  = getDb();
        $old = $db->query("SELECT refresh_token FROM kakao_tokens LIMIT 1")->fetch();
        saveTokens([
            'access_token'  => $data['access_token'],
            'refresh_token' => $data['refresh_token'] ?? ($old['refresh_token'] ?? ''),
            'expires_in'    => $data['expires_in']    ?? 21599,
        ]);
        return $data['access_token'];
    }
    return '';
}

// ─── 공통 응답 헬퍼 ───────────────────────────────────────────────────
function jsonOk(array $data = []): void {
    echo json_encode(['ok' => true] + $data, JSON_UNESCAPED_UNICODE);
    exit;
}

function jsonError(string $msg, int $code = 400): void {
    http_response_code($code);
    echo json_encode(['ok' => false, 'error' => $msg], JSON_UNESCAPED_UNICODE);
    exit;
}

// ─── API 키 검증 ──────────────────────────────────────────────────────
function requireApiKey(): void {
    $key = $_SERVER['HTTP_X_API_KEY'] ?? ($_GET['api_key'] ?? '');
    if ($key !== API_KEY) {
        http_response_code(401);
        echo json_encode(['ok' => false, 'error' => 'Unauthorized'], JSON_UNESCAPED_UNICODE);
        exit;
    }
}

// ─── Kakao REST API 요청 (cURL) ───────────────────────────────────────
function kakaoPost(string $url, array $formData, string $token): array {
    $ch = curl_init($url);
    curl_setopt_array($ch, [
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_POST           => true,
        CURLOPT_HTTPHEADER     => [
            'Authorization: Bearer ' . $token,
            'Content-Type: application/x-www-form-urlencoded;charset=utf-8',
        ],
        CURLOPT_POSTFIELDS     => http_build_query($formData),
        CURLOPT_TIMEOUT        => 15,
        CURLOPT_SSL_VERIFYPEER => true,
    ]);
    $body = curl_exec($ch);
    $code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    curl_close($ch);
    return ['code' => $code, 'body' => $body ?: ''];
}
