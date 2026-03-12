#!/usr/bin/env bash
set -euo pipefail

APP_NAME="WhisperCppRealtimeMacApp"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
EXPORT_ROOT="${PROJECT_DIR}/dist"
APP_BUNDLE="${EXPORT_ROOT}/${APP_NAME}.app"
ZIP_PATH="${EXPORT_ROOT}/${APP_NAME}.zip"
INFO_PLIST_SOURCE="${PROJECT_DIR}/Resources/Info.plist"

echo "Building ${APP_NAME} in release mode..."
swift build \
  --configuration release \
  --package-path "${PROJECT_DIR}" \
  --product "${APP_NAME}"

BIN_DIR="$(swift build --configuration release --package-path "${PROJECT_DIR}" --show-bin-path)"
EXECUTABLE_PATH="${BIN_DIR}/${APP_NAME}"

if [[ ! -x "${EXECUTABLE_PATH}" ]]; then
  echo "Expected executable not found at ${EXECUTABLE_PATH}" >&2
  exit 1
fi

rm -rf "${APP_BUNDLE}" "${ZIP_PATH}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${EXECUTABLE_PATH}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "${INFO_PLIST_SOURCE}" "${APP_BUNDLE}/Contents/Info.plist"
printf 'APPL????' > "${APP_BUNDLE}/Contents/PkgInfo"

if command -v codesign >/dev/null 2>&1; then
  echo "Applying ad-hoc signature..."
  codesign --force --deep --sign - "${APP_BUNDLE}" >/dev/null
fi

echo "Creating zip archive..."
mkdir -p "${EXPORT_ROOT}"
ditto -c -k --keepParent "${APP_BUNDLE}" "${ZIP_PATH}"

echo
echo "Export complete:"
echo "  App bundle: ${APP_BUNDLE}"
echo "  Zip archive: ${ZIP_PATH}"
echo
echo "You can now double-click the .app in Finder."
