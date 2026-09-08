import AppKit
import SwiftUI

// MARK: - Dock Item View

public struct DockItemView: View {
    public let item: PinnedItem
    public let dockId: UUID
    public let iconSize: Double
    public let isVertical: Bool
    public let showLabel: Bool
    public let magnificationEnabled: Bool
    public let magnificationScale: Double
    public let onRemove: () -> Void

    @ObservedObject private var runningApps = RunningAppsMonitor.shared
    @ObservedObject private var dockManager: DockManager
    @State private var isHovered = false

    public init(
        item: PinnedItem,
        dockId: UUID,
        iconSize: Double,
        isVertical: Bool,
        showLabel: Bool = false,
        magnificationEnabled: Bool = true,
        magnificationScale: Double = 1.25,
        dockManager: DockManager = .shared,
        onRemove: @escaping () -> Void
    ) {
        self.item = item
        self.dockId = dockId
        self.iconSize = iconSize
        self.isVertical = isVertical
        self.showLabel = showLabel
        self.magnificationEnabled = magnificationEnabled
        self.magnificationScale = magnificationScale
        self.dockManager = dockManager
        self.onRemove = onRemove
    }

    private var isRunning: Bool { runningApps.isRunning(item: item) }
    private var badgeCount: Int { runningApps.badgeCount(for: item) }

    private var hoverScale: Double {
        guard magnificationEnabled else { return 1.0 }
        return isHovered ? magnificationScale : 1.0
    }

    public var body: some View {
        if item.isSeparator {
            SeparatorItemView(isVertical: isVertical, iconSize: iconSize)
        } else {
            regularItemView
        }
    }

    @ViewBuilder
    private var regularItemView: some View {
        Button(action: { item.launch() }) {
            ZStack(alignment: isVertical ? .trailing : .bottom) {
                VStack(spacing: showLabel ? 2 : 3) {
                    // Icon + badge overlay
                    ZStack(alignment: .topTrailing) {
                        Image(nsImage: item.icon)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: iconSize, height: iconSize)
                            .shadow(
                                color: isHovered ? Color.black.opacity(0.35) : Color.black.opacity(0.18),
                                radius: isHovered ? 8 : 4,
                                y: isHovered ? 4 : 2
                            )

                        // Notification badge
                        if badgeCount > 0 {
                            ZStack {
                                Capsule()
                                    .fill(Color.red)
                                    .frame(width: badgeCount > 9 ? 18 : 14, height: 14)
                                Text(badgeCount > 99 ? "99+" : "\(badgeCount)")
                                    .font(.system(size: 8, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            .offset(x: 4, y: -4)
                        }

                        // Custom icon indicator (small star badge)
                        if item.customIconPath != nil {
                            Image(systemName: "star.fill")
                                .font(.system(size: 6))
                                .foregroundColor(.yellow)
                                .padding(2)
                                .background(Circle().fill(Color.black.opacity(0.5)))
                                .offset(x: -2, y: 2)
                                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        }
                    }

                    // Label
                    if showLabel {
                        Text(item.displayName)
                            .font(.system(size: max(9, iconSize * 0.135), weight: .medium))
                            .foregroundColor(.primary.opacity(0.85))
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .frame(maxWidth: iconSize + 12)
                    }

                    // Running dot (horizontal)
                    if !isVertical {
                        Circle()
                            .fill(isRunning ? Color.primary.opacity(0.85) : Color.clear)
                            .frame(width: 4.5, height: 4.5)
                            .padding(.top, showLabel ? 0 : 1)
                    }
                }

                // Running dot (vertical)
                if isVertical {
                    Circle()
                        .fill(isRunning ? Color.primary.opacity(0.85) : Color.clear)
                        .frame(width: 4.5, height: 4.5)
                        .padding(.trailing, 2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .scaleEffect(hoverScale)
        .animation(.spring(response: 0.22, dampingFraction: 0.72), value: isHovered)
        .onHover { isHovered = $0 }
        .help(item.displayName)
        .contextMenu {
            Text(item.displayName).font(.headline)

            Divider()

            Button("Open") { item.launch() }
            Button("Show in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([item.url])
            }

            Divider()

            // Custom icon actions
            Button("Change Icon...") {
                dockManager.promptPickCustomIcon(itemId: item.id, in: dockId)
            }
            if item.customIconPath != nil {
                Button("Reset to Default Icon") {
                    dockManager.setCustomIcon(itemId: item.id, in: dockId, iconPath: nil)
                }
            }

            Divider()

            Button("Remove from Dock", role: .destructive) { onRemove() }
        }
    }
}

// MARK: - Separator Item View

struct SeparatorItemView: View {
    let isVertical: Bool
    let iconSize: Double

    var body: some View {
        if isVertical {
            Rectangle()
                .fill(Color.primary.opacity(0.2))
                .frame(width: max(iconSize * 0.55, 24), height: 1.5)
                .padding(.vertical, 4)
        } else {
            Rectangle()
                .fill(Color.primary.opacity(0.2))
                .frame(width: 1.5, height: max(iconSize * 0.55, 24))
                .padding(.horizontal, 4)
        }
    }
}
