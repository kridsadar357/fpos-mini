# FUEL POS — ระบบขายน้ำมันปั๊ม (Flutter + SQLite)

แอป POS สำหรับปั๊มน้ำมัน รองรับมือถือ/แท็บเล็ต พิมพ์ใบเสร็จ Bluetooth (ESC/POS 58/80 mm) เสียง TTS ภาษาไทย และสำรองข้อมูล

## โฟลว์หลัก (หลัง Login)

```
Login
  └─▶ แดชบอร์ด POS (แท็บ)
        ├─ ขายน้ำมัน — เลือกหัวจ่าย / ปริมาณ / ชำระเงิน / สรุป / สำเร็จ
        ├─ สินค้าหน้าร้าน
        ├─ สรุปยอดวันนี้
        ├─ ลูกค้า
        └─ ตั้งค่า (Admin) → ระบบหลังบ้าน
```

**แคชเชียร์** ใช้แดชบอร์ดขายได้ครบ  
**ผู้ดูแลระบบ** เข้า **ตั้งค่า → ระบบหลังบ้าน** ได้เพิ่ม:

| เมนู | รายละเอียด |
|------|------------|
| คลังน้ำมัน | ดูถัง / เติมสต็อก |
| ภาพรวมรายวัน | รายได้ ลิตร กราฟช่องทางชำระ รายการขาย |
| จัดการสินค้า | CRUD สินค้าหน้าร้าน |
| โปรโมชั่น (Pro) | ส่วนลด % / คงที่ / ต่อลิตร |
| ราคาน้ำมัน | แก้ราคา / เปิด-ปิดชนิดน้ำมัน |
| เครื่องพิมพ์ | Bluetooth 58/80 mm ทดสอบพิมพ์ |
| ออกแบบใบเสร็จ | ลากเรียงบล็อก header/body/footer |
| สำรองข้อมูล (Pro) | ส่งออก .db / CSV / คลาวด์ / กู้คืน |
| ผู้ใช้งาน | แคชเชียร์ / แอดมิน |
| บันทึกกิจกรรม | login / sale / print / logout / restore |
| ตั้งค่าทั่วไป | ชื่อปั๊ม ที่อยู่ เลขภาษี ท้ายใบเสร็จ TTS |

## ฟีเจอร์สำคัญ

- **แดชบอร์ดเดียว** — ขายน้ำมัน แขวนบิล ฟลีทการ์ด ทะเบียนรถ พิมพ์สลิป / รีปริ้นท์
- **SQLite WAL** — schema v2 (สินค้า ลูกค้า บิลพัก  audit_log)
- **เครื่องพิมพ์** — `print_bluetooth_thermal` + `esc_pos_utils` แม่แบบใบเสร็จ JSON ปรับได้
- **TTS** — ยืนยันเสียง (ปิดได้จากหลังบ้าน)
- **Session timeout** — 30 นาที
- **สำรองอัตโนมัติ** — รันตอนเปิดแอป (splash) ถ้าเปิด cloud
- **Pro license** — โปรโมชั่น + cloud backup

## Tech stack

- Flutter 3.13+ / Dart 3.1+
- sqflite, provider, intl, fl_chart
- print_bluetooth_thermal, esc_pos_utils, permission_handler
- flutter_tts, file_picker, share_plus, http

## บัญชีเริ่มต้น

| Username | Password | Role |
|----------|----------|------|
| admin | admin123 | admin |
| cashier | cashier123 | cashier |

เปลี่ยนรหัสทันทีที่ **หลังบ้าน → ผู้ใช้งาน**

## Build & Run

```bash
flutter pub get
flutter run
flutter analyze
flutter test
flutter build apk --release
```

**ไอคอน / splash (หลังเปลี่ยน assets):**

```bash
dart run flutter_launcher_icons
# จากนั้น flutter clean && flutter run
```

## โครงสร้างโปรเจกต์ (ย่อ)

```
lib/
├── core/           constants, database, printer, receipt, backup, session, tts
├── data/           models + repositories
└── presentation/
    ├── providers/  app_state
    ├── widgets/    dashboard, dialogs, keypad, logo
    └── screens/
        ├── splash_screen, login_screen, pos_dashboard_screen
        ├── receive_amount_screen, summary_screen, success_screen
        ├── dashboard_* (products, customers, daily summary)
        └── backend/  (home, audit, products, printer, receipt designer, …)
```

## การตั้งค่าเครื่องพิมพ์ Bluetooth

1. จับคู่เครื่องพิมพ์ใน **Settings → Bluetooth** ของแท็บเล็ต
2. แอป → **หลังบ้าน → เครื่องพิมพ์** → สแกน → แตะชื่อเครื่อง
3. เลือก **58 mm** หรือ **80 mm** ตามม้วนกระดาษ
4. **พิมพ์หน้าทดสอบ** แล้วปรับแม่แบบที่ **ออกแบบใบเสร็จ**

## หมายเหตุ

- โฟลว์เก่า (`PosScreen` / `PaymentMethodScreen` / `FuelAmountScreen`) ถูกลบแล้ว — ใช้แดชบอร์ดเป็นหลัก
- ทดสอบพิมพ์จริงต้องใช้อุปกรณ์ Android + เครื่องพิมพ์ thermal ที่จับคู่แล้ว
