<?php
// Shared cloud backup settings for /license/backup

// Maximum upload size (bytes) — adjust on server if needed
define('BACKUP_MAX_BYTES', 50 * 1024 * 1024);

// Keep newest N files per license on disk
define('BACKUP_KEEP_PER_LICENSE', 20);

// License tiers allowed to upload (matches Flutter AppFeature.cloudBackup)
define('BACKUP_ALLOWED_TYPES', ['pro', 'enterprise']);

// Storage root (outside public URL if possible; protected by .htaccess)
define('BACKUP_STORAGE_ROOT', __DIR__ . '/storage/backups');

?>
