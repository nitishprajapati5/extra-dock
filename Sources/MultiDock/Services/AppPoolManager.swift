import AppKit
import Combine
import Foundation

@MainActor
public final class AppPoolManager: ObservableObject {
    public static let shared = AppPoolManager()

    @Published public private(set) var availableApps: [PinnedItem] = []
    @Published public private(set) var isLoading: Bool = false

    private init() {
        refreshPool()
    }

    public func refreshPool() {
        isLoading = true
        Task.detached(priority: .userInitiated) {
            let apps = Self.scanInstalledApplications()
            await MainActor.run {
                self.availableApps = apps
                self.isLoading = false
            }
        }
    }

    private nonisolated static func scanInstalledApplications() -> [PinnedItem] {
        let fileManager = FileManager.default
        var discoveredUrls: Set<URL> = []
        var items: [PinnedItem] = []

        var searchDirectories: [URL] = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications", isDirectory: true),
            URL(fileURLWithPath: "/System/Applications/Utilities", isDirectory: true)
        ]

        if let home = fileManager.urls(for: .userDirectory, in: .localDomainMask).first {
            let userApps = home.appendingPathComponent(NSUserName()).appendingPathComponent("Applications")
            searchDirectories.append(userApps)
        }

        for dir in searchDirectories {
            guard fileManager.fileExists(atPath: dir.path) else { continue }
            guard let enumerator = fileManager.enumerator(
                at: dir,
                includingPropertiesForKeys: [.isApplicationKey, .isPackageKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else { continue }

            for case let url as URL in enumerator {
                if url.pathExtension.lowercased() == "app" {
                    let stdUrl = url.standardizedFileURL
                    if !discoveredUrls.contains(stdUrl) {
                        discoveredUrls.insert(stdUrl)
                        items.append(PinnedItem(url: stdUrl))
                    }
                }
            }
        }

        // Sort alphabetically by display name
        return items.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    public func filteredApps(searchQuery: String) -> [PinnedItem] {
        let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return availableApps }
        return availableApps.filter {
            $0.displayName.localizedCaseInsensitiveContains(query)
        }
    }

    public func promptPickAppOrFile(completion: @escaping (PinnedItem?) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Add to Dock"
        panel.message = "Choose an application, script, or document to add to the dock"

        if panel.runModal() == .OK, let selectedUrl = panel.url {
            let item = PinnedItem(url: selectedUrl)
            completion(item)
        } else {
            completion(nil)
        }
    }
}
