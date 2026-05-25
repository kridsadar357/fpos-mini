#!/bin/sh
# รันบน iPad แบบ release — ไม่ใช้ Xcode Automation / Dart VM (หลีกเลี่ยงค้าง Installing and launching)
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/scripts/flutter_env.sh"
"$ROOT/scripts/prepare_ios_build.sh"
cd "$ROOT"
export COPYFILE_DISABLE=1

exec flutter run --release --device-connection attached "$@"
