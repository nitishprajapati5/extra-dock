import AppKit
import Combine
import Foundation

@MainActor
public final class DockManager: ObservableObject {
    public static let shared = DockManager()

    @Published public var docks: [DockConfig] = [] {
        didSet {
            saveToDisk()
            syncWindowControllers()
        }
    }

    @Published public var areDocksVisible: Bool = true {
        didSet {
            updateVisibility()
        }
    }

    private var windowControllers: [UUID: DockWindowController] = [:]
    private let storageUrl: URL

    public init(storageUrl: URL? = nil) {
        if let customUrl = storageUrl {
            self.storageUrl = customUrl
        } else {
            let appSupport = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
            let multiDir = appSupport.appendingPathComponent("MultiDock", isDirectory: true)
            try? FileManager.default.createDirectory(at: multiDir, withIntermediateDirectories: true)
            let multiStorage = multiDir.appendingPathComponent("docks.json")

            // Backward compatibility: Migrate existing docks configuration from OrbitDock if found
            let oldDir = appSupport.appendingPathComponent("OrbitDock", isDirectory: true)
            let oldStorage = oldDir.appendingPathComponent("docks.json")
            if !FileManager.default.fileExists(atPath: multiStorage.path) && FileManager.default.fileExists(atPath: oldStorage.path) {
                try? FileManager.default.copyItem(at: oldStorage, to: multiStorage)
            }

            self.storageUrl = multiStorage
        }

        loadFromDisk()
        syncWindowControllers()
        setupScreenChangeObserver()
    }

