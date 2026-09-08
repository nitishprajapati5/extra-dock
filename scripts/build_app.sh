#!/usr/bin/env bash
# ==============================================================================
# Script: build_app.sh
# Project: MultiDock
#
# Description:
#   Compiles MultiDock in Release mode using Swift Package Manager and packages
#   the resulting executable into a standalone, runnable macOS application
#   bundle (MultiDock.app).
#   Automatically synchronizes the Semantic Version (from VERSION file or
#   APP_VERSION environment variable) and Build Number (git commit count or
#   BUILD_NUMBER) into Info.plist before signing the bundle ad-hoc for smooth
#   local execution and Gatekeeper compatibility on macOS.
#
# Usage:
#   ./scripts/build_app.sh
#   APP_VERSION=1.1.0 ./scripts/build_app.sh
#
# Requirements:
#   - macOS with Xcode Command Line Tools or Xcode installed (swift, codesign, plutil)
# ==============================================================================

# Enable strict shell error handling:
#   -e: Exit immediately if a command exits with a non-zero status
#   -u: Treat unset variables as an error when substituting
#   -o pipefail: Pipeline return status is that of the last command to fail
set -euo pipefail

# ------------------------------------------------------------------------------
# 1. Path Configuration & Version Resolution
# ------------------------------------------------------------------------------
# Resolve the repository root directory relative to this script's location,
# ensuring the script works reliably regardless of where it is invoked from.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

# Application metadata & bundle directory layout paths
APP_NAME="MultiDock"
BUILD_DIR="${ROOT_DIR}/build"
APP_BUNDLE="${BUILD_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
VERSION_FILE="${ROOT_DIR}/VERSION"

# Resolve Semantic Version: Environment variable > VERSION file > fallback 1.0.0
APP_VERSION="${APP_VERSION:-}"
if [[ -z "${APP_VERSION}" && -f "${VERSION_FILE}" ]]; then
    APP_VERSION="$(tr -d '[:space:]' < "${VERSION_FILE}")"
fi
APP_VERSION="${APP_VERSION:-1.0.0}"

# Resolve Build Number: Environment variable > Git commit count > fallback 1
BUILD_NUMBER="${BUILD_NUMBER:-}"
if [[ -z "${BUILD_NUMBER}" ]]; then
    if git rev-parse --git-dir > /dev/null 2>&1; then
        GIT_COUNT="$(git rev-list --count HEAD 2>/dev/null || true)"
        if [[ -n "${GIT_COUNT}" && "${GIT_COUNT}" -gt 0 ]]; then
            BUILD_NUMBER="${GIT_COUNT}"
        fi
    fi
fi
BUILD_NUMBER="${BUILD_NUMBER:-1}"

# ------------------------------------------------------------------------------
# 2. Compile Binary with Swift Package Manager
# ------------------------------------------------------------------------------
echo "==> Building ${APP_NAME} v${APP_VERSION} (Build ${BUILD_NUMBER}) in release configuration..."
cd "${ROOT_DIR}"

# Build with optimizations enabled (-c release)
swift build -c release

# Dynamically locate the output binary using Swift PM's built-in query
BIN_PATH="$(swift build -c release --show-bin-path)/${APP_NAME}"

# Sanity check: Ensure the compiled binary actually exists before packaging
if [[ ! -f "${BIN_PATH}" ]]; then
    echo "Error: Release binary not found at '${BIN_PATH}'." >&2
    exit 1
fi

# ------------------------------------------------------------------------------
# 3. Assemble the macOS Application Bundle Structure
# ------------------------------------------------------------------------------
# A valid macOS .app bundle requires a standard hierarchy:
# MultiDock.app/
#   └── Contents/
#       ├── Info.plist      (App metadata, LSUIElement agent mode, permissions)
#       ├── MacOS/          (Mach-O executable)
#       └── Resources/      (Icons, assets, helper bundles)
echo "==> Assembling ${APP_NAME}.app bundle..."

# Clean up previous builds to prevent stale files or cached artifacts
rm -rf "${APP_BUNDLE}"

# Create the standard bundle directories
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

# Copy the compiled Mach-O binary and ensure executable permissions
cp "${BIN_PATH}" "${MACOS_DIR}/${APP_NAME}"
chmod +x "${MACOS_DIR}/${APP_NAME}"

# Copy Info.plist containing configuration (bundle ID, LSUIElement=true for dockless mode)
if [[ -f "${ROOT_DIR}/Info.plist" ]]; then
    cp "${ROOT_DIR}/Info.plist" "${CONTENTS_DIR}/Info.plist"
else
    echo "Warning: No Info.plist found at '${ROOT_DIR}/Info.plist'." >&2
fi

# Synchronize Semantic Version & Build Number into bundle's Info.plist
if [[ -f "${CONTENTS_DIR}/Info.plist" ]]; then
    plutil -replace CFBundleShortVersionString -string "${APP_VERSION}" "${CONTENTS_DIR}/Info.plist"
    plutil -replace CFBundleVersion -string "${BUILD_NUMBER}" "${CONTENTS_DIR}/Info.plist"
    echo "    Injected Version: ${APP_VERSION} (Build ${BUILD_NUMBER})"
fi

# ------------------------------------------------------------------------------
# 4. Code Signing & Hardened Runtime Security Hardening
# ------------------------------------------------------------------------------
# Signs the application bundle with macOS Hardened Runtime (--options runtime)
# and links the explicit entitlements file for Gatekeeper security compliance.
# - If DEVELOPER_ID or SIGNING_IDENTITY is set, signs with that certificate and secure Apple timestamp
# - Otherwise signs ad-hoc ("-") with Hardened Runtime enabled
ENTITLEMENTS_FILE="${ROOT_DIR}/MultiDock.entitlements"
SIGN_IDENTITY="${DEVELOPER_ID:-${SIGNING_IDENTITY:--}}"

CODESIGN_ARGS=(
    --force
    --deep
    --options runtime
)

if [[ -f "${ENTITLEMENTS_FILE}" ]]; then
    CODESIGN_ARGS+=(--entitlements "${ENTITLEMENTS_FILE}")
fi

if [[ "${SIGN_IDENTITY}" != "-" ]]; then
    echo "==> Signing with Developer ID: ${SIGN_IDENTITY} (Hardened Runtime + Timestamp)..."
    CODESIGN_ARGS+=(--timestamp --sign "${SIGN_IDENTITY}")
else
    echo "==> Signing application bundle (Hardened Runtime ad-hoc)..."
    CODESIGN_ARGS+=(--sign "-")
fi

codesign "${CODESIGN_ARGS[@]}" "${APP_BUNDLE}"

# ------------------------------------------------------------------------------
# 5. Done!
# ------------------------------------------------------------------------------
echo "==> Successfully created: ${APP_BUNDLE} (v${APP_VERSION})"
echo "    You can launch it with: open ${APP_BUNDLE}"
