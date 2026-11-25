-- 校园小助手：账号表（学号 / 教工号统一存 account_no）
CREATE TABLE IF NOT EXISTS user_account (
  id BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  account_no VARCHAR(32) NOT NULL COMMENT '学号或教工号，唯一',
  password_hash CHAR(64) NOT NULL COMMENT 'SHA-256(account_no:password)',
  role VARCHAR(16) NOT NULL COMMENT 'student / teacher / assistant',
  nickname VARCHAR(64) NOT NULL DEFAULT '' COMMENT '昵称，默认取学号/教工号',
  created_at BIGINT NOT NULL COMMENT '注册时间戳(ms)',
  updated_at BIGINT NOT NULL COMMENT '更新时间戳(ms)',
  PRIMARY KEY (id),
  UNIQUE KEY uk_account_no (account_no),
  KEY idx_role (role)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COMMENT = '校园小助手账号表';
