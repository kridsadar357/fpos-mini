#!/bin/sh
# Keep iOS build artifacts on /tmp so macOS Desktop/iCloud provenance does not break codesign.
set -eu

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
. "$ROOT/scripts/flutter_env.sh"
IOS_TMP="/tmp/fuel_pos_ios_build"
IOS_LINK="$ROOT/build/ios"

export COPYFILE_DISABLE=1

mkdir -p "$IOS_TMP"
mkdir -p "$ROOT/build"

if [ -L "$IOS_LINK" ] && [ ! -e "$IOS_LINK" ]; then
  rm -f "$IOS_LINK"
fi

if [ -d "$IOS_LINK" ] && [ ! -L "$IOS_LINK" ]; then
  if [ -n "$(ls -A "$IOS_LINK" 2>/dev/null || true)" ]; then
    ditto "$IOS_LINK" "$IOS_TMP" 2>/dev/null || rsync -a "$IOS_LINK/" "$IOS_TMP/" || true
  fi
  rm -rf "$IOS_LINK"
fi

if [ ! -L "$IOS_LINK" ]; then
  ln -sf "$IOS_TMP" "$IOS_LINK"
fi

xattr -cr "$ROOT/lib" 2>/dev/null || true
xattr -cr "$ROOT/.dart_tool" 2>/dev/null || true

if [ -n "${FLUTTER_ROOT:-}" ] && [ -d "$FLUTTER_ROOT/bin/cache/artifacts/engine" ]; then
  xattr -cr "$FLUTTER_ROOT/bin/cache/artifacts/engine" 2>/dev/null || true
fi
