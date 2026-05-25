# FUEL POS — License & Cloud Backup Backend

Reference implementation aligned with the production API on `ttmb-tech.com`.

## Upload Backup

**`POST /license/backup/`**

Accepts a `.db` or `.sql` file and stores it under `backup_storage/<license_id>/`. Requires a valid `token` belonging to an `active`, non-expired license.

### Request

`Content-Type: multipart/form-data`

| Field | In | Required | Notes |
| --- | --- | --- | --- |
| `file` | form-data | yes | The `.db` or `.sql` file |
| token | header `X-License-Token`, or form field `token`, or `?token=` | yes | Token returned by the verify endpoint |

Example:

```sh
curl -X POST https://ttmb-tech.com/license/backup/ \
  -H "X-License-Token: a1b2c3..." \
  -F "file=@./mydata.db"
```

Saved as: `backup_storage/<license_id>/YYYYMMDD_HHMMSS_<sanitized-name>.<ext>`

### Response — 200 OK

```json
{
  "success": true,
  "license_id": 12,
  "filename": "20260524_143015_mydata.db",
  "size": 102400
}
```

### Error responses

| Code | Body | Meaning |
| --- | --- | --- |
| 400 | `{ "error": "License token is required" }` | Token not provided |
| 400 | `{ "error": "File upload failed", "upload_error": <code> }` | Missing file or PHP upload error |
| 403 | `{ "error": "Invalid license token" }` | Token not found |
| 403 | `{ "error": "License is not active", "status": "..." }` | Wrong status |
| 403 | `{ "error": "License expired", "expiry_date": "..." }` | Past expiry |
| 405 | `{ "error": "Method not allowed" }` | Non-POST request |
| 415 | `{ "error": "Only .db and .sql files are allowed" }` | Bad extension |
| 500 | `{ "error": "Could not create backup directory" }` | Filesystem error |
| 500 | `{ "error": "Could not save uploaded file" }` | `move_uploaded_file` failed |

## Flutter app

- Endpoint default: `https://ttmb-tech.com/license/backup/`
- Token: `license_token` from Product Key verify (not the Product Key itself)
- Upload: `MultipartRequest` field `file` + header `X-License-Token`

## Deploy

1. Upload `backend_license/` to `/license/` on the server
2. Import / migrate `schema.sql` (licenses must include `token` column)
3. Ensure `backup_storage/` is writable by PHP and not listable from web
4. Set PHP `upload_max_filesize` / `post_max_size` for expected backup size
5. Admin: `/license/admin/` — จัดการ license + ดู backup ที่ `/license/admin/backups.php`

### ใช้ token จาก hosting DB ในแอป

1. ตรวจว่า verify API ส่ง `"token"` ใน JSON response
2. แอป → **ตั้งค่าทั่วไป → ตรวจสอบ License ใหม่** (เก็บ `license_token` อัตโนมัติ)
3. หรือ **สำรองข้อมูล → คลาวด์ → ซิงค์ token** / วาง token จาก DB เอง

## License status reference

| Status | Meaning |
| --- | --- |
| `pending` | Issued but never verified |
| `active` | Usable |
| `suspended` | Temporarily disabled |
| `revoked` | Permanently disabled |
