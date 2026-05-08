#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
DIST_DIR="${REPO_ROOT}/dist/gui_app"
BUILD_DIR="${REPO_ROOT}/mac_app/gui/build"

APP_VERSION="${APP_VERSION_OVERRIDE:-$(tr -d '\n' < "${REPO_ROOT}/VERSION")}"
APP_ARCHIVE="DBT-Agent-${APP_VERSION}.zip"
DOWNLOAD_BASE_URL="${DOWNLOAD_BASE_URL:-}"
ARCHIVE_URL=""

validate_gui_archive_assets() {
  local archive_path="$1"
  local listing_path="${DIST_DIR}/archive-contents.txt"
  local required_assets=(
    "DBT-Agent.app/Contents/Resources/BoardAssets/boards/TaishanPi/assets/models/1M-RK3566/preview.obj"
    "DBT-Agent.app/Contents/Resources/BoardAssets/boards/TaishanPi/assets/models/1M-RK3566/3D_PCB_2026-04-03.mtl"
    "DBT-Agent.app/Contents/Resources/BoardAssets/boards/ColorEasyPICO2/assets/models/ColorEasyPICO2/preview.obj"
    "DBT-Agent.app/Contents/Resources/BoardAssets/boards/ColorEasyPICO2/assets/models/ColorEasyPICO2/3D_PCB1_V1.0.4_2026-04-03.mtl"
    "DBT-Agent.app/Contents/Resources/Pico2WPreview.png"
  )

  unzip -Z1 "${archive_path}" > "${listing_path}"
  for asset in "${required_assets[@]}"; do
    if ! grep -Fxq "${asset}" "${listing_path}"; then
      echo "Release archive is missing required GUI asset: ${asset}" >&2
      echo "Archive listing saved to ${listing_path}" >&2
      exit 1
    fi
    local asset_probe_path="${DIST_DIR}/asset-probe.tmp"
    unzip -p "${archive_path}" "${asset}" > "${asset_probe_path}"
    if LC_ALL=C grep -a -q "git-lfs.github.com/spec" "${asset_probe_path}"; then
      rm -f "${asset_probe_path}"
      echo "Release archive contains a Git LFS pointer instead of the real GUI asset: ${asset}" >&2
      exit 1
    fi
    rm -f "${asset_probe_path}"
  done
  echo "Release archive board visual asset validation passed"
}

if [[ -n "${DOWNLOAD_BASE_URL}" ]]; then
  ARCHIVE_URL="${DOWNLOAD_BASE_URL%/}/${APP_ARCHIVE}"
fi

mkdir -p "${DIST_DIR}"
rm -rf "${DIST_DIR:?}"/*

"${REPO_ROOT}/mac_app/gui/build_gui_app.sh"

cp -f "${BUILD_DIR}/${APP_ARCHIVE}" "${DIST_DIR}/"
validate_gui_archive_assets "${DIST_DIR}/${APP_ARCHIVE}"

ARCHIVE_SHA256="$(shasum -a 256 "${DIST_DIR}/${APP_ARCHIVE}" | awk '{print $1}')"
GENERATED_AT="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

cat > "${DIST_DIR}/manifest.json" <<EOF
{
  "product": "gui_app",
  "name": "DBT-Agent",
  "bundle_name": "DBT-Agent.app",
  "archive_name": "${APP_ARCHIVE}",
  "version": "${APP_VERSION}",
  "update_manifest": "toolkit-manifest.json"
}
EOF

if [[ -n "${ARCHIVE_URL}" ]]; then
  cat > "${DIST_DIR}/toolkit-manifest.json" <<EOF
{
  "version": "${APP_VERSION}",
  "generated_at": "${GENERATED_AT}",
  "gui_app_bundle": "${APP_ARCHIVE}",
  "gui_app_sha256": "${ARCHIVE_SHA256}",
  "gui_app_url": "${ARCHIVE_URL}"
}
EOF
else
  cat > "${DIST_DIR}/toolkit-manifest.json" <<EOF
{
  "version": "${APP_VERSION}",
  "generated_at": "${GENERATED_AT}",
  "gui_app_bundle": "${APP_ARCHIVE}",
  "gui_app_sha256": "${ARCHIVE_SHA256}"
}
EOF
fi

echo "Packaged GUI release into ${DIST_DIR}"
