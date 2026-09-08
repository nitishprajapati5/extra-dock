#!/usr/bin/env bash
# ==============================================================================
# Script: version.sh
# Project: OrbitDock
#
# Description:
#   Comprehensive Semantic Versioning (SemVer 2.0.0) control manager for
#   OrbitDock. Handles reading, previewing, bumping (major, minor, patch),
#   synchronizing Info.plist, managing build numbers, and coordinating
#   full release builds.
#
# Usage:
#   ./scripts/version.sh current                  # Display current SemVer
#   ./scripts/version.sh next [patch|minor|major] # Preview next SemVer bump
#   ./scripts/version.sh bump [patch|minor|major|X.Y.Z] [--tag]
#   ./scripts/version.sh release [patch|minor|major|X.Y.Z]
#
# Examples:
#   ./scripts/version.sh next patch               # -> 1.0.1
#   ./scripts/version.sh bump minor               # -> Updates to 1.1.0 & syncs Info.plist
#   ./scripts/version.sh release patch            # -> Bumps, compiles, signs, & generates cask
# ==============================================================================

# Enable strict shell error handling:
#   -e: Exit immediately if a command exits with a non-zero status
#   -u: Treat unset variables as an error when substituting
#   -o pipefail: Pipeline return status is that of the last command to fail
set -euo pipefail

# ------------------------------------------------------------------------------
# 1. Path Configuration
# ------------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
VERSION_FILE="${ROOT_DIR}/VERSION"
PLIST_FILE="${ROOT_DIR}/Info.plist"

# Ensure root VERSION file exists; default to 1.0.0 if missing
if [[ ! -f "${VERSION_FILE}" ]]; then
    echo "1.0.0" > "${VERSION_FILE}"
fi

# ------------------------------------------------------------------------------
# 2. Version Parsing & Calculation Helpers
# ------------------------------------------------------------------------------

# Reads the raw version string from the VERSION file, trimming whitespace
get_current_version() {
    local ver
    ver="$(tr -d '[:space:]' < "${VERSION_FILE}")"
    echo "${ver}"
}

# Calculates a reproducible build number:
# - Uses git commit count if git is present and commits exist
# - Otherwise falls back to existing CFBundleVersion or 1
get_build_number() {
    local git_count
    if git rev-parse --git-dir > /dev/null 2>&1; then
        git_count="$(git rev-list --count HEAD 2>/dev/null || true)"
        if [[ -n "${git_count}" && "${git_count}" -gt 0 ]]; then
            echo "${git_count}"
            return 0
        fi
    fi

    # Fallback to Info.plist CFBundleVersion or 1
    if [[ -f "${PLIST_FILE}" ]]; then
        local plist_ver
        plist_ver="$(plutil -extract CFBundleVersion raw "${PLIST_FILE}" 2>/dev/null || true)"
        if [[ -n "${plist_ver}" ]]; then
            echo "${plist_ver}"
            return 0
        fi
    fi

    echo "1"
}

# Parses a SemVer string (MAJOR.MINOR.PATCH[-PRERELEASE]) into variables
# Arguments: <semver_string>
# Outputs variables: PARSED_MAJOR, PARSED_MINOR, PARSED_PATCH, PARSED_PRE
parse_semver() {
    local version="$1"
    local semver_regex='^([0-9]+)\.([0-9]+)\.([0-9]+)(-([0-9A-Za-z.-]+))?$'

    if [[ ! "${version}" =~ ${semver_regex} ]]; then
        echo "Error: '${version}' does not match Semantic Versioning format (e.g. 1.0.0 or 1.2.3-beta.1)." >&2
        return 1
    fi

    PARSED_MAJOR="${BASH_REMATCH[1]}"
    PARSED_MINOR="${BASH_REMATCH[2]}"
    PARSED_PATCH="${BASH_REMATCH[3]}"
    PARSED_PRE="${BASH_REMATCH[5]:-}"
}

# Computes the next semantic version based on bump type (patch, minor, major, or explicit)
# Arguments: <current_version> <bump_type_or_version>
compute_next_version() {
    local current="$1"
    local bump_type="$2"

    parse_semver "${current}"

    case "${bump_type}" in
        patch)
            echo "${PARSED_MAJOR}.${PARSED_MINOR}.$((PARSED_PATCH + 1))"
            ;;
        minor)
            echo "${PARSED_MAJOR}.$((PARSED_MINOR + 1)).0"
            ;;
        major)
            echo "$((PARSED_MAJOR + 1)).0.0"
            ;;
        *)
            # Check if user provided an explicit version number (e.g. 2.1.0)
            if parse_semver "${bump_type}" > /dev/null 2>&1; then
                echo "${bump_type}"
            else
                echo "Error: Invalid bump type or version: '${bump_type}'." >&2
                echo "Expected: 'patch', 'minor', 'major', or a valid SemVer string (e.g. 1.2.0)." >&2
                return 1
            fi
            ;;
    esac
}

