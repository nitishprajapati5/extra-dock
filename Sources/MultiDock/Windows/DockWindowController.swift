import AppKit
import Combine
import SwiftUI

// MARK: - DockWindowController
//
// Responsibilities
// ─────────────────
// • Creates and owns the NSPanel for one DockConfig.
// • Positions the panel on the correct screen, edge, and orientation.
// • Implements auto-hide: slide off-edge on mouse-away, slide back on hover.
// • Handles display connect / disconnect:
//     – When the assigned screen disappears  → orderOut + set isHiddenByMissingScreen.
//     – When the screen comes back           → re-position and orderFront (respecting
//       the user's explicit isVisible flag).
// • Floating docks can be dragged; position is saved back to DockConfig.

@MainActor
public final class DockWindowController: NSObject {
    public let dockId: UUID
    public let panel: DockPanel
    private weak var dockManager: DockManager?
    private var cancellables = Set<AnyCancellable>()

    // Auto-hide state
    private var isHiddenByAutoHide = false

    // Missing-screen state — separate from auto-hide so we can restore correctly
    private var isHiddenByMissingScreen = false

    // The "visible" frame we always snap back to after auto-hide
    private var unhiddenFrame: NSRect = .zero

    private var globalMouseMonitor: Any?

    // MARK: - Init

    public init(dockId: UUID, dockManager: DockManager) {
        self.dockId = dockId
        self.dockManager = dockManager
        self.panel = DockPanel(contentRect: NSRect(x: 0, y: 0, width: 260, height: 80))

        super.init()

        setupContentView()
        setupAutoHideMonitor()
        setupScreenChangeObserver()

        // Apply collection behavior so the dock stays on its assigned screen
        // across all Spaces and ignores Mission Control cycling.
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]

        let config = dockManager.docks.first(where: { $0.id == dockId })
        relayout()

