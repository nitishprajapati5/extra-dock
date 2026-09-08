#!/usr/bin/env bash
# ==============================================================================
# Script: make_cask.sh
# Project: OrbitDock
#
# Description:
#   Prepares a release archive (.zip) from OrbitDock.app and generates a
#   ready-to-publish Homebrew Cask formula (.rb) with the computed SHA-256
#   checksum and download URL.
#   Automatically defaults the release version from the root VERSION file if
#   not explicitly provided as a command-line argument.
#
# Usage:
#   ./scripts/make_cask.sh [version] [github_username_or_org]
#
# Examples:
#   ./scripts/make_cask.sh                                # Uses VERSION file
#   ./scripts/make_cask.sh 1.0.0 nitishmahendraprajapati
#   ./scripts/make_cask.sh 1.2.0 myorg
# ==============================================================================

# Enable strict shell error handling:
#   -e: Exit immediately if a command exits with a non-zero status
#   -u: Treat unset variables as an error when substituting
#   -o pipefail: Pipeline return status is that of the last command to fail
set -euo pipefail

# ------------------------------------------------------------------------------
# 1. Arguments & Path Configuration
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
VERSION_FILE="${ROOT_DIR}/VERSION"

# Read version: CLI argument > VERSION file > default 1.0.0
VERSION="${1:-}"
if [[ -z "${VERSION}" && -f "${VERSION_FILE}" ]]; then
    VERSION="$(tr -d '[:space:]' < "${VERSION_FILE}")"
fi
VERSION="${VERSION:-1.0.0}"

# Read GitHub username/org: CLI argument > git remote or fallback
USER_OR_ORG="${2:-yourname}"
APP_NAME="OrbitDock"

# Determine project paths relative to this script's directory
BUILD_DIR="${ROOT_DIR}/build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
ZIP_FILE="${BUILD_DIR}/${APP_NAME}-${VERSION}.zip"

# ------------------------------------------------------------------------------
# 2. Verify or Trigger App Build
# ------------------------------------------------------------------------------
# If the .app bundle does not exist yet, invoke build_app.sh automatically
if [[ ! -d "${APP_BUNDLE}" ]]; then
    echo "==> App bundle not found at '${APP_BUNDLE}'. Building app first..."
    APP_VERSION="${VERSION}" "${SCRIPT_DIR}/build_app.sh"
fi

# ------------------------------------------------------------------------------
# 3. Create Release Archive (.zip)
# ------------------------------------------------------------------------------
# We use Apple's 'ditto' utility instead of standard zip:
#   -c -k: Create a PKZip archive format
#   --keepParent: Preserves the top-level 'OrbitDock.app' directory inside the zip
# 'ditto' accurately preserves macOS extended attributes, code signatures, and file permissions.
echo "==> Creating release archive: ${ZIP_FILE}..."
cd "${BUILD_DIR}"
ditto -c -k --keepParent "${APP_NAME}.app" "${ZIP_FILE}"

# ------------------------------------------------------------------------------
# 4. Calculate Checksum & Generate Homebrew Cask
# ------------------------------------------------------------------------------
# Compute the SHA-256 cryptographic hash of the release archive
SHA256="$(shasum -a 256 "${ZIP_FILE}" | awk '{print $1}')"

# Homebrew Cask names follow standard lowercase convention
CASK_NAME="$(echo "${APP_NAME}" | tr '[:upper:]' '[:lower:]')"
CASK_FILE="${BUILD_DIR}/${CASK_NAME}.rb"

# Generate the Homebrew Cask Ruby definition file
cat <<EOF > "${CASK_FILE}"
cask "${CASK_NAME}" do
  version "${VERSION}"
  sha256 "${SHA256}"

  url "https://github.com/${USER_OR_ORG}/${APP_NAME}/releases/download/v#{version}/${APP_NAME}-#{version}.zip"
  name "${APP_NAME}"
  desc "Lightweight, customizable multi-dock application for macOS"
  homepage "https://github.com/${USER_OR_ORG}/${APP_NAME}"

  app "${APP_NAME}.app"

  zap trash: [
    "~/Library/Application Support/OrbitDock",
    "~/Library/Preferences/com.orbitdock.OrbitDock.plist",
  ]
end
EOF

# ------------------------------------------------------------------------------
# 5. Output Summary
# ------------------------------------------------------------------------------
echo "==> Generated Homebrew Cask: ${CASK_FILE}"
echo "----------------------------------------------------"
cat "${CASK_FILE}"
echo "----------------------------------------------------"
echo "Next steps:"
echo "  1. Upload '${ZIP_FILE}' to GitHub Releases under tag 'v${VERSION}'."
echo "  2. Submit '${CASK_FILE}' to your Homebrew tap repository."
