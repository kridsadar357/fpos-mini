<?php
require_once __DIR__ . '/db_config.php';
require_once __DIR__ . '/backup_config.php';

function backup_json_response(int $code, array $payload): void
{
    http_response_code($code);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($payload, JSON_UNESCAPED_UNICODE);
    exit;
}

function backup_read_bearer_token(): ?string
{
    $auth = $_SERVER['HTTP_AUTHORIZATION'] ?? $_SERVER['REDIRECT_HTTP_AUTHORIZATION'] ?? '';
    if (preg_match('/Bearer\s+(\S+)/i', $auth, $m)) {
        return trim($m[1]);
    }

    $fallback = $_SERVER['HTTP_X_LICENSE_KEY'] ?? '';
    return $fallback !== '' ? trim($fallback) : null;
}

function backup_license_allows_cloud(array $license): bool
{
    $type = strtolower(trim($license['license_type'] ?? 'free'));
    return in_array($type, BACKUP_ALLOWED_TYPES, true);
}

function backup_validate_license(PDO $db, string $licenseKey): array
{
    $stmt = $db->prepare('SELECT * FROM licenses WHERE license_key = ? LIMIT 1');
    $stmt->execute([$licenseKey]);
    $license = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$license) {
        backup_json_response(401, [
            'status' => 'error',
            'message' => 'Invalid license key',
        ]);
    }

    if (($license['status'] ?? '') !== 'active') {
        backup_json_response(403, [
            'status' => 'error',
            'message' => 'License is not active',
        ]);
    }

    if (!backup_license_allows_cloud($license)) {
        backup_json_response(403, [
            'status' => 'error',
            'message' => 'Cloud backup requires Pro or Enterprise license',
        ]);
    }

    return $license;
}

function backup_sanitize_filename(string $name): string
{
    $name = basename($name);
    $name = preg_replace('/[^a-zA-Z0-9._-]+/', '_', $name) ?? 'fuel_pos_backup.db';
    if (strlen($name) < 4 || substr(strtolower($name), -3) !== '.db') {
        $name .= '.db';
    }
    return $name;
}

function backup_is_sqlite(string $bytes): bool
{
    return strncmp($bytes, 'SQLite format 3', 15) === 0;
}

function backup_ensure_storage_dir(string $licenseKey): string
{
    $dir = BACKUP_STORAGE_ROOT . '/' . hash('sha256', $licenseKey);
    if (!is_dir($dir) && !mkdir($dir, 0750, true) && !is_dir($dir)) {
        backup_json_response(500, [
            'status' => 'error',
            'message' => 'Cannot create storage directory',
        ]);
    }
    return $dir;
}

function backup_trim_old_files(PDO $db, int $licenseId, string $dir): void
{
    $stmt = $db->prepare(
        'SELECT id, stored_path FROM backup_uploads
         WHERE license_id = ?
         ORDER BY created_at DESC, id DESC'
    );
    $stmt->execute([$licenseId]);
    $rows = $stmt->fetchAll(PDO::FETCH_ASSOC);

    if (count($rows) <= BACKUP_KEEP_PER_LICENSE) {
        return;
    }

    $toDelete = array_slice($rows, BACKUP_KEEP_PER_LICENSE);
    $delStmt = $db->prepare('DELETE FROM backup_uploads WHERE id = ?');

    foreach ($toDelete as $row) {
        $path = $row['stored_path'];
        if (is_string($path) && is_file($path)) {
            @unlink($path);
        }
        $delStmt->execute([(int) $row['id']]);
    }
}

function backup_record_upload(
    PDO $db,
    array $license,
    string $storedPath,
    string $fileName,
    int $fileSize,
    int $schemaVersion,
    string $source,
    ?string $deviceId
): int {
    $stmt = $db->prepare(
        'INSERT INTO backup_uploads
         (license_id, license_key, device_id, file_name, stored_path, file_size,
          schema_version, source, client_ip, created_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())'
    );
    $stmt->execute([
        (int) $license['id'],
        $license['license_key'],
        $deviceId,
        $fileName,
        $storedPath,
        $fileSize,
        $schemaVersion,
        $source,
        $_SERVER['REMOTE_ADDR'] ?? null,
    ]);

    return (int) $db->lastInsertId();
}

?>
