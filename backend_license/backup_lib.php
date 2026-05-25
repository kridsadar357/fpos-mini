<?php
require_once __DIR__ . '/db_config.php';
require_once __DIR__ . '/backup_config.php';

function backup_json(int $code, array $payload): void
{
    http_response_code($code);
    header('Content-Type: application/json; charset=utf-8');
    echo json_encode($payload, JSON_UNESCAPED_UNICODE);
    exit;
}

function backup_error(int $code, string $message, array $extra = []): void
{
    backup_json($code, array_merge(['error' => $message], $extra));
}

function backup_read_token(): ?string
{
    $header = $_SERVER['HTTP_X_LICENSE_TOKEN'] ?? '';
    if ($header !== '') {
        return trim($header);
    }

    if (!empty($_POST['token'])) {
        return trim((string) $_POST['token']);
    }

    if (!empty($_GET['token'])) {
        return trim((string) $_GET['token']);
    }

    return null;
}

function backup_find_license(PDO $db, string $token): array
{
    $stmt = $db->prepare('SELECT * FROM licenses WHERE token = ? LIMIT 1');
    $stmt->execute([$token]);
    $license = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$license) {
        backup_error(403, 'Invalid license token');
    }

    $status = strtolower(trim($license['status'] ?? ''));
    if ($status !== 'active') {
        backup_error(403, 'License is not active', ['status' => $license['status']]);
    }

    $expiry = $license['expires_at'] ?? $license['expiry_date'] ?? null;
    if (!empty($expiry)) {
        $expiryTs = strtotime((string) $expiry);
        if ($expiryTs !== false && $expiryTs < time()) {
            backup_error(403, 'License expired', ['expiry_date' => $expiry]);
        }
    }

    return $license;
}

function backup_sanitize_basename(string $name): string
{
    $name = basename($name);
    $name = preg_replace('/[^a-zA-Z0-9._-]+/', '_', $name) ?? 'backup';
    $name = trim($name, '._-');
    return $name !== '' ? $name : 'backup';
}

function backup_allowed_extension(string $filename): ?string
{
    $ext = strtolower(pathinfo($filename, PATHINFO_EXTENSION));
    if ($ext === 'db' || $ext === 'sql') {
        return $ext;
    }
    return null;
}

function backup_storage_dir(int $licenseId): string
{
    $dir = BACKUP_STORAGE_ROOT . '/' . $licenseId;
    if (!is_dir($dir) && !mkdir($dir, 0750, true) && !is_dir($dir)) {
        backup_error(500, 'Could not create backup directory');
    }
    return $dir;
}

?>
