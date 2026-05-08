#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
BUILD_DIR="${SCRIPT_DIR}/build"
APP_NAME="DBT-Agent"
APP_DISPLAY_NAME="${APP_DISPLAY_NAME:-Embed Labs}"
APP_DIR="${BUILD_DIR}/${APP_NAME}.app"
BIN_DIR="${APP_DIR}/Contents/MacOS"
RES_DIR="${APP_DIR}/Contents/Resources"
BIN_PATH="${BIN_DIR}/${APP_NAME}"
ICON_SOURCE="${REPO_ROOT}/assets/app-logo.png"
INFO_LOGO_SOURCE="${REPO_ROOT}/assets/app-logo.png"
INFO_LOGO_LIGHT_SOURCE="${REPO_ROOT}/assets/app-logo-light.png"
INFO_LOGO_DARK_SOURCE="${REPO_ROOT}/assets/app-logo-dark.png"
ALIPAY_QR_SOURCE="${REPO_ROOT}/assets/zhifubao.JPG"
WECHAT_QR_SOURCE="${REPO_ROOT}/assets/weixin.JPG"
PICO2W_PREVIEW_SOURCE="${REPO_ROOT}/assets/Pico2WPreview.png"
BOARD_ASSETS_SOURCE="${REPO_ROOT}/board_plugins/boards"
BOARD_ASSETS_DEST="${RES_DIR}/BoardAssets/boards"
REQUIRE_BOARD_ASSETS="${REQUIRE_BOARD_ASSETS:-1}"
GUI_RESOURCES_SOURCE="${SCRIPT_DIR}/Resources"
ICONSET_DIR="${BUILD_DIR}/AppIcon.iconset"
ICON_MASTER="${BUILD_DIR}/AppIcon-master.png"
DEFAULT_APP_VERSION="$(tr -d '\n' < "${REPO_ROOT}/VERSION" 2>/dev/null || printf '1.0.0')"
APP_VERSION="${APP_VERSION_OVERRIDE:-${DEFAULT_APP_VERSION}}"
APP_BUILD="${APP_BUILD:-1}"
APP_ARCHIVE="${BUILD_DIR}/${APP_NAME}-${APP_VERSION}.zip"
LEGACY_APP_NAME="RK356xToolkitGUI"
rm -rf "${BUILD_DIR}/${LEGACY_APP_NAME}.app"
rm -f "${BUILD_DIR}/${LEGACY_APP_NAME}-"*.zip
rm -rf "${BUILD_DIR}/DevelopmentBoardToolchain.app"
rm -f "${BUILD_DIR}/DevelopmentBoardToolchain-"*.zip
rm -rf "${BUILD_DIR}/DBT.app"
rm -f "${BUILD_DIR}/DBT-"*.zip

build_icon() {
  if [[ ! -f "${ICON_SOURCE}" ]]; then
    echo "Icon source not found at ${ICON_SOURCE}; skipping icon build"
    return 0
  fi

  if ! command -v sips >/dev/null 2>&1; then
    echo "sips not available; skipping icon build"
    return 0
  fi

  if ! command -v iconutil >/dev/null 2>&1; then
    echo "iconutil not available; skipping icon build"
    return 0
  fi

  rm -rf "${ICONSET_DIR}"
  mkdir -p "${ICONSET_DIR}"

  local width height edge
  width="$(sips -g pixelWidth "${ICON_SOURCE}" 2>/dev/null | awk '/pixelWidth:/ {print $2}')"
  height="$(sips -g pixelHeight "${ICON_SOURCE}" 2>/dev/null | awk '/pixelHeight:/ {print $2}')"
  if [[ -z "${width}" || -z "${height}" ]]; then
    echo "Unable to inspect icon source dimensions; skipping icon build"
    return 0
  fi
  edge="${width}"
  if (( height > edge )); then
    edge="${height}"
  fi

  cp -f "${ICON_SOURCE}" "${ICON_MASTER}"
  if ! sips --padColor F3F0E8 --padToHeightWidth "${edge}" "${edge}" "${ICON_MASTER}" >/dev/null 2>&1; then
    echo "Failed to pad icon master image; skipping icon build"
    return 0
  fi

  local entries=(
    "16:icon_16x16.png"
    "32:icon_16x16@2x.png"
    "32:icon_32x32.png"
    "64:icon_32x32@2x.png"
    "128:icon_128x128.png"
    "256:icon_128x128@2x.png"
    "256:icon_256x256.png"
    "512:icon_256x256@2x.png"
    "512:icon_512x512.png"
    "1024:icon_512x512@2x.png"
  )

  local entry size name
  for entry in "${entries[@]}"; do
    size="${entry%%:*}"
    name="${entry#*:}"
    if ! sips -z "${size}" "${size}" "${ICON_MASTER}" --out "${ICONSET_DIR}/${name}" >/dev/null 2>&1; then
      echo "Failed to generate icon size ${size}; skipping icon build"
      return 0
    fi
  done

  if ! iconutil -c icns "${ICONSET_DIR}" -o "${RES_DIR}/AppIcon.icns" >/dev/null 2>&1; then
    echo "iconutil failed; skipping icon build"
    return 0
  fi
}

