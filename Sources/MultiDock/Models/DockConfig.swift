import AppKit
import CoreGraphics
import Foundation
import SwiftUI

public enum DockOrientation: String, Codable, CaseIterable {
    case horizontal
    case vertical
}

public enum DockEdge: String, Codable, CaseIterable {
    case bottom
    case top
    case left
    case right
    case floating
}

public enum BackgroundStyle: String, Codable, CaseIterable {
    case glass        // Glassmorphism (ultraThin + black overlay)
    case dark         // Dark Frosted
    case ultraThin    // Ultra Thin Blur only
    case clear        // Almost transparent
    case liquidGlass  // Liquid Glass — iridescent animated sheen (macOS 26 style)

    public var displayName: String {
        switch self {
        case .glass: return "Glassmorphism"
        case .dark: return "Dark Frosted"
        case .ultraThin: return "Ultra Thin"
        case .clear: return "Transparent"
        case .liquidGlass: return "Liquid Glass"
        }
    }
}

// MARK: - Color Theme Presets

public struct ColorTheme: Identifiable {
    public let id: String
    public let name: String
    public let icon: String            // SF Symbol
    public let backgroundStyle: BackgroundStyle
    public let useCustomColor: Bool
    public let colorHex: String
    public let colorOpacity: Double
    public let cornerRadius: Double

    public static let presets: [ColorTheme] = [
        ColorTheme(id: "classic",    name: "Classic macOS",  icon: "apple.logo",          backgroundStyle: .glass,      useCustomColor: false, colorHex: "#1E1E2E", colorOpacity: 0.00, cornerRadius: 22),
        ColorTheme(id: "liquidglass",name: "Liquid Glass",   icon: "drop.fill",           backgroundStyle: .liquidGlass,useCustomColor: false, colorHex: "#FFFFFF", colorOpacity: 0.08, cornerRadius: 24),
        ColorTheme(id: "darkmode",   name: "Dark Matter",    icon: "moon.stars.fill",     backgroundStyle: .dark,       useCustomColor: false, colorHex: "#000000", colorOpacity: 0.55, cornerRadius: 18),
        ColorTheme(id: "ultra",      name: "Ultra Minimal",  icon: "circle.dashed",       backgroundStyle: .ultraThin,  useCustomColor: false, colorHex: "#FFFFFF", colorOpacity: 0.04, cornerRadius: 14),
        ColorTheme(id: "neonpurple", name: "Neon Purple",    icon: "wand.and.stars",      backgroundStyle: .glass,      useCustomColor: true,  colorHex: "#7C3AED", colorOpacity: 0.55, cornerRadius: 22),
        ColorTheme(id: "neonpink",   name: "Neon Pink",      icon: "heart.fill",          backgroundStyle: .glass,      useCustomColor: true,  colorHex: "#EC4899", colorOpacity: 0.50, cornerRadius: 22),
        ColorTheme(id: "ocean",      name: "Ocean Blue",     icon: "wave.3.right",        backgroundStyle: .glass,      useCustomColor: true,  colorHex: "#0EA5E9", colorOpacity: 0.45, cornerRadius: 22),
        ColorTheme(id: "sunset",     name: "Sunset Gold",    icon: "sun.horizon.fill",    backgroundStyle: .glass,      useCustomColor: true,  colorHex: "#F59E0B", colorOpacity: 0.45, cornerRadius: 20),
        ColorTheme(id: "cherry",     name: "Cherry Red",     icon: "flame.fill",          backgroundStyle: .glass,      useCustomColor: true,  colorHex: "#EF4444", colorOpacity: 0.50, cornerRadius: 22),
        ColorTheme(id: "neongreen",  name: "Neon Green",     icon: "sparkles",            backgroundStyle: .glass,      useCustomColor: true,  colorHex: "#22C55E", colorOpacity: 0.45, cornerRadius: 22),
        ColorTheme(id: "arctic",     name: "Arctic White",   icon: "snowflake",           backgroundStyle: .ultraThin,  useCustomColor: true,  colorHex: "#FFFFFF", colorOpacity: 0.18, cornerRadius: 26),
        ColorTheme(id: "midnight",   name: "Midnight Black", icon: "circle.fill",         backgroundStyle: .clear,      useCustomColor: true,  colorHex: "#000000", colorOpacity: 0.72, cornerRadius: 16),
    ]
}


public struct DockConfig: Identifiable, Codable, Equatable {
    public var id: UUID
    public var name: String
    public var orientation: DockOrientation
    public var edge: DockEdge
    public var screenIndex: Int
    public var iconSize: Double
    public var spacing: Double
    public var autoHide: Bool
    public var backgroundStyle: BackgroundStyle
    public var useCustomColor: Bool
    public var customColorHex: String
    public var customColorOpacity: Double
    public var floatingX: Double?
    public var floatingY: Double?
    public var items: [PinnedItem]

