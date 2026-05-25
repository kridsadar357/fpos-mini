#!/bin/sh
# ติดตั้งแอปบน iPad โดยไม่ต้องรอ debug VM (ไม่ค้างที่ Installing and launching)
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/scripts/flutter_env.sh"
DEVICE="${1:-00008103-001039940E31001E}"

"$ROOT/scripts/prepare_ios_build.sh"
cd "$ROOT"
export COPYFILE_DISABLE=1

echo "Flutter: $(flutter --version | head -1)"
flutter pub get

echo "Building release..."
flutter build ios --release

APP="$ROOT/build/ios/iphoneos/Runner.app"
if [ ! -d "$APP" ]; then
  APP="/tmp/fuel_pos_ios_build/iphoneos/Runner.app"
fi
if [ ! -d "$APP" ]; then
  echo "ไม่พบ Runner.app — build ล้มเหลว" >&2
  exit 1
fi

echo "Installing to iPad..."
if xcrun devicectl device install app --device "$DEVICE" "$APP" 2>&1; then
  :
elif flutter install -d "$DEVICE" --use-application-binary="$APP" 2>/dev/null; then
  :
else
  echo "ติดตั้งด้วย devicectl/flutter ไม่สำเร็จ — ลอง Xcode → Window → Devices" >&2
  exit 1
fi

echo ""
echo "✓ ติดตั้งแล้ว — เปิดแอป \"Fuel Pos\" บน iPad ด้วยตนเอง"
echo "  (ไม่ต้องรอ flutter run / debug VM)"
