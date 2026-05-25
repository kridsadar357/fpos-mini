<?php
/**
 * FUEL POS cloud backup receiver
 * POST https://ttmb-tech.com/license/backup
 *
 * Headers:
 *   Authorization: Bearer {license_key}
 *   Content-Type: application/octet-stream
 *   X-Backup-Source: fuel-pos
 *   X-Backup-Name: cloud_fuel_pos_....db
 *   X-Backup-Schema: 13
 *   X-Device-Id: (optional)
 */

require_once __DIR__ . '/../backup_lib.php';

if ($_SERVER['REQUEST_METHOD'] === 'GET') {
    backup_json_response(200, [
        'status' => 'ok',
        'service' => 'fpos-cloud-backup',
        'method' => 'POST',
        'max_bytes' => BACKUP_MAX_BYTES,
    ]);
}

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    backup_json_response(405, [
        'status' => 'error',
        'message' => 'Method not allowed',
    ]);
}

$licenseKey = backup_read_bearer_token();
if ($licenseKey === null || $licenseKey === '') {
    backup_json_response(401, [
        'status' => 'error',
        'message' => 'Missing Authorization Bearer token (use Product Key)',
    ]);
}

$db = getDB();
$license = backup_validate_license($db, $licenseKey);

$raw = file_get_contents('php://input');
if ($raw === false) {
    backup_json_response(400, [
        'status' => 'error',
        'message' => 'Empty request body',
    ]);
}

$size = strlen($raw);
if ($size < 512) {
    backup_json_response(400, [
        'status' => 'error',
        'message' => 'Backup file too small',
    ]);
}

if ($size > BACKUP_MAX_BYTES) {
    backup_json_response(413, [
        'status' => 'error',
        'message' => 'Backup exceeds maximum size',
        'max_bytes' => BACKUP_MAX_BYTES,
    ]);
}

if (!backup_is_sqlite($raw)) {
    backup_json_response(400, [
        'status' => 'error',
        'message' => 'Invalid SQLite backup file',
    ]);
}

$fileName = backup_sanitize_filename($_SERVER['HTTP_X_BACKUP_NAME'] ?? 'fuel_pos_backup.db');
$schemaVersion = (int) ($_SERVER['HTTP_X_BACKUP_SCHEMA'] ?? 0);
$source = preg_replace('/[^a-zA-Z0-9._-]/', '', $_SERVER['HTTP_X_BACKUP_SOURCE'] ?? 'fuel-pos') ?: 'fuel-pos';
$deviceId = $_SERVER['HTTP_X_DEVICE_ID'] ?? $license['device_id'] ?? null;
if (is_string($deviceId)) {
    $deviceId = substr(trim($deviceId), 0, 100);
} else {
    $deviceId = null;
}

$dir = backup_ensure_storage_dir($licenseKey);
$storedName = gmdate('Y-m-d_His') . '_' . $fileName;
$storedPath = $dir . '/' . $storedName;

if (file_put_contents($storedPath, $raw, LOCK_EX) === false) {
    backup_json_response(500, [
        'status' => 'error',
        'message' => 'Failed to write backup file',
    ]);
}

@chmod($storedPath, 0640);

try {
    $uploadId = backup_record_upload(
        $db,
        $license,
        $storedPath,
        $fileName,
        $size,
        $schemaVersion,
        $source,
        $deviceId
    );
    backup_trim_old_files($db, (int) $license['id'], $dir);
} catch (Exception $e) {
    @unlink($storedPath);
    backup_json_response(500, [
        'status' => 'error',
        'message' => 'Database error: ' . $e->getMessage(),
    ]);
}

backup_json_response(200, [
    'status' => 'success',
    'message' => 'Backup received',
    'upload_id' => $uploadId,
    'file_size' => $size,
    'stored_as' => $storedName,
    'schema_version' => $schemaVersion,
]);

?>
