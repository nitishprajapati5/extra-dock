import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Liquid Glass Background View

/// An iridescent, animated "Liquid Glass" background — approximating the macOS 26 Tahoe
/// design language with a layered blur + prismatic colour shimmer.
struct LiquidGlassBackground: View {
    @State private var phase: Double = 0.0

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.04)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                // Base — thick system material
                Rectangle().fill(.regularMaterial)

                // Iridescent shimmer layer 1 (slow rotation)
                AngularGradient(
                    gradient: Gradient(colors: [
                        Color(hue: (t * 0.04).truncatingRemainder(dividingBy: 1.0),        saturation: 0.6, brightness: 1.0, opacity: 0.10),
                        Color(hue: ((t * 0.04) + 0.33).truncatingRemainder(dividingBy: 1.0), saturation: 0.7, brightness: 1.0, opacity: 0.10),
                        Color(hue: ((t * 0.04) + 0.66).truncatingRemainder(dividingBy: 1.0), saturation: 0.6, brightness: 1.0, opacity: 0.10),
                        Color(hue: (t * 0.04).truncatingRemainder(dividingBy: 1.0),        saturation: 0.6, brightness: 1.0, opacity: 0.10),
                    ]),
                    center: .center
                )
                .blendMode(.softLight)

                // Shimmer layer 2 — faster, offset hue
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hue: ((t * 0.07) + 0.5).truncatingRemainder(dividingBy: 1.0), saturation: 0.5, brightness: 1.0, opacity: 0.08),
                        Color.white.opacity(0.04),
                        Color(hue: ((t * 0.07) + 0.8).truncatingRemainder(dividingBy: 1.0), saturation: 0.5, brightness: 1.0, opacity: 0.08),
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .blendMode(.screen)

                // Top highlight — frosted glint
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.22),
                        Color.white.opacity(0.0),
                    ]),
                    startPoint: .top,
                    endPoint: UnitPoint(x: 0.5, y: 0.35)
                )
            }
        }
    }
}

// MARK: - DockView

public struct DockView: View {
    public let dockId: UUID
    @ObservedObject var dockManager: DockManager
    @State private var isTargetedForDrop = false
    @State private var dragOffset: CGSize = .zero
    @State private var dragStartOrigin: CGPoint = .zero

    public init(dockId: UUID, dockManager: DockManager) {
        self.dockId = dockId
        self.dockManager = dockManager
    }

    private var config: DockConfig? {
        dockManager.docks.first(where: { $0.id == dockId })
    }

    public var body: some View {
        if let config = config {
            let isVertical = config.orientation == .vertical
            let cr = config.cornerRadius
            let pH = isVertical ? config.paddingV : config.paddingH
            let pV = isVertical ? config.paddingH : config.paddingV

            Group {
                if isVertical {
                    VStack(spacing: config.spacing) {
                        itemsContent(config: config, isVertical: true)
                    }
                } else {
                    HStack(spacing: config.spacing) {
                        itemsContent(config: config, isVertical: false)
                    }
                }
            }
            .padding(.horizontal, pH)
            .padding(.vertical, pV)
            .background(dockBackground(for: config))
            .overlay(
                RoundedRectangle(cornerRadius: cr, style: .continuous)
                    .stroke(
                        isTargetedForDrop
                            ? Color.accentColor.opacity(0.8)
                            : borderColor(for: config),
                        lineWidth: isTargetedForDrop ? 2.5 : 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cr, style: .continuous))
            .shadow(
                color: shadowColor(for: config),
                radius: config.backgroundStyle == .liquidGlass ? 20 : 16,
                x: 0,
                y: config.backgroundStyle == .liquidGlass ? 10 : 8
            )
            .scaleEffect(isTargetedForDrop ? 1.04 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isTargetedForDrop)
            .onDrop(of: [.fileURL], isTargeted: $isTargetedForDrop) { providers in
                handleDrop(providers: providers, dockId: config.id)
            }
            .gesture(
                config.edge == .floating ? dragGesture(config: config) : nil
            )
        }
    }

    // MARK: - Helpers

    private func borderColor(for config: DockConfig) -> Color {
        switch config.backgroundStyle {
        case .liquidGlass:
            return Color.white.opacity(0.35)
        default:
            return config.useCustomColor
                ? config.swiftUIColor.opacity(0.4)
                : Color.white.opacity(0.18)
        }
    }

    private func shadowColor(for config: DockConfig) -> Color {
        switch config.backgroundStyle {
        case .liquidGlass:
            return Color.black.opacity(0.22)
        default:
            return config.useCustomColor
                ? config.swiftUIColor.opacity(min(config.customColorOpacity * 0.7, 0.45))
                : Color.black.opacity(0.28)
        }
    }

    @ViewBuilder
    private func itemsContent(config: DockConfig, isVertical: Bool) -> some View {
        if config.items.isEmpty {
            Text("Drop apps here")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.secondary)
                .padding(8)
        } else {
            ForEach(config.items) { item in
                DockItemView(
                    item: item,
                    dockId: config.id,
                    iconSize: config.iconSize,
                    isVertical: isVertical,
                    showLabel: config.showLabels,
                    magnificationEnabled: config.magnificationEnabled,
                    magnificationScale: config.magnificationScale,
                    dockManager: dockManager,
                    onRemove: {
                        dockManager.removeItem(itemId: item.id, from: config.id)
                    }
                )
            }
        }
    }

    @ViewBuilder
    private func dockBackground(for config: DockConfig) -> some View {
        ZStack {
            switch config.backgroundStyle {
            case .glass:
                Rectangle().fill(.ultraThinMaterial)
                Color.black.opacity(0.12)
            case .dark:
                Rectangle().fill(.thinMaterial)
                Color.black.opacity(0.45)
            case .ultraThin:
                Rectangle().fill(.ultraThinMaterial)
            case .clear:
                Color.black.opacity(0.04)
            case .liquidGlass:
                LiquidGlassBackground()
            }

            if config.useCustomColor {
                config.swiftUIColor
                    .opacity(config.customColorOpacity)
            }
        }
    }

    // MARK: - Drag (Floating)

    private func dragGesture(config: DockConfig) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                dragOffset = value.translation
            }
            .onEnded { value in
                dockManager.applyFloatingDrag(
                    dockId: config.id,
                    totalDX: value.translation.width,
                    totalDY: -value.translation.height,
                    startOrigin: dragStartOrigin
                )
                dragOffset = .zero
            }
    }

    // MARK: - Drop

    private func handleDrop(providers: [NSItemProvider], dockId: UUID) -> Bool {
        var handled = false
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else {
                        if let directUrl = item as? URL {
                            DispatchQueue.main.async {
                                self.dockManager.addItem(PinnedItem(url: directUrl), to: dockId)
                            }
                        }
                        return
                    }
                    DispatchQueue.main.async {
                        self.dockManager.addItem(PinnedItem(url: url), to: dockId)
                    }
                }
                handled = true
            }
        }
        return handled
    }
}
