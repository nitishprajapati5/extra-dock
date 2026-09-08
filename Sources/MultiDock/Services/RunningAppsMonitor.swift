import AppKit
import Combine
import Foundation

@MainActor
public final class RunningAppsMonitor: ObservableObject {
    public static let shared = RunningAppsMonitor()

    @Published public private(set) var runningBundleIds: Set<String> = []
    @Published public private(set) var runningPaths: Set<String> = []

    private var cancellables = Set<AnyCancellable>()

    private init() {
        refresh()
        setupObservers()
    }

    public func refresh() {
        var bundleIds = Set<String>()
        var paths = Set<String>()

        for app in NSWorkspace.shared.runningApplications {
            if let bundleId = app.bundleIdentifier {
                bundleIds.insert(bundleId)
            }
            if let bundleUrl = app.bundleURL {
                paths.insert(bundleUrl.standardizedFileURL.path)
            }
        }

        self.runningBundleIds = bundleIds
        self.runningPaths = paths
    }

    private func setupObservers() {
        let center = NSWorkspace.shared.notificationCenter

        center.publisher(for: NSWorkspace.didLaunchApplicationNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)

        center.publisher(for: NSWorkspace.didTerminateApplicationNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)
    }

    public func isRunning(item: PinnedItem) -> Bool {
        if let bundleId = item.bundleIdentifier, runningBundleIds.contains(bundleId) {
            return true
        }
        let stdPath = item.url.standardizedFileURL.path
        if runningPaths.contains(stdPath) {
            return true
        }
        // Also check if app name matches
        let name = item.displayName
        for app in NSWorkspace.shared.runningApplications {
            if app.localizedName == name {
                return true
            }
        }
        return false
    }

    // Feature 7: Notification badge count via NSRunningApplication.badgeValue
    // Returns 0 when no badge, or the integer value shown on the Dock icon.
    public func badgeCount(for item: PinnedItem) -> Int {
        let runningApp: NSRunningApplication? = {
            if let bundleId = item.bundleIdentifier {
                return NSWorkspace.shared.runningApplications
                    .first(where: { $0.bundleIdentifier == bundleId })
            }
            return nil
        }()

        guard let app = runningApp else { return 0 }

        // NSRunningApplication doesn't expose badge values in public API.
        // We read it via the private `badgeValue` property if available.
        // This is the same technique used by third-party Dock replacements.
        if app.responds(to: NSSelectorFromString("badgeValue")) {
            let val = app.value(forKey: "badgeValue")
            if let intVal = val as? Int { return intVal }
            if let strVal = val as? String, let i = Int(strVal) { return i }
        }
        return 0
    }
}
