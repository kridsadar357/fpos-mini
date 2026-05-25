#!/bin/sh
# Build release artifacts for App Store (.ipa) and Play Store (.aab)
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/scripts/flutter_env.sh"
OUT="$ROOT/store_release"
VERSION="$(grep '^version:' "$ROOT/pubspec.yaml" | sed 's/version: //' | tr -d ' ')"
NAME="fuelpos-${VERSION}"

mkdir -p "$OUT"
"$ROOT/scripts/setup_android_signing.sh"
"$ROOT/scripts/prepare_ios_build.sh"

cd "$ROOT"
export COPYFILE_DISABLE=1

echo "Flutter: $(flutter --version | head -1)"
flutter pub get

if command -v dart >/dev/null 2>&1; then
  dart run flutter_launcher_icons 2>/dev/null || true
fi

echo ""
echo "=== Building Android App Bundle (Play Store) ==="
flutter build appbundle --release
AAB_SRC="$ROOT/build/app/outputs/bundle/release/app-release.aab"
AAB_DST="$OUT/${NAME}.aab"
cp "$AAB_SRC" "$AAB_DST"

echo ""
echo "=== Building iOS IPA (App Store) ==="
flutter build ipa --release --export-options-plist="$ROOT/ios/ExportOptions.plist"
IPA_SRC="$(ls -t "$ROOT/build/ios/ipa/"*.ipa 2>/dev/null | head -1)"
if [ -z "$IPA_SRC" ]; then
  IPA_SRC="$(find "$ROOT/build/ios" -name '*.ipa' -print 2>/dev/null | head -1)"
fi
if [ -n "$IPA_SRC" ] && [ -f "$IPA_SRC" ]; then
  IPA_DST="$OUT/${NAME}.ipa"
  cp "$IPA_SRC" "$IPA_DST"
else
  echo "WARN: ไม่พบ .ipa — ลองเปิด Xcode → Product → Archive แล้ว Distribute App" >&2
fi

# Metadata bundle for store consoles
cat > "$OUT/RELEASE_INFO.txt" <<EOF
FUEL POS — Store upload bundle
Built: $(date)
Version: $VERSION
Android applicationId: com.ttmbtech.fuelpos
iOS bundleId: com.ttmbtech.fuelpos
Apple Team ID: JGZ59SA7RF

Files:
  ${NAME}.aab  → Google Play Console → Production → Create release → Upload
  ${NAME}.ipa  → Transporter app หรือ Xcode Organizer → Distribute App

Before first upload:
  1. สร้าง App ใน App Store Connect (bundle com.ttmbtech.fuelpos)
  2. สร้าง App ใน Google Play Console (package com.ttmbtech.fuelpos)
  3. อ่าน store_release/SUBMISSION_CHECKLIST.md
EOF

echo ""
echo "✓ Store release files:"
ls -lh "$OUT/${NAME}.aab" 2>/dev/null || true
ls -lh "$OUT/${NAME}.ipa" 2>/dev/null || true
ls -lh "$OUT/RELEASE_INFO.txt"
echo ""
echo "โฟลเดอร์: $OUT"
