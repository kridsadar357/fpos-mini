# FUEL POS — Store submission checklist

Build artifacts:

```bash
./scripts/build_store_release.sh
```

Output folder: `store_release/`

| File | Upload to |
|------|-----------|
| `fuelpos-1.0.0+1.aab` | [Google Play Console](https://play.google.com/console) → Release → Production |
| `fuelpos-1.0.0+1.ipa` | [Transporter](https://apps.apple.com/app/transporter/id1450874784) or Xcode Organizer |

---

## App identifiers (production)

| Platform | ID |
|----------|-----|
| Android | `com.ttmbtech.fuelpos` |
| iOS | `com.ttmbtech.fuelpos` |
| Apple Team | `JGZ59SA7RF` |
| Version | `1.0.0` (build `1`) — จาก `pubspec.yaml` |

---

## ก่อนอัปโหลดครั้งแรก

### Apple App Store Connect

1. สร้าง App ใหม่ → Bundle ID `com.ttmbtech.fuelpos`
2. ลงทะเบียน App ID ใน [Apple Developer](https://developer.apple.com/account/resources/identifiers/list) (ถ้ายังไม่มี)
3. เปิด Xcode → Signing & Capabilities → Team `JGZ59SA7RF`, Automatic signing
4. กรอกข้อมูล App Store:
   - ชื่อ: **FUEL POS**
   - หมวด: Business / Productivity
   - ภาษา: Thai (+ English ถ้าต้องการ)
5. **Privacy Nutrition Labels:** ข้อมูลที่เก็บ — ขาย/สต็อกในเครื่อง (SQLite), ไม่ส่ง PII ไป server ยกเว้น cloud backup (Pro)
6. **App Review notes:** บัญชีทดสอบ `admin` / `admin123` — เปลี่ยนรหัส production ก่อนปล่อยจริง
7. Screenshots: iPad 12.9" + iPhone 6.7" (อย่างน้อย)

### Google Play Console

1. สร้าง App → Package `com.ttmbtech.fuelpos`
2. **App signing:** ใช้ upload key จาก `android/app/upload-keystore.jks`  
   รหัสอยู่ใน `store_release/SIGNING_CREDENTIALS.txt` (สร้างโดย `setup_android_signing.sh`)
3. **Data safety form:**
   - Bluetooth — เชื่อมต่อเครื่องพิมพ์
   - Location — สแกน Bluetooth (Android)
   - Files — สำรอง/กู้คืน .db
   - ไม่เก็บข้อมูลส่วนบุคคลส่ง third party (ยกเว้น cloud backup ถ้าเปิด)
4. Content rating: Business app questionnaire
5. Screenshots: Phone + 7" tablet + 10" tablet

---

## Android signing (ครั้งแรก)

```bash
./scripts/setup_android_signing.sh
```

เก็บ `upload-keystore.jks` และรหัผ่านไว้ปลอดภัย — **สูญหายแล้วอัปเดตแอปไม่ได้**

---

## iOS signing

- ใช้ Automatic signing + Distribution certificate จาก Apple Developer
- ถ้า `flutter build ipa` ล้มเหลว → Xcode → Product → Archive → Distribute App → App Store Connect

---

## หลังอนุมัติ Store

- [ ] เปลี่ยนรหัส `admin` / `cashier` เริ่มต้น
- [ ] ทดสอบ cloud backup บน production license server
- [ ] อัป `version` ใน `pubspec.yaml` ทุกครั้งที่ปล่อยเวอร์ชันใหม่ (`1.0.1+2`)
