#!/bin/sh
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/scripts/flutter_env.sh"
"$ROOT/scripts/prepare_ios_build.sh"
cd "$ROOT"
export COPYFILE_DISABLE=1

# บังคับ USB — wireless มักทำให้ debug ค้าง
# Debug mode ต้องอนุญาต Terminal/Cursor ควบคุม Xcode (Settings → Privacy → Automation)
# ถ้าค้างที่ Installing and launching ให้ใช้ ./scripts/run_ios_release.sh หรือ ./scripts/install_ios.sh แทน
exec flutter run --device-connection attached --device-timeout=120 "$@"
