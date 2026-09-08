import AppKit
import Foundation
import UniformTypeIdentifiers

public struct PinnedItem: Identifiable, Codable, Equatable, Hashable {
    public var id: UUID
    public var url: URL
    public var customName: String?
    public var bundleIdentifier: String?
    /// Section Dividers — renders as a thin rule, not an app icon.
    public var isSeparator: Bool
    /// Custom icon — absolute path to a user-supplied image file (PNG/JPEG/ICNS/TIFF).
    public var customIconPath: String?

    public init(
        id: UUID = UUID(),
        url: URL,
        customName: String? = nil,
        bundleIdentifier: String? = nil,
        isSeparator: Bool = false,
        customIconPath: String? = nil
    ) {
        self.id = id
        self.url = url
        self.customName = customName
        self.bundleIdentifier = bundleIdentifier ?? PinnedItem.resolveBundleIdentifier(for: url)
        self.isSeparator = isSeparator
        self.customIconPath = customIconPath
    }

    /// Creates a separator item that renders as a thin divider line.
    public static func separator() -> PinnedItem {
        PinnedItem(
            url: URL(fileURLWithPath: "/dev/null"),
            customName: "──────",
            isSeparator: true
        )
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.url = try container.decode(URL.self, forKey: .url)
        self.customName = try container.decodeIfPresent(String.self, forKey: .customName)
        self.bundleIdentifier = try container.decodeIfPresent(String.self, forKey: .bundleIdentifier)
        self.isSeparator = try container.decodeIfPresent(Bool.self, forKey: .isSeparator) ?? false
        self.customIconPath = try container.decodeIfPresent(String.self, forKey: .customIconPath)
    }

    public var displayName: String {
        if let customName = customName, !customName.isEmpty {
            return customName
        }
        let filename = url.deletingPathExtension().lastPathComponent
        return filename.isEmpty ? url.lastPathComponent : filename
    }

    /// Returns the icon to display — custom image if set, otherwise the system icon for the app/file.
    public var icon: NSImage {
        // Try custom icon first
        if let customPath = customIconPath,
           !customPath.isEmpty,
           let customImage = NSImage(contentsOfFile: customPath) {
            customImage.size = NSSize(width: 128, height: 128)
            return customImage
        }

        // Fall back to system icon
        let path = url.path
        if FileManager.default.fileExists(atPath: path) {
            let sysIcon = NSWorkspace.shared.icon(forFile: path)
            sysIcon.size = NSSize(width: 128, height: 128)
            return sysIcon
        }
        if let contentType = UTType(filenameExtension: url.pathExtension) {
            return NSWorkspace.shared.icon(for: contentType)
        }
        return NSWorkspace.shared.icon(forFile: path)
    }

    public static func resolveBundleIdentifier(for url: URL) -> String? {
        Bundle(url: url)?.bundleIdentifier
    }

    public func launch() {
        guard !isSeparator else { return }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open(url, configuration: configuration) { _, error in
            if let error = error {
                NSLog("[MultiDock] Failed to open \(url): \(error.localizedDescription)")
            }
        }
    }
}
