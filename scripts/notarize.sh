#!/usr/bin/env bash
# ==============================================================================
# Script: notarize.sh
# Project: MultiDock
#
# Description:
#   Submits MultiDock.app (or release zip) to Apple's Notary Service using
#   'xcrun notarytool', waits for the ticket, and staples the notarization ticket
#   to MultiDock.app so that macOS Gatekeeper approves the app instantly on
#   public downloads (Product Hunt, GitHub Releases, Homebrew Cask).
#
# Usage:
#   ./scripts/notarize.sh <keychain-profile-name>
#
# Setup Credentials (One-time):
#   xcrun notarytool store-credentials "AC_PASSWORD" \
#       --apple-id "developer@example.com" \
#       --team-id "TEAM_ID" \
#       --password "xxxx-xxxx-xxxx-xxxx"
#
# Then run:
#   ./scripts/notarize.sh AC_PASSWORD
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BUILD_DIR="${ROOT_DIR}/build"
APP_BUNDLE="${BUILD_DIR}/MultiDock.app"

KEYCHAIN_PROFILE="${1:-}"

if [[ -z "${KEYCHAIN_PROFILE}" ]]; then
    echo "Usage: ./scripts/notarize.sh <keychain-profile-name>"
    echo ""
    echo "To set up a keychain profile with Apple, run:"
    echo "  xcrun notarytool store-credentials \"notarytool-profile\" \\"
    echo "      --apple-id \"your-apple-id@email.com\" \\"
    echo "      --team-id \"YOUR_10_CHAR_TEAM_ID\" \\"
    echo "      --password \"your-app-specific-password\""
    echo ""
    echo "Then run: ./scripts/notarize.sh notarytool-profile"
    exit 1
fi

if [[ ! -d "${APP_BUNDLE}" ]]; then
    echo "Error: MultiDock.app not found at '${APP_BUNDLE}'. Run ./scripts/build_app.sh first." >&2
    exit 1
fi

ZIP_PATH="${BUILD_DIR}/MultiDock-notarize.zip"
echo "==> Creating temporary archive for notarization submission..."
ditto -c -k --keepParent "${APP_BUNDLE}" "${ZIP_PATH}"

echo "==> Submitting to Apple Notary Service (profile: ${KEYCHAIN_PROFILE})..."
xcrun notarytool submit "${ZIP_PATH}" --keychain-profile "${KEYCHAIN_PROFILE}" --wait

echo "==> Stapling notarization ticket to MultiDock.app..."
xcrun stapler staple "${APP_BUNDLE}"

echo "==> Validating staple..."
xcrun stapler validate "${APP_BUNDLE}"

# Clean up temp archive
rm -f "${ZIP_PATH}"

echo "==> Notarization and stapling complete! MultiDock is fully cleared for Gatekeeper."