# Synchronizes CFBundleShortVersionString and CFBundleVersion in Info.plist
# Arguments: <version> [build_number]
sync_plist() {
    local new_version="$1"
    local build_number="${2:-$(get_build_number)}"

    if [[ -f "${PLIST_FILE}" ]]; then
        echo "==> Updating Info.plist (Version: ${new_version}, Build: ${build_number})..."
        plutil -replace CFBundleShortVersionString -string "${new_version}" "${PLIST_FILE}"
        plutil -replace CFBundleVersion -string "${build_number}" "${PLIST_FILE}"
    fi
}

# ------------------------------------------------------------------------------
# 3. Command Implementations
# ------------------------------------------------------------------------------

# Command: current
# Output the current active version string
cmd_current() {
    get_current_version
}

# Command: next <patch|minor|major>
# Preview the next version without applying changes
cmd_next() {
    local bump_type="${1:-patch}"
    local current
    current="$(get_current_version)"
    compute_next_version "${current}" "${bump_type}"
}

# Command: bump <patch|minor|major|X.Y.Z> [--tag]
# Updates VERSION file and Info.plist, optionally creating a git tag
cmd_bump() {
    local bump_type="${1:-patch}"
    local create_tag=false

    # Check for optional --tag flag
    for arg in "$@"; do
        if [[ "${arg}" == "--tag" ]]; then
            create_tag=true
        fi
    done

    local current
    current="$(get_current_version)"
    local next
    next="$(compute_next_version "${current}" "${bump_type}")"
    local build
    build="$(get_build_number)"

    echo "==> Bumping version: ${current} -> ${next} (Build ${build})"

    # 1. Update VERSION file
    echo "${next}" > "${VERSION_FILE}"

    # 2. Synchronize Info.plist
    sync_plist "${next}" "${build}"

    # 3. Handle Git tagging if requested and git is available
    if [[ "${create_tag}" == "true" ]]; then
        if git rev-parse --git-dir > /dev/null 2>&1; then
            echo "==> Creating Git tag v${next}..."
            git add "${VERSION_FILE}" "${PLIST_FILE}"
            git commit -m "chore(release): bump version to v${next}" || true
            git tag -a "v${next}" -m "Release v${next}"
            echo "    Tagged: v${next}"
        else
            echo "Warning: Not a Git repository; skipping Git tag." >&2
        fi
    fi

    echo "==> Version updated successfully to ${next}."
}

# Command: release <patch|minor|major|X.Y.Z>
# End-to-end automated release pipeline:
# 1. Bump version and sync Info.plist
# 2. Build release .app bundle
# 3. Create release archive and Homebrew Cask
cmd_release() {
    local bump_type="${1:-patch}"

    echo "============================================================"
    echo "  OrbitDock Semantic Release Pipeline"
    echo "============================================================"

    # Step 1: Bump version
    cmd_bump "${bump_type}"

    local release_ver
    release_ver="$(get_current_version)"

    # Step 2: Build and codesign application bundle
    echo ""
    echo "==> Executing release build..."
    "${SCRIPT_DIR}/build_app.sh"

    # Step 3: Package release archive and generate Homebrew Cask
    echo ""
    echo "==> Generating release package and Homebrew Cask formula..."
    "${SCRIPT_DIR}/make_cask.sh" "${release_ver}"

    echo ""
    echo "============================================================"
    echo "  Release v${release_ver} ready!"
    echo "============================================================"
    echo "Artifacts generated in '${ROOT_DIR}/build':"
    echo "  - OrbitDock.app (signed application)"
    echo "  - OrbitDock-${release_ver}.zip (release asset)"
    echo "  - orbitdock.rb (Homebrew Cask formula)"
    echo "============================================================"
}

# ------------------------------------------------------------------------------
# 4. CLI Routing & Help Display
# ------------------------------------------------------------------------------
show_help() {
    cat <<EOF
OrbitDock Semantic Versioning Control Tool

Usage:
  ./scripts/version.sh <command> [options]

Commands:
  current                         Display current version
  next [patch|minor|major]        Preview next semantic version
  bump [patch|minor|major|X.Y.Z]  Update VERSION file and Info.plist
    --tag                         Also commit changes and create git tag 'vX.Y.Z'
  release [patch|minor|major]     Full release: bump, build .app, zip, and generate cask
  sync                            Sync Info.plist with current VERSION file
  help                            Show this help message

Examples:
  ./scripts/version.sh current
  ./scripts/version.sh next minor
  ./scripts/version.sh bump patch
  ./scripts/version.sh bump 1.2.0 --tag
  ./scripts/version.sh release patch
EOF
}

COMMAND="${1:-help}"

case "${COMMAND}" in
    current)
        cmd_current
        ;;
    next)
        cmd_next "${2:-patch}"
        ;;
    bump)
        shift
        cmd_bump "$@"
        ;;
    sync)
        sync_plist "$(get_current_version)" "$(get_build_number)"
        ;;
    release)
        shift
        cmd_release "$@"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo "Error: Unknown command '${COMMAND}'" >&2
        show_help
        exit 1
        ;;
esac
