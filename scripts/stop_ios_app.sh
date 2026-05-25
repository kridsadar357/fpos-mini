#!/bin/sh
# บังคับปิดหรือถอน Fuel Pos บน iPad (เมื่อแอปค้าง / ออกไม่ได้)
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/scripts/flutter_env.sh"

BUNDLE_ID="com.example.fuelPos"
DEVICE="00008103-001039940E31001E"
MODE="force"

usage() {
  cat <<'EOF'
ใช้งาน: ./scripts/stop_ios_app.sh [kill|uninstall|force] [device-id]

  kill        พยายามบังคับปิด process (อาจไม่สำเร็จถ้า iPad ค้าง)
  uninstall   ถอนแอป Fuel Pos ออกจาก iPad
  force       ถอนแอปทันที — ใช้เมื่อ iPad ค้างในแอป (ค่าเริ่มต้น)

ตัวอย่าง:
  ./scripts/stop_ios_app.sh
  ./scripts/stop_ios_app.sh kill
  ./scripts/stop_ios_app.sh uninstall 00008103-001039940E31001E
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    -h|--help|help)
      usage
      exit 0
      ;;
    kill|uninstall|force)
      MODE="$1"
      shift
      ;;
    *)
      DEVICE="$1"
      shift
      ;;
  esac
done

try_kill_process() {
  json="$(mktemp "${TMPDIR:-/tmp}/fuel_pos_procs.XXXXXX")"
  trap 'rm -f "$json"' EXIT INT TERM

  echo "กำลังค้นหา process Fuel Pos บน iPad…"
  if ! xcrun devicectl device info processes \
    --device "$DEVICE" \
    --filter "bundleIdentifier == '$BUNDLE_ID'" \
    --json-output "$json" \
    --timeout 12 2>/dev/null; then
    echo "ไม่สามารถดึงรายการ process ได้ (iPad อาจค้างหรือ devicectl timeout)" >&2
    return 1
  fi

  pid="$(python3 - "$json" <<'PY'
import json, sys
path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    data = json.load(f)
procs = data.get("result", {}).get("runningProcesses", [])
target = "com.example.fuelPos"
for proc in procs:
    if proc.get("bundleIdentifier") == target:
        print(proc.get("processIdentifier", ""))
        break
PY
)"

  if [ -z "$pid" ]; then
    echo "ไม่พบ Fuel Pos ที่กำลังรันอยู่"
    return 0
  fi

  echo "กำลังบังคับปิด PID $pid…"
  xcrun devicectl device process terminate \
    --device "$DEVICE" \
    --pid "$pid" \
    --kill \
    --timeout 15
  echo "✓ บังคับปิด Fuel Pos แล้ว"
}

try_terminate_via_launch() {
  echo "ลอง terminate ผ่าน devicectl launch --terminate-existing…"
  if xcrun devicectl device process launch \
    --device "$DEVICE" \
    "$BUNDLE_ID" \
    --terminate-existing \
    --no-activate \
    --start-stopped \
    --timeout 12 2>/dev/null; then
    echo "✓ ส่งคำสั่ง terminate แล้ว"
    return 0
  fi
  return 1
}

uninstall_app() {
  echo "กำลังถอน Fuel Pos ($BUNDLE_ID) จาก iPad…"
  xcrun devicectl device uninstall app \
    --device "$DEVICE" \
    "$BUNDLE_ID" \
    --timeout 30
  echo "✓ ถอนแอป Fuel Pos แล้ว — iPad ใช้งานได้ตามปกติ"
  echo "  ติดตั้งใหม่: ./scripts/install_ios.sh"
}

print_manual_exit() {
  cat <<'EOF'

ถ้า iPad ยังค้าง:
  1. ปัดขึ้นจากขอบล่าง → ค้าง → ปัด Fuel Pos ขึ้น
  2. หรือรัน: ./scripts/stop_ios_app.sh uninstall
  3. หรือรีสตาร์ท iPad (Vol Up → Vol Down → กด Power ค้าง)
EOF
}

case "$MODE" in
  kill)
    if try_kill_process || try_terminate_via_launch; then
      exit 0
    fi
    echo "บังคับปิดจาก Mac ไม่สำเร็จ" >&2
    print_manual_exit
    exit 1
    ;;
  uninstall)
    uninstall_app
    ;;
  force)
    if try_kill_process || try_terminate_via_launch; then
      exit 0
    fi
    echo "บังคับปิดไม่สำเร็จ — ถอนแอปแทน (วิธีที่ได้ผลเมื่อ iPad ค้าง)…"
    uninstall_app
    ;;
  *)
    usage >&2
    exit 1
    ;;
esac