    // ── Feature 1: Icon Labels ──────────────────────────────
    public var showLabels: Bool

    // ── Feature 2: Hover Magnification ─────────────────────
    public var magnificationEnabled: Bool
    public var magnificationScale: Double

    // ── Feature 3: Corner Radius ────────────────────────────
    public var cornerRadius: Double

    // ── Feature 4: Dock Padding ─────────────────────────────
    public var paddingH: Double
    public var paddingV: Double

    // ── Per-dock visibility ────────────────────────────────
    /// When false the dock window is hidden (ordered out) regardless of autoHide.
    public var isVisible: Bool

    public init(
        id: UUID = UUID(),
        name: String = "Main Dock",
        orientation: DockOrientation = .horizontal,
        edge: DockEdge = .bottom,
        screenIndex: Int = 0,
        iconSize: Double = 64.0,
        spacing: Double = 12.0,
        autoHide: Bool = true,
        backgroundStyle: BackgroundStyle = .glass,
        useCustomColor: Bool = false,
        customColorHex: String = "#1E1E2E",
        customColorOpacity: Double = 0.55,
        floatingX: Double? = nil,
        floatingY: Double? = nil,
        items: [PinnedItem] = [],
        showLabels: Bool = false,
        magnificationEnabled: Bool = true,
        magnificationScale: Double = 1.25,
        cornerRadius: Double = 22.0,
        paddingH: Double = 14.0,
        paddingV: Double = 10.0,
        isVisible: Bool = true
    ) {
        self.id = id
        self.name = name
        self.orientation = orientation
        self.edge = edge
        self.screenIndex = screenIndex
        self.iconSize = iconSize
        self.spacing = spacing
        self.autoHide = autoHide
        self.backgroundStyle = backgroundStyle
        self.useCustomColor = useCustomColor
        self.customColorHex = customColorHex
        self.customColorOpacity = customColorOpacity
        self.floatingX = floatingX
        self.floatingY = floatingY
        self.items = items
        self.showLabels = showLabels
        self.magnificationEnabled = magnificationEnabled
        self.magnificationScale = magnificationScale
        self.cornerRadius = cornerRadius
        self.paddingH = paddingH
        self.paddingV = paddingV
        self.isVisible = isVisible
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        let rawName = try container.decode(String.self, forKey: .name)
        self.name = String(rawName.prefix(128))
        self.orientation = try container.decode(DockOrientation.self, forKey: .orientation)
        self.edge = try container.decode(DockEdge.self, forKey: .edge)
        let rawScreenIndex = try container.decode(Int.self, forKey: .screenIndex)
        self.screenIndex = max(0, min(rawScreenIndex, 32))

        // Defensive bounds clamping to protect UI and memory
        let rawIconSize = try container.decodeIfPresent(Double.self, forKey: .iconSize) ?? 64.0
        self.iconSize = min(max(rawIconSize, 16.0), 256.0)

        let rawSpacing = try container.decodeIfPresent(Double.self, forKey: .spacing) ?? 12.0
        self.spacing = min(max(rawSpacing, 0.0), 100.0)

        self.autoHide = try container.decodeIfPresent(Bool.self, forKey: .autoHide) ?? true
        self.backgroundStyle = try container.decode(BackgroundStyle.self, forKey: .backgroundStyle)
        self.useCustomColor = try container.decodeIfPresent(Bool.self, forKey: .useCustomColor) ?? false
        self.customColorHex = try container.decodeIfPresent(String.self, forKey: .customColorHex) ?? "#1E1E2E"

        let rawOpacity = try container.decodeIfPresent(Double.self, forKey: .customColorOpacity) ?? 0.55
        self.customColorOpacity = min(max(rawOpacity, 0.0), 1.0)

        self.floatingX = try container.decodeIfPresent(Double.self, forKey: .floatingX)
        self.floatingY = try container.decodeIfPresent(Double.self, forKey: .floatingY)

        let rawItems = try container.decode([PinnedItem].self, forKey: .items)
        self.items = Array(rawItems.prefix(256))

        self.showLabels = try container.decodeIfPresent(Bool.self, forKey: .showLabels) ?? false
        self.magnificationEnabled = try container.decodeIfPresent(Bool.self, forKey: .magnificationEnabled) ?? true

        let rawMagScale = try container.decodeIfPresent(Double.self, forKey: .magnificationScale) ?? 1.25
        self.magnificationScale = min(max(rawMagScale, 1.0), 3.0)

        let rawCorner = try container.decodeIfPresent(Double.self, forKey: .cornerRadius) ?? 22.0
        self.cornerRadius = min(max(rawCorner, 0.0), 64.0)

        let rawPadH = try container.decodeIfPresent(Double.self, forKey: .paddingH) ?? 14.0
        self.paddingH = min(max(rawPadH, 0.0), 64.0)

        let rawPadV = try container.decodeIfPresent(Double.self, forKey: .paddingV) ?? 10.0
        self.paddingV = min(max(rawPadV, 0.0), 64.0)

        self.isVisible = try container.decodeIfPresent(Bool.self, forKey: .isVisible) ?? true
        // Backward-compat: if backgroundStyle is unknown, fall back to glass
        if self.backgroundStyle == BackgroundStyle.glass && (try? container.decodeIfPresent(String.self, forKey: .backgroundStyle)) == nil {
            self.backgroundStyle = .glass
        }
    }

