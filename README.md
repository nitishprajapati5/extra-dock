# MultiDock 🚀

A lightweight, customizable multi-dock application for macOS built with SwiftUI and AppKit. Ships free and open source via Homebrew.

![macOS 13+](https://img.shields.io/badge/macOS-13.0%2B-blue)
![Swift 5.9+](https://img.shields.io/badge/Swift-5.9%2B-orange)
![License: MIT](https://img.shields.io/badge/License-MIT-green)

---

## ✨ Features

- **Multiple Floating Docks**: Create and customize $N$ independent docks across multiple monitors.
- **Drag & Drop Pinning**: Drag `.app` bundles, folders, and documents directly onto any dock to pin them.
- **Per-Dock Edge & Placement**: Position docks on any screen edge (Bottom, Top, Left, Right) or let them float anywhere on your desktop.
- **Launch on Click**: Click any pinned item to launch or switch to the application.
- **Active App Indicators**: Native macOS-style indicator dots under running applications, updated in real time.
- **Smooth Auto-Hide**: Optionally auto-hide the dock off-screen until your mouse hovers over the edge.
- **Aesthetic Customization**: Choose between Glassmorphic, Frosted Dark, Ultra-Thin Blur, or Transparent backgrounds with adjustable icon sizes and spacing.
- **Menu Bar Controller**: Agent app (`LSUIElement = true`) living in the macOS menu bar with hotkeys (`Cmd+Shift+D` to toggle, `Cmd+Shift+N` to add dock).

---

## 🏗️ Architecture

```
MultiDock/
├── Package.swift                             # Swift Package Manager manifest
├── Info.plist                                # LSUIElement=true agent configuration
├── scripts/
│   ├── build_app.sh                          # Compiles & bundles MultiDock.app
│   ├── make_cask.sh                          # Packages release zip & generates Homebrew Cask
│   └── version.sh                            # SemVer 2.0.0 bump and release manager
├── Sources/
│   └── MultiDock/
│       ├── App/
│       │   ├── MultiDockApp.swift            # SwiftUI App scene entry point
│       │   └── AppDelegate.swift             # Status item, NSMenu, settings window
│       ├── Models/
│       │   ├── DockConfig.swift              # Dock configuration (edge, orientation, sizing)
│       │   └── PinnedItem.swift              # Pinned item model (URL, icon, bundle ID)
│       ├── Services/
│       │   ├── DockManager.swift             # Observable source of truth & JSON persistence
│       │   └── RunningAppsMonitor.swift      # Tracks active apps via NSWorkspace notifications
│       ├── Windows/
│       │   ├── DockPanel.swift               # Borderless, non-activating floating NSPanel
│       │   └── DockWindowController.swift   # Screen geometry, edge anchoring & auto-hide
│       └── Views/
│           ├── DockView.swift                # SwiftUI dock layout, glassmorphic capsule, drop handler
│           ├── DockItemView.swift            # Icon renderer, hover magnification, running dot
│           └── SettingsView.swift            # Preferences UI (docks sidebar, appearance sliders)
└── Tests/
    └── MultiDockTests/
        └── DockManagerTests.swift            # Unit tests for serialization and dock operations
```

---

## 🛠️ Getting Started & Local Development

### Prerequisites
- macOS 13.0 (Ventura) or later
- Xcode 15+ or Swift 5.9+ toolchain installed

### Running Tests
```bash
swift test
```

### Running Locally from Terminal
```bash
swift run
```

### Building the Standalone `.app` Bundle
To build and package into `build/MultiDock.app`:
```bash
chmod +x scripts/*.sh
./scripts/build_app.sh
open build/MultiDock.app
```

---

## 🍺 Homebrew Cask Distribution

MultiDock is distributed as a precompiled Homebrew Cask:

1. Build release zip and generate Cask definition:
   ```bash
   ./scripts/make_cask.sh 1.0.0 <your-github-username>
   ```

2. Tag and publish the release on GitHub:
   - Create release `v1.0.0`
   - Upload `build/MultiDock-1.0.0.zip`

3. Install locally or via custom tap:
   ```bash
   brew tap <your-username>/homebrew-multidock
   brew install --cask multidock
   ```

---

## 🏷️ Semantic Versioning & Releases

MultiDock follows [Semantic Versioning (SemVer 2.0.0)](https://semver.org/):

| Command | Action |
|---|---|
| `./scripts/version.sh current` | View active version |
| `./scripts/version.sh next patch` | Preview next patch release (`1.0.0` → `1.0.1`) |
| `./scripts/version.sh next minor` | Preview next minor release (`1.0.0` → `1.1.0`) |
| `./scripts/version.sh next major` | Preview next major release (`1.0.0` → `2.0.0`) |
| `./scripts/version.sh bump patch` | Bumps version in `VERSION` and synchronizes `Info.plist` |
| `./scripts/version.sh release minor` | End-to-end release: bumps version, builds `.app`, packages zip, and generates Cask formula |

---

## 🔒 Security & Privacy

MultiDock is built with an **offline-first, zero-telemetry** architecture:
- **Zero Tracking**: No network telemetry, analytics, or background reporting.
- **Local User Isolation**: All dock settings are saved locally with POSIX `0600` permissions (restricted to the user account) and `NSFileProtectionComplete`.
- **Target Sanitization**: Pinned application targets are restricted to valid local files and standard web protocols. Potentially unsafe URI schemes (`javascript:`, `applescript:`, `data:`) are strictly blocked.
- **Hardened Runtime**: Released binaries include macOS Hardened Runtime (`--options runtime`) with library validation and restricted entitlements.
- For full details, see [SECURITY.md](SECURITY.md).

---

## 🚀 Public Release & Gatekeeper (Product Hunt & Homebrew)

When publishing to Product Hunt or distributing via Homebrew Cask:

1. **Local / Unnotarized Builds**:
   Users who download an unnotarized zip can clear the macOS quarantine flag by running:
   ```bash
   xattr -cr /Applications/MultiDock.app
   ```
   *(Or by right-clicking `MultiDock.app` and selecting **Open**).*

2. **Official Apple Notarization (Zero Gatekeeper Prompts)**:
   If you have an Apple Developer ID:
   ```bash
   # 1. Build with your Developer ID
   DEVELOPER_ID="Developer ID Application: Your Name (TEAM_ID)" ./scripts/build_app.sh

   # 2. Notarize and staple with Apple
   ./scripts/notarize.sh <keychain-profile-name>
   ```

---

## 📄 License
MIT License.
