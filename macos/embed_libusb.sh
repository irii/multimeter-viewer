#!/bin/sh
# Copies libusb into the app's Frameworks folder and signs it, so the
# sandboxed app can load it (it cannot read /opt/homebrew at runtime).
# Override the source with LIBUSB_DYLIB=/path/to/libusb-1.0.0.dylib.
set -e

SRC="${LIBUSB_DYLIB}"
if [ -z "$SRC" ]; then
  for candidate in \
    /opt/homebrew/lib/libusb-1.0.0.dylib \
    /usr/local/lib/libusb-1.0.0.dylib \
    /opt/local/lib/libusb-1.0.0.dylib; do
    if [ -f "$candidate" ]; then
      SRC="$candidate"
      break
    fi
  done
fi

if [ -z "$SRC" ]; then
  echo "warning: libusb not found, install it with 'brew install libusb' or set LIBUSB_DYLIB"
  exit 0
fi

DEST_DIR="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
DEST="${DEST_DIR}/libusb-1.0.0.dylib"
mkdir -p "$DEST_DIR"
cp -fL "$SRC" "$DEST"
chmod u+w "$DEST"
install_name_tool -id "@rpath/libusb-1.0.0.dylib" "$DEST"
codesign --force --sign "${EXPANDED_CODE_SIGN_IDENTITY:--}" --timestamp=none "$DEST"
