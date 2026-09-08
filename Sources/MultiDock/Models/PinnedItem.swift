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

    /// Supported image extensions for custom icons to prevent executing or loading arbitrary files
    public static let allowedIconExtensions: Set<String> = ["png", "jpg", "jpeg", "icns", "tiff", "webp"]

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
        self.customName = customName.map { String($0.prefix(128)) }
        self.bundleIdentifier = bundleIdentifier ?? PinnedItem.resolveBundleIdentifier(for: url)
        self.isSeparator = isSeparator
        self.customIconPath = PinnedItem.isValidIconPath(customIconPath) ? customIconPath : nil
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
        let rawName = try container.decodeIfPresent(String.self, forKey: .customName)
        self.customName = rawName.map { String($0.prefix(128)) }
        self.bundleIdentifier = try container.decodeIfPresent(String.self, forKey: .bundleIdentifier)
        self.isSeparator = try container.decodeIfPresent(Bool.self, forKey: .isSeparator) ?? false
        let rawIconPath = try container.decodeIfPresent(String.self, forKey: .customIconPath)
        self.customIconPath = PinnedItem.isValidIconPath(rawIconPath) ? rawIconPath : nil
    }

    public var displayName: String {
        if let customName = customName, !customName.isEmpty {
            return customName
        }
        let filename = url.deletingPathExtension().lastPathComponent
        return filename.isEmpty ? url.lastPathComponent : filename
    }

    /// Validates that a custom icon file exists and has a supported image extension
    public static func isValidIconPath(_ path: String?) -> Bool {
        guard let path = path, !path.isEmpty else { return false }
        let ext = (path as NSString).pathExtension.lowercased()
        guard allowedIconExtensions.contains(ext) else { return false }
        return FileManager.default.fileExists(atPath: path)
    }

    /// Returns the icon to display — custom image if set and valid, otherwise system icon.
    public var icon: NSImage {
        // Try validated custom icon first
        if let customPath = customIconPath,
           PinnedItem.isValidIconPath(customPath),
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

    /// Security Verification: Checks if a target URL is safe to open.
    /// Blocks unsafe or dangerous URI schemes (e.g. javascript:, applescript:, data:)
    /// and ensures local file targets actually exist before invoking NSWorkspace.
    public var isSafeToLaunch: Bool {
        guard let scheme = url.scheme?.lowercased() else { return false }

        switch scheme {
        case "file":
            let path = url.path
            return !path.isEmpty && FileManager.default.fileExists(atPath: path)
        case "https", "http":
            guard let host = url.host, !host.isEmpty else { return false }
            return true
        default:
            return false
        }
    }

    public func launch() {
        guard !isSeparator else { return }

        guard isSafeToLaunch else {
            NSLog("[MultiDock] Blocked launch of invalid or non-existent target: \(url.absoluteString)")
            return
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open(url, configuration: configuration) { _, error in
            if let error = error {
                NSLog("[MultiDock] Failed to open \(url): \(error.localizedDescription)")
            }
        }
    }
}
