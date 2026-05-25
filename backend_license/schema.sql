-- backend_license/schema.sql

CREATE DATABASE IF NOT EXISTS license_db;
USE license_db;

CREATE TABLE IF NOT EXISTS licenses (
    id INT AUTO_INCREMENT PRIMARY KEY,
    license_key VARCHAR(50) UNIQUE NOT NULL,
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
    status ENUM('active', 'revoked') DEFAULT 'active'
);

CREATE TABLE IF NOT EXISTS backup_uploads (
    id INT AUTO_INCREMENT PRIMARY KEY,
    license_id INT NOT NULL,
    license_key VARCHAR(50) NOT NULL,
    device_id VARCHAR(100),
    file_name VARCHAR(255) NOT NULL,
    stored_path VARCHAR(512) NOT NULL,
    file_size BIGINT NOT NULL,
    schema_version INT NOT NULL DEFAULT 0,
    source VARCHAR(50) NOT NULL DEFAULT 'fuel-pos',
    client_ip VARCHAR(45),
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_backup_license_created (license_id, created_at),
    CONSTRAINT fk_backup_license FOREIGN KEY (license_id)
        REFERENCES licenses(id) ON DELETE CASCADE
);

-- Seed some test keys
INSERT INTO licenses (license_key, license_type) VALUES ('FPOS-FREE-TEST', 'free');
INSERT INTO licenses (license_key, license_type) VALUES ('FPOS-PRO-TEST', 'pro');