    private func setupScreenChangeObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screensDidChange),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc private nonisolated func screensDidChange() {
        Task { @MainActor in
            // Re-layout every window so docks snap to their assigned screen.
            // DockWindowController already observes this notification individually,
            // but we also need to update visibility state for docks whose target
            // screen has disappeared.
            self.syncWindowControllers()
        }
    }

    public func loadFromDisk() {
        do {
            if FileManager.default.fileExists(atPath: storageUrl.path) {
                let data = try Data(contentsOf: storageUrl)
                let loadedDocks = try JSONDecoder().decode([DockConfig].self, from: data)
                if !loadedDocks.isEmpty {
                    self.docks = loadedDocks
                    return
                }
            }
        } catch {
            NSLog("[MultiDock] Failed to load docks from \(storageUrl): \(error)")
        }

        // Fallback default docks based on connected screens
        var initialDocks = [DockConfig.defaultDock()]
        let screens = NSScreen.screens
        if screens.count > 1 {
            for i in 1..<screens.count {
                initialDocks.append(DockConfig.createDock(forScreen: i, dockNumber: 1))
            }
        }
        self.docks = initialDocks
    }

    public func saveToDisk() {
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(docks)
            try data.write(to: storageUrl, options: .atomic)
        } catch {
            NSLog("[MultiDock] Failed to save docks to \(storageUrl): \(error)")
        }
    }

    public func syncWindowControllers() {
        let activeIds = Set(docks.map { $0.id })

        // Remove obsolete window controllers
        for (id, controller) in windowControllers where !activeIds.contains(id) {
            controller.close()
            windowControllers.removeValue(forKey: id)
        }

        // Add or update controllers for active docks
        for dock in docks {
            if let controller = windowControllers[dock.id] {
                controller.relayout(animated: true)
            } else {
                let controller = DockWindowController(dockId: dock.id, dockManager: self)
                windowControllers[dock.id] = controller
            }
        }
    }

    public func addDock(forScreen screenIndex: Int? = nil) {
        let screens = NSScreen.screens
        let targetScreenIndex: Int
        if let idx = screenIndex {
            targetScreenIndex = idx
        } else {
            // Find first connected display that doesn't have a dock yet
            let coveredScreens = Set(docks.map { $0.screenIndex })
            if let uncovered = screens.indices.first(where: { !coveredScreens.contains($0) }) {
                targetScreenIndex = uncovered
            } else {
                targetScreenIndex = 0
            }
        }

        let existingCount = docks.filter { $0.screenIndex == targetScreenIndex }.count
        let newDock = DockConfig.createDock(forScreen: targetScreenIndex, dockNumber: existingCount + 1)
        docks.append(newDock)
    }

    public func addDocksForEveryScreen() {
        let screens = NSScreen.screens
        let coveredScreens = Set(docks.map { $0.screenIndex })
        for idx in screens.indices where !coveredScreens.contains(idx) {
            addDock(forScreen: idx)
        }
    }

    public func removeDock(id: UUID) {
        guard docks.count > 1 else {
            // Keep at least one dock
            return
        }
        docks.removeAll { $0.id == id }
    }

    public func updateDock(_ updated: DockConfig) {
        if let idx = docks.firstIndex(where: { $0.id == updated.id }) {
            docks[idx] = updated
        }
    }

    public func addItem(_ item: PinnedItem, to dockId: UUID) {
        guard let idx = docks.firstIndex(where: { $0.id == dockId }) else { return }
        // Avoid adding exact duplicate URL if already present
        if !docks[idx].items.contains(where: { $0.url == item.url }) {
            docks[idx].items.append(item)
        }
    }

    public func removeItem(itemId: UUID, from dockId: UUID) {
        guard let idx = docks.firstIndex(where: { $0.id == dockId }) else { return }
        docks[idx].items.removeAll { $0.id == itemId }
    }

    /// Set a custom icon path for a pinned item (per-app icon customization).
    public func setCustomIcon(itemId: UUID, in dockId: UUID, iconPath: String?) {
        guard let dockIdx = docks.firstIndex(where: { $0.id == dockId }),
              let itemIdx = docks[dockIdx].items.firstIndex(where: { $0.id == itemId }) else { return }
        docks[dockIdx].items[itemIdx].customIconPath = iconPath
    }

    /// Present an NSOpenPanel to pick an image file for a dock item's custom icon.
    @MainActor
    public func promptPickCustomIcon(itemId: UUID, in dockId: UUID) {
        let panel = NSOpenPanel()
        panel.title = "Choose Custom Icon"
        panel.message = "Select a PNG, JPEG, TIFF, or ICNS image to use as the dock icon."
        panel.allowedContentTypes = [.png, .jpeg, .tiff, .icns, .image]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            setCustomIcon(itemId: itemId, in: dockId, iconPath: url.path)
        }
    }

    // Feature 6: Item drag-to-reorder
    public func moveItem(in dockId: UUID, from source: IndexSet, to destination: Int) {
        guard let idx = docks.firstIndex(where: { $0.id == dockId }) else { return }
        docks[idx].items.move(fromOffsets: source, toOffset: destination)
    }

    // Feature 5: Insert a separator divider
    public func addSeparator(to dockId: UUID) {
        guard let idx = docks.firstIndex(where: { $0.id == dockId }) else { return }
        docks[idx].items.append(PinnedItem.separator())
    }

    public func toggleDockVisibility(id: UUID) {
        guard let idx = docks.firstIndex(where: { $0.id == id }) else { return }
        docks[idx].isVisible.toggle()
        applyVisibility(for: docks[idx])
    }

    public func setDockVisible(_ visible: Bool, id: UUID) {
        guard let idx = docks.firstIndex(where: { $0.id == id }) else { return }
        docks[idx].isVisible = visible
        applyVisibility(for: docks[idx])
    }

    private func applyVisibility(for config: DockConfig) {
        guard let controller = windowControllers[config.id] else { return }
        if config.isVisible {
            controller.panel.orderFront(nil)
            controller.relayout(animated: true)
        } else {
            controller.panel.orderOut(nil)
        }
    }

    /// Called when a floating-dock drag ends.
    /// `totalDX / totalDY` are the full gesture translation (not per-frame deltas).
    /// We read the panel's *current* frame (which reflects live OS drag movement)
    /// and simply save it — no arithmetic needed.
    public func applyFloatingDrag(dockId: UUID, totalDX: Double, totalDY: Double, startOrigin: CGPoint) {
        guard let idx = docks.firstIndex(where: { $0.id == dockId }),
              let controller = windowControllers[dockId] else { return }

        // The panel has already been visually moved by the window server.
        // Just persist whatever position it ended up at.
        let finalFrame = controller.panel.frame
        docks[idx].floatingX = Double(finalFrame.origin.x)
        docks[idx].floatingY = Double(finalFrame.origin.y)
    }

    // Legacy alias kept for source compatibility
    public func updateFloatingPosition(dockId: UUID, deltaX: Double, deltaY: Double) {
        applyFloatingDrag(dockId: dockId, totalDX: deltaX, totalDY: deltaY, startOrigin: .zero)
    }

    public func toggleAllDocks() {
        areDocksVisible.toggle()
    }

    private func updateVisibility() {
        for dock in docks {
            guard let controller = windowControllers[dock.id] else { continue }
            if areDocksVisible && dock.isVisible {
                controller.panel.orderFront(nil)
                controller.relayout(animated: true)
            } else {
                controller.panel.orderOut(nil)
            }
        }
    }
}
