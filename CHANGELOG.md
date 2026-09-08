# Changelog

All notable changes to **MultiDock** will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Semantic Versioning automation suite (`scripts/version.sh`).
- Security hardening suite: macOS Hardened Runtime, `MultiDock.entitlements`, URL scheme sanitization, image extension verification, defensive JSON deserialization, POSIX 0600 file permissions, and Apple Notarization pipeline (`scripts/notarize.sh`).
- Security and vulnerability policy documentation (`SECURITY.md`).

---

## [1.0.0] - 2025-09-09

### Added
- Multiple independent floating docks on macOS.
- Per-dock display assignment and automatic hide/restore on screen connect/disconnect.
- Auto-hide mode with configurable edge detection and hover responsiveness.
- Application pool for choosing, adding, and dragging apps to docks.
- Appearance customization: 12 preset color themes, Liquid Glass blur, and custom backgrounds.
- Per-dock layout controls: horizontal/vertical orientation, icon size, item spacing, corner radius.
- Custom app icon selection and context menu actions.
- Menu bar status item controller for toggling docks and quick access to settings.
- Build and packaging scripts for standalone macOS `.app` bundle and Homebrew Cask distribution.
