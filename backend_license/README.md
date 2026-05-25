# FUEL POS — License & Cloud Backup Backend

Deploy โฟลเดอร์นี้ไปที่ `https://ttmb-tech.com/license/` บนเซิร์ฟเวอร์ PHP + MySQL

## Endpoints

| URL | ไฟล์ | วิธี |
|-----|------|------|
| `https://ttmb-tech.com/license/api.php` | (existing product verify) | GET |
| `https://ttmb-tech.com/license/backup` | `backup/index.php` | POST |

### Cloud backup — POST `/license/backup`

**Auth:** `Authorization: Bearer {Product Key}` (License key จากแอป)

**Headers จากแอป:**

```
Content-Type: application/octet-stream
X-Backup-Source: fuel-pos
X-Backup-Name: cloud_fuel_pos_....db
X-Backup-Schema: 13
X-Device-Id: {device_id}
X-Backup-Attempt: 1
```

**Body:** ไฟล์ SQLite `.db` (binary)

**Response 200:**

```json
{
  "status": "success",
  "message": "Backup received",
  "upload_id": 12,
  "file_size": 524288,
  "stored_as": "2026-05-22_143000_cloud_fuel_pos....db",
  "schema_version": 13
}
```

**GET `/license/backup`** — health check (ไม่ต้อง auth)

## ติดตั้งครั้งแรก

1. สร้าง DB และ import `schema.sql`
2. แก้ `db_config.php` (host, user, password)
3. อัปโหลดไฟล์ทั้งโฟลเดอร์ `backend_license/` ไป `/license/`
4. สร้างโฟลเดอร์ writable:
   ```bash
   chmod 750 storage/backups
   chown www-data:www-data storage/backups
   ```
5. ใน MySQL รัน migration ถ้ามี DB เดิม:
   ```sql
   CREATE TABLE IF NOT EXISTS backup_uploads (...);  -- ดู schema.sql
   ALTER TABLE licenses MODIFY license_type VARCHAR(20) NOT NULL DEFAULT 'free';
   ```

## ทดสอบด้วย curl

```bash
curl -s "https://ttmb-tech.com/license/backup"

curl -X POST "https://ttmb-tech.com/license/backup" \
  -H "Authorization: Bearer YOUR-PRO-LICENSE-KEY" \
  -H "Content-Type: application/octet-stream" \
  -H "X-Backup-Source: fuel-pos" \
  -H "X-Backup-Name: test_backup.db" \
  -H "X-Backup-Schema: 13" \
  --data-binary @fuel_pos_backup.db
```

## ความปลอดภัย

- ไฟล์เก็บใน `storage/backups/{sha256(license_key)}/` — ปิด direct access ด้วย `.htaccess`
- รับเฉพาะ license ประเภท **pro** / **enterprise** ที่ status = active
- จำกัดขนาด `BACKUP_MAX_BYTES` (default 50 MB) ใน `backup_config.php`
- เก็บไฟล์ล่าสุด `BACKUP_KEEP_PER_LICENSE` ต่อ license (default 20)

## แอป Flutter

ค่า default ในแอป:

- Endpoint: `https://ttmb-tech.com/license/backup`
- Token: Product Key (License key) — กรอกอัตโนมัติถ้าว่าง

เปิดใช้ที่ **หลังบ้าน → สำรองข้อมูล → สำรองคลาวด์** (ต้องมี License Pro+)