echo "Building ${APP_DISPLAY_NAME} (${APP_NAME}) ${APP_VERSION} in ${BUILD_DIR}"
rm -rf "${APP_DIR}"
mkdir -p "${BIN_DIR}" "${RES_DIR}"

echo "Compiling GUI executable"
swiftc \
  -parse-as-library \
  -framework SwiftUI \
  -framework AppKit \
  -framework IOKit \
  -framework SceneKit \
  -framework SystemConfiguration \
  "${SCRIPT_DIR}/DevelopmentBoardToolchainGUI.swift" \
  -o "${BIN_PATH}"

echo "Writing Info.plist"
cat >"${APP_DIR}/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>com.developmentboard.toolchain.gui</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${APP_DISPLAY_NAME}</string>
  <key>CFBundleDisplayName</key>
  <string>${APP_DISPLAY_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${APP_VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${APP_BUILD}</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
EOF

echo "Building app icon"
build_icon

if [[ -f "${INFO_LOGO_SOURCE}" ]]; then
  echo "Copying info logo"
  cp -f "${INFO_LOGO_SOURCE}" "${RES_DIR}/AppInfoLogo.png"
fi

if [[ -f "${INFO_LOGO_LIGHT_SOURCE}" ]]; then
  echo "Copying light info logo"
  cp -f "${INFO_LOGO_LIGHT_SOURCE}" "${RES_DIR}/AppInfoLogoLight.png"
fi

if [[ -f "${INFO_LOGO_DARK_SOURCE}" ]]; then
  echo "Copying dark info logo"
  cp -f "${INFO_LOGO_DARK_SOURCE}" "${RES_DIR}/AppInfoLogoDark.png"
fi

if [[ -f "${ALIPAY_QR_SOURCE}" ]]; then
  echo "Copying Alipay QR"
  cp -f "${ALIPAY_QR_SOURCE}" "${RES_DIR}/ContactAlipay.jpg"
fi

if [[ -f "${WECHAT_QR_SOURCE}" ]]; then
  echo "Copying WeChat QR"
  cp -f "${WECHAT_QR_SOURCE}" "${RES_DIR}/ContactWeChat.jpg"
fi

if [[ -f "${PICO2W_PREVIEW_SOURCE}" ]]; then
  echo "Copying Pico 2 W preview"
  cp -f "${PICO2W_PREVIEW_SOURCE}" "${RES_DIR}/Pico2WPreview.png"
fi

if [[ -d "${BOARD_ASSETS_SOURCE}" ]]; then
  echo "Copying board visual assets"
  mkdir -p "${BOARD_ASSETS_DEST}"
  for board_dir in "${BOARD_ASSETS_SOURCE}"/*; do
    [[ -d "${board_dir}/assets" ]] || continue
    board_id="$(basename "${board_dir}")"
    mkdir -p "${BOARD_ASSETS_DEST}/${board_id}"
    ditto "${board_dir}/assets" "${BOARD_ASSETS_DEST}/${board_id}/assets"
  done
  find "${BOARD_ASSETS_DEST}" -type f | sort
elif [[ "${REQUIRE_BOARD_ASSETS}" == "1" ]]; then
  echo "Board visual assets source not found at ${BOARD_ASSETS_SOURCE}" >&2
  exit 1
fi

if [[ -d "${GUI_RESOURCES_SOURCE}" ]]; then
  echo "Copying GUI localization resources"
  ditto "${GUI_RESOURCES_SOURCE}" "${RES_DIR}"
fi

echo "Packaging app archive"
rm -f "${APP_ARCHIVE}"
(cd "${BUILD_DIR}" && ditto -c -k --sequesterRsrc --keepParent "${APP_NAME}.app" "$(basename "${APP_ARCHIVE}")")

echo "Built app: ${APP_DIR}"
echo "Archive: ${APP_ARCHIVE}"
echo "Run: open \"${APP_DIR}\""
