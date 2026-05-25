<?php
// backend_license/db_config.php

define('DB_HOST', 'localhost');
define('DB_NAME', 'license_db');
define('DB_USER', 'root');
define('DB_PASS', '');

function getDB() {
    try {
        $db = new PDO("mysql:host=".DB_HOST.";dbname=".DB_NAME.";charset=utf8", DB_USER, DB_PASS);
        $db->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
        return $db;
    } catch (PDOException $e) {
        die(json_encode(['status' => 'error', 'message' => 'Database connection failed']));
    }
}

// SQL Schema:
/*
CREATE TABLE licenses (
    id INT AUTO_INCREMENT PRIMARY KEY,
    license_key VARCHAR(50) UNIQUE NOT NULL,
    license_type ENUM('free', 'pro') DEFAULT 'free',
    device_id VARCHAR(100),
    activated_at DATETIME,
    expires_at DATETIME,
    status ENUM('active', 'revoked') DEFAULT 'active'
);
*/
?>
