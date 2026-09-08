# OrbitDock 🚀

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
OrbitDock/
├── Package.swift                             # Swift Package Manager manifest
├── Info.plist                                # LSUIElement=true agent configuration
├── scripts/
│   ├── build_app.sh                          # Compiles & bundles OrbitDock.app
│   └── make_cask.sh                          # Packages release zip & generates Homebrew Cask
├── Sources/
│   └── OrbitDock/
│       ├── App/
│       │   ├── OrbitDockApp.swift            # SwiftUI App scene entry point
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
    └── OrbitDockTests/
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
To build and package into `build/OrbitDock.app`:
```bash
chmod +x scripts/*.sh
./scripts/build_app.sh
open build/OrbitDock.app
```

---

## 🍺 Homebrew Cask Distribution

OrbitDock is distributed as a precompiled Homebrew Cask:

1. Build release zip and generate Cask definition:
   ```bash
   ./scripts/make_cask.sh 1.0.0 <your-github-username>
   ```

2. Tag and publish the release on GitHub:
   - Create release `v1.0.0`
   - Upload `build/OrbitDock-1.0.0.zip`

3. Install locally or via custom tap:
   ```bash
   brew tap <your-username>/homebrew-orbitdock
   brew install --cask orbitdock
   ```

---

## 🏷️ Semantic Versioning & Releases

OrbitDock follows [Semantic Versioning (SemVer 2.0.0)](https://semver.org/):

| Command | Action |
|---|---|
| `./scripts/version.sh current` | View active version |
| `./scripts/version.sh next patch` | Preview next patch release (`1.0.0` → `1.0.1`) |
| `./scripts/version.sh next minor` | Preview next minor release (`1.0.0` → `1.1.0`) |
| `./scripts/version.sh next major` | Preview next major release (`1.0.0` → `2.0.0`) |
| `./scripts/version.sh bump patch` | Bumps version in `VERSION` and synchronizes `Info.plist` |
| `./scripts/version.sh release minor` | End-to-end release: bumps version, builds `.app`, packages zip, and generates Cask formula |

---

## 📄 License
MIT License.
