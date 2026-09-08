import AppKit
import SwiftUI

@MainActor
public final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var statusItem: NSStatusItem?
    private var settingsWindow: NSWindow?
    private let dockManager = DockManager.shared

    public func applicationDidFinishLaunching(_ notification: Notification) {
        // Configure as accessory agent app without standard Dock icon
        NSApp.setActivationPolicy(.accessory)

        setupStatusItem()

        // Ensure docks are visible and initialized
        dockManager.syncWindowControllers()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
            let image = NSImage(systemSymbolName: "dock.rectangle", accessibilityDescription: "MultiDock")?
                .withSymbolConfiguration(config)
            button.image = image
            button.toolTip = "MultiDock - Floating macOS Docks"
        }

        rebuildMenu()
    }

    public func rebuildMenu() {
        let menu = NSMenu()

        // Title header
        let titleItem = NSMenuItem(title: "MultiDock", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)

        menu.addItem(NSMenuItem.separator())

        // Toggle visibility
        let toggleTitle = dockManager.areDocksVisible ? "Hide All Docks" : "Show All Docks"
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleDocks), keyEquivalent: "d")
        toggleItem.keyEquivalentModifierMask = [.command, .shift]
        toggleItem.target = self
        menu.addItem(toggleItem)

        // Add new dock with per-screen submenu if multiple displays connected
        let screens = NSScreen.screens
        if screens.count > 1 {
            let addMenu = NSMenu()
            for idx in screens.indices {
                let screenTitle = idx == 0 ? "Add for Screen 1 (Primary)" : "Add for Screen \(idx + 1) (Secondary)"
                let item = NSMenuItem(title: screenTitle, action: #selector(addDockForScreen(_:)), keyEquivalent: "")
                item.tag = idx
                item.target = self
                addMenu.addItem(item)
            }
            addMenu.addItem(NSMenuItem.separator())
            let addAllItem = NSMenuItem(title: "Add Docks for All Screens", action: #selector(addAllScreensDocks), keyEquivalent: "")
            addAllItem.target = self
            addMenu.addItem(addAllItem)

            let addParentItem = NSMenuItem(title: "Add New Dock", action: nil, keyEquivalent: "n")
            addParentItem.keyEquivalentModifierMask = [.command, .shift]
            addParentItem.submenu = addMenu
            menu.addItem(addParentItem)
        } else {
            let addItem = NSMenuItem(title: "Add New Dock", action: #selector(addNewDock), keyEquivalent: "n")
            addItem.keyEquivalentModifierMask = [.command, .shift]
            addItem.target = self
            menu.addItem(addItem)
        }

        menu.addItem(NSMenuItem.separator())

        // Submenu listing active docks with per-dock show/hide toggles
        let docksMenu = NSMenu()

        // Group docks by screen
        let screenCount = max(NSScreen.screens.count, dockManager.docks.map { $0.screenIndex + 1 }.max() ?? 1)
        for screenIdx in 0..<screenCount {
            let screenDocks = dockManager.docks.filter { $0.screenIndex == screenIdx }
            guard !screenDocks.isEmpty else { continue }

            let screenLabel = screenIdx == 0
                ? "── Screen 1 (Primary) ──"
                : "── Screen \(screenIdx + 1) (Secondary) ──"
            let headerItem = NSMenuItem(title: screenLabel, action: nil, keyEquivalent: "")
            headerItem.isEnabled = false
            docksMenu.addItem(headerItem)

            for dock in screenDocks {
                let edgeLabel = dock.edge.rawValue.capitalized
                let orientLabel = dock.orientation.rawValue.capitalized
                let visLabel = dock.isVisible ? "Visible" : "Hidden"
                let separator = " · "
                let dockSubItem = NSMenuItem(
                    title: "  \(dock.name)  [\(edgeLabel)\(separator)\(orientLabel)] — \(visLabel)",
                    action: #selector(toggleDockVisibility(_:)),
                    keyEquivalent: ""
                )
                dockSubItem.target = self
                dockSubItem.representedObject = dock.id
                dockSubItem.state = dock.isVisible ? NSControl.StateValue.on : NSControl.StateValue.off
                docksMenu.addItem(dockSubItem)
            }

            if screenIdx < screenCount - 1 {
                docksMenu.addItem(NSMenuItem.separator())
            }
        }

        let docksParentItem = NSMenuItem(title: "Docks (\(dockManager.docks.count))", action: nil, keyEquivalent: "")
        docksParentItem.submenu = docksMenu
        menu.addItem(docksParentItem)

        menu.addItem(NSMenuItem.separator())

        // App Pool & Settings
        let poolItem = NSMenuItem(title: "Applications Pool...", action: #selector(openSettings), keyEquivalent: "p")
        poolItem.keyEquivalentModifierMask = [.command, .shift]
        poolItem.target = self
        menu.addItem(poolItem)

        let settingsItem = NSMenuItem(title: "Preferences...", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit MultiDock", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc private func toggleDocks() {
        dockManager.toggleAllDocks()
        rebuildMenu()
    }

    @objc private func toggleDockVisibility(_ sender: NSMenuItem) {
        guard let dockId = sender.representedObject as? UUID else { return }
        dockManager.toggleDockVisibility(id: dockId)
        rebuildMenu()
    }

    @objc private func addNewDock() {
        dockManager.addDock()
        rebuildMenu()
        openSettings()
    }

    @objc private func addDockForScreen(_ sender: NSMenuItem) {
        dockManager.addDock(forScreen: sender.tag)
        rebuildMenu()
        openSettings()
    }

    @objc private func addAllScreensDocks() {
        dockManager.addDocksForEveryScreen()
        rebuildMenu()
        openSettings()
    }

    @objc public func openSettings() {
        // Enforce strictly single-instance settings window
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "MultiDock Preferences"
        window.minSize = NSSize(width: 840, height: 560)
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = NSHostingView(rootView: SettingsView(dockManager: dockManager))

        self.settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func windowWillClose(_ notification: Notification) {
        if let closingWindow = notification.object as? NSWindow, closingWindow == settingsWindow {
            // Keep reference ready or reset if needed
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
