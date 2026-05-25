-- Optional migration for existing license_db

ALTER TABLE licenses
  ADD COLUMN IF NOT EXISTS token VARCHAR(128) UNIQUE AFTER license_key;

ALTER TABLE licenses
  MODIFY status ENUM('pending', 'active', 'suspended', 'revoked') NOT NULL DEFAULT 'pending';
