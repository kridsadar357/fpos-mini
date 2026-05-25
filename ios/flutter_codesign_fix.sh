#!/bin/sh
# macOS Desktop/iCloud adds com.apple.provenance on source files — strip before build.
# Do NOT xattr build products after codesign (breaks Info.plist signature).
export COPYFILE_DISABLE=1

PROJECT_ROOT="${PROJECT_DIR}/.."
IOS_TMP="/tmp/fuel_pos_ios_build"
IOS_LINK="${PROJECT_ROOT}/build/ios"

mkdir -p "$IOS_TMP"
mkdir -p "${PROJECT_ROOT}/build"

if [ -L "$IOS_LINK" ] && [ ! -e "$IOS_LINK" ]; then
  rm -f "$IOS_LINK"
fi

if [ -d "$IOS_LINK" ] && [ ! -L "$IOS_LINK" ]; then
  rm -rf "$IOS_LINK"
fi

if [ ! -L "$IOS_LINK" ]; then
  ln -sf "$IOS_TMP" "$IOS_LINK"
fi

xattr -cr "${PROJECT_ROOT}/lib" 2>/dev/null || true
xattr -cr "${PROJECT_ROOT}/.dart_tool" 2>/dev/null || true

if [ -n "$FLUTTER_ROOT" ]; then
  xattr -cr "$FLUTTER_ROOT/bin/cache/artifacts/engine" 2>/dev/null || true
fi
