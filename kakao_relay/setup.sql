-- ═══════════════════════════════════════════════════════════════════════
--  kakao_relay / setup.sql
--  MySQL 5.7+ / MariaDB 10.2+ 호환
--
--  사용법:
--    mysql -u root -p < setup.sql
--  또는 phpMyAdmin에서 직접 실행
-- ═══════════════════════════════════════════════════════════════════════

-- DB 생성
CREATE DATABASE IF NOT EXISTS kakao_relay
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE kakao_relay;

-- ─── 1. OAuth 토큰 저장 ──────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS kakao_tokens (
  id            INT          AUTO_INCREMENT PRIMARY KEY,
  access_token  VARCHAR(2000) NOT NULL,
  refresh_token VARCHAR(2000) DEFAULT '',
  expires_in    INT           DEFAULT 21599,  -- 초 단위 (기본 6시간)
  updated_at    DATETIME      DEFAULT CURRENT_TIMESTAMP
                              ON UPDATE CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ─── 2. 카카오 채널봇 수신 메시지 큐 ────────────────────────────────
--  skill.php 가 Kakao OpenBuilder 에서 수신한 발화를 저장
--  Flutter 앱은 api.php?action=poll 로 주기적으로 조회
CREATE TABLE IF NOT EXISTS kakao_messages (
  id          INT      AUTO_INCREMENT PRIMARY KEY,
  user_key    VARCHAR(255) DEFAULT '',  -- Kakao 사용자 고유 키
  user_id     VARCHAR(255) DEFAULT '',  -- plusfriendUserKey (채널 친구 ID)
  utterance   TEXT         NOT NULL,    -- 사용자 발화 내용
  received_at DATETIME     DEFAULT CURRENT_TIMESTAMP,
  is_read     TINYINT(1)   DEFAULT 0,   -- 0: 미읽음, 1: 읽음
  raw_json    MEDIUMTEXT   DEFAULT NULL -- OpenBuilder 원본 요청 전체
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE INDEX IF NOT EXISTS idx_messages_is_read     ON kakao_messages (is_read);
CREATE INDEX IF NOT EXISTS idx_messages_received_at ON kakao_messages (received_at);

-- ─── 3. 전송 로그 ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS send_log (
  id       INT          AUTO_INCREMENT PRIMARY KEY,
  target   VARCHAR(50)  DEFAULT 'self',  -- 'self' | 'user'
  receiver VARCHAR(255) DEFAULT '',      -- 수신자 UUID (target=user 일 때)
  message  TEXT,
  status   VARCHAR(50)  DEFAULT 'ok',    -- 'ok' | 'error'
  error    VARCHAR(500) DEFAULT '',
  sent_at  DATETIME     DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ─── 4. 웹훅 진단 로그 ───────────────────────────────────────────────
--  skill.php 에 들어오는 모든 요청을 파싱 성공/실패와 무관하게 기록.
--  카카오 서버가 실제로 호출하는지, JSON 구조가 예상과 다른지 진단용.
CREATE TABLE IF NOT EXISTS webhook_log (
  id           INT      AUTO_INCREMENT PRIMARY KEY,
  method       VARCHAR(10)  DEFAULT '',
  remote_ip    VARCHAR(64)  DEFAULT '',
  raw_body     MEDIUMTEXT   DEFAULT NULL,
  parse_result VARCHAR(255) DEFAULT '',   -- 'saved:ID' | 'empty_utterance' | 'db_error:...'
  created_at   DATETIME     DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ─── DB 유저 권한 설정 (필수 실행) ───────────────────────────────────
-- config.php 의 DB_USER / DB_PASS 와 일치해야 합니다.
-- root 권한으로 실행하세요.
--
-- 유저가 없으면 생성:
CREATE USER IF NOT EXISTS 'mediain'@'localhost' IDENTIFIED BY 'tkdtn0902';

-- kakao_relay DB 에 필요한 최소 권한 부여
-- (SELECT, INSERT, UPDATE, DELETE 만으로 충분 — TRUNCATE 불필요)
GRANT SELECT, INSERT, UPDATE, DELETE ON kakao_relay.* TO 'mediain'@'localhost';
FLUSH PRIVILEGES;

-- ─── 기존 DB에 이미 setup.sql 을 실행했던 경우, webhook_log 테이블만 추가하려면: ───
-- USE kakao_relay;
-- CREATE TABLE IF NOT EXISTS webhook_log (
--   id           INT      AUTO_INCREMENT PRIMARY KEY,
--   method       VARCHAR(10)  DEFAULT '',
--   remote_ip    VARCHAR(64)  DEFAULT '',
--   raw_body     MEDIUMTEXT   DEFAULT NULL,
--   parse_result VARCHAR(255) DEFAULT '',
--   created_at   DATETIME     DEFAULT CURRENT_TIMESTAMP
-- ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
