# Security Policy

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| 1.0.x   | :white_check_mark: |

---

## Security Architecture & Local Privacy

MultiDock is designed with a **privacy-first and offline-first** security model:

1. **Zero Telemetry / Zero Tracking**: MultiDock does not collect, transmit, or monitor any personal data, app usage, or analytics.
2. **Local Storage**: All user settings and dock arrangements are stored locally in `~/Library/Application Support/MultiDock/docks.json` with POSIX `0600` permissions (restricted to the current macOS user).
3. **Hardened Runtime**: Released binaries are compiled with Apple Hardened Runtime (`--options runtime`), library validation, and explicit entitlements (`MultiDock.entitlements`).
4. **Input & Launch Sanitization**: Target application URLs are restricted to valid local file paths and standard web schemes (`https://`, `http://`). Potentially dangerous schemes (`javascript:`, `applescript:`, `data:`) are strictly blocked.
5. **Custom Icon Sandboxing**: Custom icon paths are validated against allowed image formats (`PNG`, `JPEG`, `ICNS`, `TIFF`, `WebP`) and verified on disk before loading.

---

## Reporting a Vulnerability

If you discover a security vulnerability in MultiDock, please report it responsibly:

1. **Email**: Send details of the issue to `security@multidock.app` (or open a private security advisory on GitHub).
2. **Information to Include**:
   - macOS version
   - MultiDock version
   - Detailed description and proof-of-concept steps to reproduce the issue
   - Any potential impact assessment

We will acknowledge receipt within 48 hours and work on a fix promptly. Please do not open public GitHub issues for undisclosed security vulnerabilities.
