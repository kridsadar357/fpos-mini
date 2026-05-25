<?php
require_once '../db_config.php';
$db = getDB();

function admin_generate_token(): string
{
    return bin2hex(random_bytes(16));
}

$message = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if (isset($_POST['generate'])) {
        $key = 'FPOS-' . strtoupper(substr(md5(uniqid()), 0, 8)) . '-' . strtoupper(substr(md5(uniqid()), 8, 8));
        $token = admin_generate_token();
        $type = $_POST['type'] ?? 'free';
        try {
            $stmt = $db->prepare(
                'INSERT INTO licenses (license_key, token, license_type, status) VALUES (?, ?, ?, ?)'
            );
            $stmt->execute([$key, $token, $type, 'pending']);
            $message = "Generated: <strong>$key</strong> ($type)<br>Token: <code>$token</code>";
        } catch (Exception $e) {
            $message = 'Error: ' . $e->getMessage();
        }
    }

    if (isset($_POST['reset'])) {
        $id = $_POST['license_id'];
        try {
            $stmt = $db->prepare('UPDATE licenses SET device_id = NULL, activated_at = NULL WHERE id = ?');
            $stmt->execute([$id]);
            $message = 'License reset successfully';
        } catch (Exception $e) {
            $message = 'Error: ' . $e->getMessage();
        }
    }
}

$licenses = $db->query('SELECT * FROM licenses ORDER BY id DESC')->fetchAll(PDO::FETCH_ASSOC);
?>
<!DOCTYPE html>
<html>
<head>
    <title>Fuel POS License Manager</title>
    <style>
        body { font-family: sans-serif; padding: 20px; background: #f4f4f4; }
        .container { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        table { width: 100%; border-collapse: collapse; margin-top: 20px; }
        th, td { padding: 12px; border: 1px solid #ddd; text-align: left; font-size: 13px; }
        th { background: #eee; }
        .btn { padding: 8px 16px; cursor: pointer; border-radius: 4px; border: none; }
        .btn-gen { background: #2ecc71; color: white; }
        .btn-reset { background: #e67e22; color: white; }
        .alert { padding: 15px; background: #d4edda; border: 1px solid #c3e6cb; margin-bottom: 20px; border-radius: 4px; }
        a { color: #1e56a0; }
        code { font-size: 12px; }
    </style>
</head>
<body>
    <div class="container">
        <h1>License Management</h1>
        <p><a href="backups.php">ดู Cloud Backups →</a></p>

        <?php if ($message): ?>
            <div class="alert"><?php echo $message; ?></div>
        <?php endif; ?>

        <form method="POST">
            <select name="type">
                <option value="free">FREE</option>
                <option value="standard">STANDARD</option>
                <option value="pro">PRO</option>
                <option value="enterprise">ENTERPRISE</option>
            </select>
            <button type="submit" name="generate" class="btn btn-gen">Generate New Key + Token</button>
        </form>

        <table>
            <thead>
                <tr>
                    <th>ID</th>
                    <th>Key</th>
                    <th>Token</th>
                    <th>Type</th>
                    <th>Device</th>
                    <th>Status</th>
                    <th>Backups</th>
                    <th>Action</th>
                </tr>
            </thead>
            <tbody>
                <?php foreach ($licenses as $l): ?>
                <tr>
                    <td><?php echo $l['id']; ?></td>
                    <td><code><?php echo htmlspecialchars($l['license_key']); ?></code></td>
                    <td>
                        <?php if (!empty($l['token'])): ?>
                            <code>…<?php echo htmlspecialchars(substr($l['token'], -8)); ?></code>
                        <?php else: ?>
                            <em>—</em>
                        <?php endif; ?>
                    </td>
                    <td><strong><?php echo strtoupper($l['license_type']); ?></strong></td>
                    <td><?php echo $l['device_id'] ? htmlspecialchars($l['device_id']) : '<em>Not Activated</em>'; ?></td>
                    <td><?php echo htmlspecialchars($l['status']); ?></td>
                    <td><a href="backups.php?license_id=<?php echo (int) $l['id']; ?>">ดู</a></td>
                    <td>
                        <?php if ($l['device_id']): ?>
                        <form method="POST" style="display:inline;">
                            <input type="hidden" name="license_id" value="<?php echo $l['id']; ?>">
                            <button type="submit" name="reset" class="btn btn-reset">Reset Device</button>
                        </form>
                        <?php endif; ?>
                    </td>
                </tr>
                <?php endforeach; ?>
            </tbody>
        </table>
    </div>
</body>
</html>
