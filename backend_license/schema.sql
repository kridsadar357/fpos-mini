-- Reference schema (align with production license server)

CREATE DATABASE IF NOT EXISTS license_db;
USE license_db;

CREATE TABLE IF NOT EXISTS licenses (
    id INT AUTO_INCREMENT PRIMARY KEY,
    license_key VARCHAR(50) UNIQUE NOT NULL,
    token VARCHAR(128) UNIQUE,
    license_type VARCHAR(20) NOT NULL DEFAULT 'free',
    device_id VARCHAR(100),
    device_model VARCHAR(100),
    os_version VARCHAR(50),
    app_version VARCHAR(50),
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    last_ip VARCHAR(45),
    activated_at DATETIME,
    expires_at DATETIME,
    status ENUM('pending', 'active', 'suspended', 'revoked') NOT NULL DEFAULT 'pending',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO licenses (license_key, token, license_type, status)
VALUES ('FPOS-PRO-TEST', 'test-token-replace-me', 'pro', 'active')
ON DUPLICATE KEY UPDATE license_key = license_key;