    public static func defaultOrientation(for edge: DockEdge) -> DockOrientation {
        switch edge {
        case .left, .right:
            return .vertical
        case .bottom, .top, .floating:
            return .horizontal
        }
    }

    public mutating func updateEdge(_ newEdge: DockEdge) {
        self.edge = newEdge
        if newEdge != .floating {
            self.orientation = DockConfig.defaultOrientation(for: newEdge)
        }
    }

    public static func defaultDock() -> DockConfig {
        var defaultItems: [PinnedItem] = []

        let candidatePaths = [
            "/System/Applications/Finder.app",
            "/Applications/Safari.app",
            "/System/Applications/Safari.app",
            "/System/Applications/Mail.app",
            "/System/Applications/Messages.app",
            "/System/Applications/Utilities/Terminal.app",
            "/System/Applications/System Settings.app"
        ]

        for path in candidatePaths {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: path) {
                defaultItems.append(PinnedItem(url: url))
            }
        }

        return DockConfig(
            name: "Screen 1 - Primary Dock",
            orientation: .horizontal,
            edge: .bottom,
            screenIndex: 0,
            iconSize: 64.0,
            spacing: 12.0,
            autoHide: true,
            backgroundStyle: .glass,
            useCustomColor: false,
            customColorHex: "#1E1E2E",
            customColorOpacity: 0.55,
            items: defaultItems
        )
    }

    public static func createDock(forScreen screenIndex: Int, dockNumber: Int = 1) -> DockConfig {
        let name: String
        if screenIndex == 0 {
            name = dockNumber == 1 ? "Screen 1 - Primary Dock" : "Screen 1 - Dock \(dockNumber)"
        } else {
            name = dockNumber == 1 ? "Screen \(screenIndex + 1) - Secondary Dock" : "Screen \(screenIndex + 1) - Dock \(dockNumber)"
        }

        return DockConfig(
            name: name,
            orientation: .horizontal,
            edge: .bottom,
            screenIndex: screenIndex,
            iconSize: 64.0,
            spacing: 12.0,
            autoHide: true,
            backgroundStyle: .glass,
            useCustomColor: false,
            customColorHex: "#1E1E2E",
            customColorOpacity: 0.55,
            items: []
        )
    }
}

// MARK: - Color Hex Conversion
public extension DockConfig {
    var swiftUIColor: Color {
        Color(hex: customColorHex) ?? Color.accentColor
    }

    static func hexString(from color: Color) -> String {
        let nsColor = NSColor(color).usingColorSpace(.sRGB) ?? NSColor(color)
        let red = Int(round(nsColor.redComponent * 255.0))
        let green = Int(round(nsColor.greenComponent * 255.0))
        let blue = Int(round(nsColor.blueComponent * 255.0))
        return String(format: "#%02X%02X%02X", red, green, blue)
    }

    /// Apply a ColorTheme preset, overwriting appearance fields.
    mutating func applyTheme(_ theme: ColorTheme) {
        backgroundStyle = theme.backgroundStyle
        useCustomColor = theme.useCustomColor
        customColorHex = theme.colorHex
        customColorOpacity = theme.colorOpacity
        cornerRadius = theme.cornerRadius
    }
}


public extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let red, green, blue: Double
        if hexSanitized.count == 6 {
            red = Double((rgb & 0xFF0000) >> 16) / 255.0
            green = Double((rgb & 0x00FF00) >> 8) / 255.0
            blue = Double(rgb & 0x0000FF) / 255.0
        } else if hexSanitized.count == 8 {
            red = Double((rgb & 0xFF000000) >> 24) / 255.0
            green = Double((rgb & 0x00FF0000) >> 16) / 255.0
            blue = Double((rgb & 0x0000FF00) >> 8) / 255.0
        } else {
            return nil
        }

        self.init(red: red, green: green, blue: blue)
    }
}
