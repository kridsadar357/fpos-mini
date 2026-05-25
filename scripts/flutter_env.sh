#!/bin/sh
# Use one Flutter SDK only. Mixing ~/develop/flutter with Homebrew breaks iOS builds.
if [ -x "/opt/homebrew/share/flutter/bin/flutter" ]; then
  export PATH="/opt/homebrew/share/flutter/bin:$PATH"
  export FLUTTER_ROOT="/opt/homebrew/share/flutter"
elif [ -n "${FLUTTER_ROOT:-}" ] && [ -x "$FLUTTER_ROOT/bin/flutter" ]; then
  export PATH="$FLUTTER_ROOT/bin:$PATH"
else
  echo "ไม่พบ Flutter SDK — ติดตั้งที่ /opt/homebrew/share/flutter หรือตั้ง FLUTTER_ROOT" >&2
  exit 1
fi

VERSION="$(flutter --version 2>/dev/null | head -1 || true)"
case "$VERSION" in
  *"develop/flutter"*)
    echo "ERROR: กำลังใช้ Flutter จาก ~/develop/flutter — จะ build ไม่ผ่าน" >&2
    echo "รัน: export PATH=/opt/homebrew/share/flutter/bin:\$PATH" >&2
    exit 1
    ;;
esac
