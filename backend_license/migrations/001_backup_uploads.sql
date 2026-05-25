-- Run once on existing license_db servers

ALTER TABLE licenses
  MODIFY license_type VARCHAR(20) NOT NULL DEFAULT 'free';

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