        if config?.isVisible == false {
            panel.orderOut(nil)
        } else {
            panel.orderFront(nil)
            if config?.autoHide == true {
                checkMousePositionForAutoHide(animated: false)
            }
        }
    }

    deinit {
        if let monitor = globalMouseMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    // MARK: - Setup

    private func setupContentView() {
        guard let dockManager = dockManager else { return }
        let dockView = DockView(dockId: dockId, dockManager: dockManager)
        let hostingView = NSHostingView(rootView: dockView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView = hostingView
    }

    private func setupScreenChangeObserver() {
        NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.handleScreenChange() }
            .store(in: &cancellables)
    }

    private func setupAutoHideMonitor() {
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            Task { @MainActor in
                self?.checkMousePositionForAutoHide(animated: true)
            }
        }
    }

    // MARK: - Screen Helpers

    /// Returns the NSScreen this dock is assigned to, or nil if it's disconnected.
    private func getTargetScreen(for config: DockConfig) -> NSScreen? {
        let screens = NSScreen.screens
        guard screens.indices.contains(config.screenIndex) else { return nil }
        return screens[config.screenIndex]
    }

    // MARK: - Screen Connect / Disconnect

    private func handleScreenChange() {
        guard let config = dockManager?.docks.first(where: { $0.id == dockId }) else { return }

        if getTargetScreen(for: config) == nil {
            // ── Screen just disappeared ───────────────────────────────────────
            if !isHiddenByMissingScreen {
                isHiddenByMissingScreen = true
                NSLog("[MultiDock] Screen \(config.screenIndex) disconnected — hiding dock '\(config.name)'")
                panel.orderOut(nil)
            }
        } else {
            // ── Screen is present (may have just reconnected) ─────────────────
            if isHiddenByMissingScreen {
                isHiddenByMissingScreen = false
                NSLog("[MultiDock] Screen \(config.screenIndex) reconnected — restoring dock '\(config.name)'")
            }

            // Always re-layout to snap back to the (possibly changed) screen geometry
            relayout(animated: true)

            // Re-show if the user hasn't explicitly hidden this dock
            if config.isVisible && !isHiddenByAutoHide {
                panel.orderFront(nil)
            }
        }
    }

    // MARK: - Auto-hide

    private func checkMousePositionForAutoHide(animated: Bool = true) {
        guard let config = dockManager?.docks.first(where: { $0.id == dockId }) else { return }

        // Don't interfere with explicitly-hidden or missing-screen panels
        guard config.isVisible, !isHiddenByMissingScreen else { return }

        guard config.autoHide else {
            if isHiddenByAutoHide { showDock(animated: animated) }
            return
        }

        guard let targetScreen = getTargetScreen(for: config) else {
            if !isHiddenByAutoHide { hideDock(animated: false) }
            return
        }

        let mouseLocation = NSEvent.mouseLocation
        let screenFrame = targetScreen.visibleFrame

        // Guard: mouse must be on the assigned screen before we even check edges.
        // This prevents a bottom-edge dock on Screen 1 from triggering when the
        // user hovers the bottom of Screen 2.
        let fullScreenFrame = targetScreen.frame
        guard fullScreenFrame.contains(mouseLocation) else {
            if !isHiddenByAutoHide { hideDock(animated: animated) }
            return
        }

        // Edge proximity trigger (generous 24-pt lateral tolerance)
        let triggerDistance: CGFloat = 16.0
        let tolerance: CGFloat = 24.0
        let isNearDockEdge: Bool

        switch config.edge {
        case .bottom:
            isNearDockEdge = mouseLocation.y <= screenFrame.minY + triggerDistance
                          && mouseLocation.x >= unhiddenFrame.minX - tolerance
                          && mouseLocation.x <= unhiddenFrame.maxX + tolerance
        case .top:
            isNearDockEdge = mouseLocation.y >= screenFrame.maxY - triggerDistance
                          && mouseLocation.x >= unhiddenFrame.minX - tolerance
                          && mouseLocation.x <= unhiddenFrame.maxX + tolerance
        case .left:
            isNearDockEdge = mouseLocation.x <= screenFrame.minX + triggerDistance
                          && mouseLocation.y >= unhiddenFrame.minY - tolerance
                          && mouseLocation.y <= unhiddenFrame.maxY + tolerance
        case .right:
            isNearDockEdge = mouseLocation.x >= screenFrame.maxX - triggerDistance
                          && mouseLocation.y >= unhiddenFrame.minY - tolerance
                          && mouseLocation.y <= unhiddenFrame.maxY + tolerance
        case .floating:
            isNearDockEdge = false
        }

        let detectionFrame = panel.frame.insetBy(dx: -16, dy: -16)

        if detectionFrame.contains(mouseLocation) || isNearDockEdge {
            if isHiddenByAutoHide { showDock(animated: animated) }
        } else {
            if !isHiddenByAutoHide { hideDock(animated: animated) }
        }
    }

    private func hideDock(animated: Bool) {
        guard !isHiddenByAutoHide else { return }
        isHiddenByAutoHide = true

        guard let config = dockManager?.docks.first(where: { $0.id == dockId }) else { return }

        var targetFrame = unhiddenFrame
        let hideDistance: CGFloat = 4.0 // leave a tiny sliver so mouse tracking still works

        switch config.edge {
        case .bottom:
            targetFrame.origin.y -= (unhiddenFrame.height - hideDistance)
        case .top:
            targetFrame.origin.y += (unhiddenFrame.height - hideDistance)
        case .left:
            targetFrame.origin.x -= (unhiddenFrame.width - hideDistance)
        case .right:
            targetFrame.origin.x += (unhiddenFrame.width - hideDistance)
        case .floating:
            if animated {
                panel.animator().alphaValue = 0.0
            } else {
                panel.alphaValue = 0.0
            }
            return
        }

        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.22
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(targetFrame, display: true)
                panel.animator().alphaValue = 0.0
            }
        } else {
            panel.setFrame(targetFrame, display: true)
            panel.alphaValue = 0.0
        }
    }

    private func showDock(animated: Bool) {
        guard isHiddenByAutoHide else { return }
        isHiddenByAutoHide = false

        if animated {
            NSAnimationContext.runAnimationGroup { ctx in
                ctx.duration = 0.2
                ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                panel.animator().setFrame(unhiddenFrame, display: true)
                panel.animator().alphaValue = 1.0
            }
        } else {
            panel.setFrame(unhiddenFrame, display: true)
            panel.alphaValue = 1.0
        }
    }

    // MARK: - Layout

    public func relayout(animated: Bool = false) {
        guard let config = dockManager?.docks.first(where: { $0.id == dockId }),
              let contentView = panel.contentView else { return }

        // If target screen is missing, handle via handleScreenChange instead
        guard let targetScreen = getTargetScreen(for: config) else {
            if !isHiddenByMissingScreen {
                isHiddenByMissingScreen = true
                panel.orderOut(nil)
            }
            return
        }

        let screenFrame = targetScreen.visibleFrame
        let fittingSize = contentView.fittingSize
        let safeSize = NSSize(
            width: max(fittingSize.width, 70),
            height: max(fittingSize.height, 50)
        )

        let margin: CGFloat = 8.0
        var newOrigin = NSPoint.zero

        switch config.edge {
        case .bottom:
            newOrigin.x = screenFrame.midX - (safeSize.width / 2.0)
            newOrigin.y = screenFrame.minY + margin
        case .top:
            newOrigin.x = screenFrame.midX - (safeSize.width / 2.0)
            newOrigin.y = screenFrame.maxY - safeSize.height - margin
        case .left:
            newOrigin.x = screenFrame.minX + margin
            newOrigin.y = screenFrame.midY - (safeSize.height / 2.0)
        case .right:
            newOrigin.x = screenFrame.maxX - safeSize.width - margin
            newOrigin.y = screenFrame.midY - (safeSize.height / 2.0)
        case .floating:
            if let savedX = config.floatingX, let savedY = config.floatingY {
                // Clamp saved position within the assigned screen so it doesn't
                // drift off after a display layout change.
                let clampedX = min(max(savedX, screenFrame.minX), screenFrame.maxX - safeSize.width)
                let clampedY = min(max(savedY, screenFrame.minY), screenFrame.maxY - safeSize.height)
                newOrigin = NSPoint(x: clampedX, y: clampedY)
            } else {
                newOrigin.x = screenFrame.midX - (safeSize.width / 2.0)
                newOrigin.y = screenFrame.midY - (safeSize.height / 2.0)
            }
        }

        let newFrame = NSRect(origin: newOrigin, size: safeSize)
        self.unhiddenFrame = newFrame

        // Apply the frame, respecting auto-hide and missing-screen state
        if isHiddenByAutoHide {
            // Re-run hide to update the slid-off position with new geometry
            isHiddenByAutoHide = false   // reset so hideDock() doesn't guard-return
            hideDock(animated: animated)
        } else {
            if animated {
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.2
                    ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                    panel.animator().setFrame(newFrame, display: true)
                    panel.animator().alphaValue = 1.0
                }
            } else {
                panel.setFrame(newFrame, display: true)
                panel.alphaValue = 1.0
            }
        }
    }

    // MARK: - Close

    public func close() {
        panel.orderOut(nil)
        panel.close()
    }
}
