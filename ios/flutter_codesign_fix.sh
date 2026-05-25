#!/bin/sh
# macOS Desktop/iCloud adds com.apple.provenance which breaks iOS codesign.
# iOS build output goes to /tmp via FLUTTER_BUILD_DIR in Debug/Release.xcconfig.
export COPYFILE_DISABLE=1

PROJECT_ROOT="${PROJECT_DIR}/.."

xattr -cr "${PROJECT_ROOT}/lib" 2>/dev/null || true
xattr -cr "${PROJECT_ROOT}/.dart_tool" 2>/dev/null || true

if [ -n "$FLUTTER_ROOT" ]; then
  xattr -cr "$FLUTTER_ROOT/bin/cache/artifacts/engine" 2>/dev/null || true
fi

if [ -n "$BUILT_PRODUCTS_DIR" ]; then
  xattr -cr "$BUILT_PRODUCTS_DIR" 2>/dev/null || true
fi

if [ -n "$TARGET_BUILD_DIR" ]; then
  xattr -cr "$TARGET_BUILD_DIR" 2>/dev/null || true
fi
