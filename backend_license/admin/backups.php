<?php
require_once '../db_config.php';
require_once '../backup_config.php';

$db = getDB();
$filterId = isset($_GET['license_id']) ? (int) $_GET['license_id'] : 0;

$licenses = $db->query('SELECT id, license_key, license_type, status FROM licenses ORDER BY id ASC')
    ->fetchAll(PDO::FETCH_ASSOC);
$licenseById = [];
foreach ($licenses as $l) {
    $licenseById[(int) $l['id']] = $l;
}

$entries = [];
$root = BACKUP_STORAGE_ROOT;
if (is_dir($root)) {
    foreach (scandir($root) as $dirName) {
        if ($dirName === '.' || $dirName === '..') {
            continue;
        }
        $dirPath = $root . '/' . $dirName;
        if (!is_dir($dirPath)) {
            continue;
        }
        if (!ctype_digit($dirName)) {
            continue;
        }
        $licenseId = (int) $dirName;
        if ($filterId > 0 && $licenseId !== $filterId) {
            continue;
        }
        foreach (scandir($dirPath) as $fileName) {
            if ($fileName === '.' || $fileName === '..') {
                continue;
            }
            $filePath = $dirPath . '/' . $fileName;
            if (!is_file($filePath)) {
                continue;
            }
            $entries[] = [
                'license_id' => $licenseId,
                'filename' => $fileName,
                'size' => filesize($filePath),
                'modified' => filemtime($filePath),
                'path' => $filePath,
            ];
        }
    }
}

usort($entries, static function ($a, $b) {
    return $b['modified'] <=> $a['modified'];
});

function fmt_bytes(int $bytes): string
{
    if ($bytes < 1024) {
        return $bytes . ' B';
    }
    if ($bytes < 1024 * 1024) {
        return round($bytes / 1024, 1) . ' KB';
    }
    return round($bytes / (1024 * 1024), 1) . ' MB';
}
?>
<!DOCTYPE html>
<html>
<head>
    <title>FUEL POS — Cloud Backups</title>
    <style>
        body { font-family: sans-serif; padding: 20px; background: #f4f4f4; }
        .container { background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        table { width: 100%; border-collapse: collapse; margin-top: 16px; }
        th, td { padding: 10px; border: 1px solid #ddd; text-align: left; font-size: 14px; }
        th { background: #eee; }
        a { color: #1e56a0; }
        .muted { color: #666; font-size: 13px; }
    </style>
</head>
<body>
    <div class="container">
        <p><a href="index.php">← License admin</a></p>
        <h1>Cloud Backups</h1>
        <p class="muted">ไฟล์จาก POST /license/backup/ — เก็บใน backup_storage/&lt;license_id&gt;/</p>

        <form method="get">
            <label>License ID
                <select name="license_id" onchange="this.form.submit()">
                    <option value="0">ทั้งหมด</option>
                    <?php foreach ($licenses as $l): ?>
                        <option value="<?php echo (int) $l['id']; ?>" <?php echo $filterId === (int) $l['id'] ? 'selected' : ''; ?>>
                            #<?php echo (int) $l['id']; ?> — <?php echo htmlspecialchars($l['license_key']); ?>
                        </option>
                    <?php endforeach; ?>
                </select>
            </label>
        </form>

        <?php if (empty($entries)): ?>
            <p class="muted">ยังไม่มีไฟล์สำรอง</p>
        <?php else: ?>
            <table>
                <thead>
                    <tr>
                        <th>License</th>
                        <th>ไฟล์</th>
                        <th>ขนาด</th>
                        <th>อัปโหลด</th>
                    </tr>
                </thead>
                <tbody>
                    <?php foreach ($entries as $e): ?>
                        <?php $lic = $licenseById[$e['license_id']] ?? null; ?>
                        <tr>
                            <td>
                                #<?php echo $e['license_id']; ?><br>
                                <code><?php echo htmlspecialchars($lic['license_key'] ?? '?'); ?></code>
                            </td>
                            <td><code><?php echo htmlspecialchars($e['filename']); ?></code></td>
                            <td><?php echo fmt_bytes((int) $e['size']); ?></td>
                            <td><?php echo date('Y-m-d H:i:s', $e['modified']); ?></td>
                        </tr>
                    <?php endforeach; ?>
                </tbody>
            </table>
        <?php endif; ?>
    </div>
</body>
</html>
