<?php
/**
 * POST /license/backup/
 * multipart/form-data: file=@backup.db
 * Header: X-License-Token: {token from verify}
 */

require_once __DIR__ . '/../backup_lib.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    backup_error(405, 'Method not allowed');
}

$token = backup_read_token();
if ($token === null || $token === '') {
    backup_error(400, 'License token is required');
}

$db = getDB();
$license = backup_find_license($db, $token);
$licenseId = (int) $license['id'];

if (!isset($_FILES['file']) || !is_array($_FILES['file'])) {
    backup_error(400, 'File upload failed', ['upload_error' => UPLOAD_ERR_NO_FILE]);
}

$upload = $_FILES['file'];
$uploadError = (int) ($upload['error'] ?? UPLOAD_ERR_NO_FILE);
if ($uploadError !== UPLOAD_ERR_OK) {
    backup_error(400, 'File upload failed', ['upload_error' => $uploadError]);
}

$originalName = (string) ($upload['name'] ?? 'backup.db');
$ext = backup_allowed_extension($originalName);
if ($ext === null) {
    backup_error(415, 'Only .db and .sql files are allowed');
}

$size = (int) ($upload['size'] ?? 0);
if ($size <= 0) {
    backup_error(400, 'File upload failed', ['upload_error' => UPLOAD_ERR_NO_FILE]);
}

$safeBase = backup_sanitize_basename(pathinfo($originalName, PATHINFO_FILENAME));
$storedName = date('Ymd_His') . '_' . $safeBase . '.' . $ext;
$dir = backup_storage_dir($licenseId);
$destPath = $dir . '/' . $storedName;

if (!is_uploaded_file($upload['tmp_name'])) {
    backup_error(400, 'File upload failed', ['upload_error' => UPLOAD_ERR_NO_TMP_DIR]);
}

if (!move_uploaded_file($upload['tmp_name'], $destPath)) {
    backup_error(500, 'Could not save uploaded file');
}

@chmod($destPath, 0640);

backup_json(200, [
    'success' => true,
    'license_id' => $licenseId,
    'filename' => $storedName,
    'size' => $size,
]);

?>
