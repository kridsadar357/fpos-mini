#!/bin/sh
# อย่าใช้ `flutter run` เปล่า — มักค้างตอนสแกน iPad wireless
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/scripts/flutter_env.sh"
cd "$ROOT"

DEVICE="${1:-}"
if [ -z "$DEVICE" ]; then
  echo "กำลังค้นหา device (USB/simulator เท่านั้น, timeout 12s)..."
  flutter devices --device-timeout=12 --device-connection attached 2>&1 || true
  echo ""
  echo "ใช้คำสั่งพร้อมระบุ device เช่น:"
  echo "  ./scripts/run.sh emulator-5554          # Android emulator"
  echo "  ./scripts/run.sh macos                    # macOS"
  echo "  ./scripts/run_ios_release.sh -d <ipad-id> # iPad (แนะนำ — ไม่ค้าง debug)"
  echo "  ./scripts/run_ios.sh -d <ipad-id>         # iPad debug (ต้องอนุญาต Automation)"
  exit 1
fi

shift || true
exec flutter run -d "$DEVICE" --device-connection attached --device-timeout=120 "$@"
