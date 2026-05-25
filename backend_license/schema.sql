-- backend_license/schema.sql

CREATE DATABASE IF NOT EXISTS license_db;
USE license_db;

CREATE TABLE IF NOT EXISTS licenses (
    id INT AUTO_INCREMENT PRIMARY KEY,
    license_key VARCHAR(50) UNIQUE NOT NULL,
    license_type ENUM('free', 'pro') DEFAULT 'free',
    device_id VARCHAR(100),
    device_model VARCHAR(100),
    os_version VARCHAR(50),
    app_version VARCHAR(50),
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    last_ip VARCHAR(45),
    activated_at DATETIME,
    expires_at DATETIME,
    status ENUM('active', 'revoked') DEFAULT 'active'
);

-- Seed some test keys
INSERT INTO licenses (license_key, license_type) VALUES ('FPOS-FREE-TEST', 'free');
INSERT INTO licenses (license_key, license_type) VALUES ('FPOS-PRO-TEST', 'pro');
