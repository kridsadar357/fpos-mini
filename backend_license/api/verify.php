<?php
// backend_license/api/verify.php
header('Content-Type: application/json');
require_once '../db_config.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['status' => 'error', 'message' => 'Method not allowed']);
    exit;
}

$input = json_decode(file_get_contents('php://input'), true);
$license_key = $input['license_key'] ?? '';
$device_id = $input['device_id'] ?? '';

if (empty($license_key) || empty($device_id)) {
    echo json_encode(['status' => 'error', 'message' => 'License key and device ID required']);
    exit;
}

$device_model = $input['device_model'] ?? 'Unknown';
$os_version = $input['os_version'] ?? 'Unknown';
$app_version = $input['app_version'] ?? 'Unknown';
$lat = $input['latitude'] ?? null;
$lng = $input['longitude'] ?? null;
$ip = $_SERVER['REMOTE_ADDR'] ?? '0.0.0.0';

$db = getDB();

try {
    $stmt = $db->prepare("SELECT * FROM licenses WHERE license_key = ? LIMIT 1");
    $stmt->execute([$license_key]);
    $license = $stmt->fetch(PDO::FETCH_ASSOC);

    if (!$license) {
        echo json_encode(['status' => 'error', 'message' => 'Invalid license key']);
        exit;
    }

    if ($license['status'] !== 'active') {
        echo json_encode(['status' => 'error', 'message' => 'This license has been revoked']);
        exit;
    }

    // Check if key is already locked to another device
    if (!empty($license['device_id']) && $license['device_id'] !== $device_id) {
        echo json_encode(['status' => 'error', 'message' => 'License already in use on another device']);
        exit;
    }

    // Activate or Update tracking info
    $stmt = $db->prepare("UPDATE licenses SET 
        device_id = ?, 
        device_model = ?, 
        os_version = ?, 
        app_version = ?, 
        latitude = ?, 
        longitude = ?, 
        last_ip = ?, 
        activated_at = IFNULL(activated_at, NOW()) 
        WHERE id = ?");
    $stmt->execute([
        $device_id, 
        $device_model, 
        $os_version, 
        $app_version, 
        $lat, 
        $lng, 
        $ip, 
        $license['id']
    ]);

    echo json_encode([
        'status' => 'success',
        'license_type' => $license['license_type'],
        'expires_at' => $license['expires_at'],
        'message' => 'License activated successfully'
    ]);

} catch (Exception $e) {
    echo json_encode(['status' => 'error', 'message' => 'Server error: ' . $e->getMessage()]);
}
?>
