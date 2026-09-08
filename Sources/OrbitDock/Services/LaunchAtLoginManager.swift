import Foundation
import ServiceManagement

/// Feature 8: Launch at Login — wraps SMAppService for macOS 13+
@MainActor
public final class LaunchAtLoginManager: ObservableObject {
    public static let shared = LaunchAtLoginManager()

    @Published public var isEnabled: Bool = false {
        didSet {
            guard oldValue != isEnabled else { return }
            apply()
        }
    }

    private init() {
        refresh()
    }

    /// Read current registration state from the OS.
    public func refresh() {
        if #available(macOS 13.0, *) {
            isEnabled = SMAppService.mainApp.status == .enabled
        } else {
            // For macOS < 13, fall back to UserDefaults flag only
            isEnabled = UserDefaults.standard.bool(forKey: "launchAtLogin")
        }
    }

    private func apply() {
        if #available(macOS 13.0, *) {
            do {
                if isEnabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                NSLog("[OrbitDock] LaunchAtLogin toggle failed: \(error.localizedDescription)")
                // Roll back the published value so the UI stays in sync
                isEnabled = !isEnabled
            }
        } else {
            // Legacy fallback — store intent, remind user
            UserDefaults.standard.set(isEnabled, forKey: "launchAtLogin")
        }
    }
}
