#!/bin/sh
# สร้าง Android upload keystore ครั้งแรก (Play Store ต้องใช้ keystore เดิมตลอด)
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
KEYSTORE="$ROOT/android/app/upload-keystore.jks"
PROPS="$ROOT/android/key.properties"
EXAMPLE="$ROOT/android/key.properties.example"

if [ -f "$KEYSTORE" ] && [ -f "$PROPS" ]; then
  echo "✓ มี keystore แล้ว: $KEYSTORE"
  exit 0
fi

STORE_PASS="${STORE_PASSWORD:-FuelPos2026Upload!}"
KEY_PASS="${KEY_PASSWORD:-$STORE_PASS}"
ALIAS="${KEY_ALIAS:-upload}"

echo "สร้าง upload keystore สำหรับ Play Store…"
keytool -genkeypair -v \
  -keystore "$KEYSTORE" \
  -storetype PKCS12 \
  -storepass "$STORE_PASS" \
  -keypass "$KEY_PASS" \
  -alias "$ALIAS" \
  -keyalg RSA \
  -keysize 2048 \
  -validity 10000 \
  -dname "CN=TTMB Tech, OU=Mobile, O=TTMB Tech, L=Bangkok, ST=Bangkok, C=TH"

cat > "$PROPS" <<EOF
storePassword=$STORE_PASS
keyPassword=$KEY_PASS
keyAlias=$ALIAS
storeFile=upload-keystore.jks
EOF

CREDS="$ROOT/store_release/SIGNING_CREDENTIALS.txt"
mkdir -p "$ROOT/store_release"
cat > "$CREDS" <<EOF
Android upload keystore (เก็บไฟล์นี้ไว้ปลอดภัย — ห้าม commit)
Keystore: android/app/upload-keystore.jks
Alias: $ALIAS
Store password: $STORE_PASS
Key password: $KEY_PASS
Created: $(date)
EOF
chmod 600 "$CREDS" 2>/dev/null || true

echo ""
echo "✓ สร้าง keystore แล้ว"
echo "  Keystore: $KEYSTORE"
echo "  Config:   $PROPS"
echo "  บันทึกรหัสผ่านไว้ที่: $CREDS"
echo ""
echo "เปลี่ยนรหัสได้ด้วย env: STORE_PASSWORD=... KEY_PASSWORD=... $0"
