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

if [[ -n "${DOWNLOAD_BASE_URL}" ]]; then
  ARCHIVE_URL="${DOWNLOAD_BASE_URL%/}/${APP_ARCHIVE}"
fi

mkdir -p "${DIST_DIR}"
rm -rf "${DIST_DIR:?}"/*

"${REPO_ROOT}/mac_app/gui/build_gui_app.sh"

cp -f "${BUILD_DIR}/${APP_ARCHIVE}" "${DIST_DIR}/"

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
