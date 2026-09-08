import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
public struct SettingsView: View {
    @ObservedObject var dockManager: DockManager
    @State private var selectedDockId: UUID?
    @State private var selectedTab: SettingsTab = .appearance

    public enum SettingsTab: String, CaseIterable, Identifiable {
        case appPool = "App Pool"
        case appearance = "Appearance & Color"
        case layout = "Position & Layout"
        case pinned = "Pinned Items"
        case general = "General"

        public var id: String { rawValue }

        var iconName: String {
            switch self {
            case .appPool: return "square.grid.2x2"
            case .appearance: return "paintpalette"
            case .layout: return "rectangle.dock"
            case .pinned: return "pin"
            case .general: return "gearshape"
            }
        }
    }

    public init(dockManager: DockManager) {
        self.dockManager = dockManager
        _selectedDockId = State(initialValue: dockManager.docks.first?.id)
    }

    public init() {
        self.init(dockManager: .shared)
    }

    private var selectedDock: DockConfig? {
        dockManager.docks.first(where: { $0.id == selectedDockId })
    }

    public var body: some View {
        NavigationSplitView {
            List(selection: $selectedDockId) {
                ForEach(Array(NSScreen.screens.enumerated()), id: \.offset) { screenIdx, _ in
                    let screenDocks = dockManager.docks.filter { $0.screenIndex == screenIdx }
                    let screenTitle = screenIdx == 0
                        ? "Display 1 (Primary)"
                        : "Display \(screenIdx + 1) (Secondary)"

                    Section(screenTitle) {
                        if screenDocks.isEmpty {
                            Button(action: {
                                dockManager.addDock(forScreen: screenIdx)
                                selectedDockId = dockManager.docks.last?.id
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "plus.circle.dashed")
                                    Text("Add Dock for this Screen")
                                        .font(.caption)
                                }
                                .foregroundColor(.accentColor)
                            }
                            .buttonStyle(.plain)
                        } else {
                            ForEach(screenDocks) { dock in
                                NavigationLink(value: dock.id) {
                                    HStack(spacing: 8) {
                                        Image(systemName: dock.orientation == .horizontal ? "dock.rectangle" : "dock.arrowtriangle.down")
                                            .foregroundColor(.accentColor)
                                        Text(dock.name)
                                            .fontWeight(.medium)
                                        Spacer()
                                        Text("\(dock.items.count)")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Capsule().fill(Color.secondary.opacity(0.15)))
                                    }
                                }
                            }
                        }
                    }
                }

                // Docks on other / disconnected screens if any
                let otherDocks = dockManager.docks.filter { $0.screenIndex >= NSScreen.screens.count }
                if !otherDocks.isEmpty {
                    Section("Other Screens") {
                        ForEach(otherDocks) { dock in
                            NavigationLink(value: dock.id) {
                                HStack(spacing: 8) {
                                    Image(systemName: "dock.rectangle")
                                        .foregroundColor(.secondary)
                                    Text(dock.name)
                                    Spacer()
                                    Text("Screen \(dock.screenIndex + 1)")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 250)
            .toolbar {
                ToolbarItem {
                    Menu {
                        ForEach(Array(NSScreen.screens.enumerated()), id: \.offset) { idx, _ in
                            Button(idx == 0 ? "Add for Display 1 (Primary)" : "Add for Display \(idx + 1) (Secondary)") {
                                dockManager.addDock(forScreen: idx)
                                selectedDockId = dockManager.docks.last?.id
                            }
                        }
                        if NSScreen.screens.count > 1 {
                            Divider()
                            Button("Create Docks for All Displays") {
                                dockManager.addDocksForEveryScreen()
                                selectedDockId = dockManager.docks.last?.id
                            }
                        }
                    } label: {
                        Label("Add Dock", systemImage: "plus")
                    }
                }
            }
        } detail: {
            if let dock = selectedDock {
                VStack(spacing: 0) {
                    // Header with Tab Bar
                    HStack(spacing: 12) {
                        ForEach(SettingsTab.allCases) { tab in
                            Button(action: {
                                selectedTab = tab
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: tab.iconName)
                                    Text(tab.rawValue)
                                }
                                .font(.system(size: 12, weight: selectedTab == tab ? .semibold : .regular))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    selectedTab == tab
                                        ? Capsule().fill(Color.accentColor.opacity(0.18))
                                        : Capsule().fill(Color.clear)
                                )
                                .foregroundColor(selectedTab == tab ? .accentColor : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(NSColor.windowBackgroundColor))

                    Divider()

                    // Tab Content
                    Group {
                        switch selectedTab {
                        case .appPool:
                            AppPoolTabView(
                                dock: dock,
                                onAddItem: { item in
                                    dockManager.addItem(item, to: dock.id)
                                }
                            )
                        case .appearance:
                            AppearanceTabView(
                                dock: dock,
                                onUpdate: { updated in
                                    dockManager.updateDock(updated)
                                }
                            )
                        case .layout:
                            LayoutTabView(
                                dock: dock,
                                dockCount: dockManager.docks.count,
                                onUpdate: { updated in
                                    dockManager.updateDock(updated)
                                },
                                onDelete: {
                                    dockManager.removeDock(id: dock.id)
                                    selectedDockId = dockManager.docks.first?.id
                                }
                            )
                        case .pinned:
                            PinnedItemsTabView(
                                dock: dock,
                                onRemoveItem: { itemId in
                                    dockManager.removeItem(itemId: itemId, from: dock.id)
                                },
                                onMoveItem: { from, to in
                                    dockManager.moveItem(in: dock.id, from: from, to: to)
                                },
                                onAddSeparator: {
                                    dockManager.addSeparator(to: dock.id)
                                }
                            )
                        case .general:
                            GeneralTabView()
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .navigationTitle(dock.name)
                .id(dock.id)
            } else {
                Text("Select a dock from the sidebar to configure")
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 980, height: 660)
    }
}

// MARK: - App Pool Tab
struct AppPoolTabView: View {
    let dock: DockConfig
    let onAddItem: (PinnedItem) -> Void

    @StateObject private var poolManager = AppPoolManager.shared
    @State private var searchText: String = ""

    private var filteredApps: [PinnedItem] {
        poolManager.filteredApps(searchQuery: searchText)
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search installed applications...", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button(action: {
                    poolManager.refreshPool()
                }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(poolManager.isLoading)

                Button(action: {
                    poolManager.promptPickAppOrFile { item in
                        if let item = item {
                            onAddItem(item)
                        }
                    }
                }) {
                    Label("Browse File / App...", systemImage: "folder.badge.plus")
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color(NSColor.controlBackgroundColor)))
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Text("💡 Tip: Click '+ Add to Dock' or drag any app icon directly to the floating dock.")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)

            if poolManager.isLoading {
                Spacer()
                ProgressView("Scanning installed applications...")
                Spacer()
            } else if filteredApps.isEmpty {
                Spacer()
                Text("No applications found matching '\(searchText)'.")
                    .foregroundColor(.secondary)
                Spacer()
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 12)], spacing: 12) {
                        ForEach(filteredApps) { item in
                            let isAlreadyInDock = dock.items.contains(where: { $0.url == item.url })

                            VStack(spacing: 6) {
                                Image(nsImage: item.icon)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: 44, height: 44)
                                    .onDrag {
                                        NSItemProvider(object: item.url as NSURL)
                                    }

                                Text(item.displayName)
                                    .font(.system(size: 11, weight: .medium))
                                    .lineLimit(1)
                                    .truncationMode(.tail)

                                if isAlreadyInDock {
                                    HStack(spacing: 3) {
                                        Image(systemName: "checkmark")
                                            .font(.caption2)
                                        Text("Added")
                                            .font(.caption2)
                                    }
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                } else {
                                    Button(action: {
                                        onAddItem(item)
                                    }) {
                                        HStack(spacing: 3) {
                                            Image(systemName: "plus")
                                                .font(.caption2)
                                            Text("Add to Dock")
                                                .font(.caption2)
                                        }
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                                        .foregroundColor(.accentColor)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color(NSColor.controlBackgroundColor).opacity(0.6))
                            )
                        }
                    }
                    .padding(16)
                }
            }
        }
    }
}

// MARK: - Appearance & Background Color Tab
struct AppearanceTabView: View {
    @State private var config: DockConfig
    @State private var selectedColor: Color
    let onUpdate: (DockConfig) -> Void

    init(dock: DockConfig, onUpdate: @escaping (DockConfig) -> Void) {
        _config = State(initialValue: dock)
        _selectedColor = State(initialValue: dock.swiftUIColor)
        self.onUpdate = onUpdate
    }

    var body: some View {
        ScrollView {
            Form {

                // ── Color Themes ──────────────────────────────────────────
                Section("Color Themes") {
                    Text("Tap a theme to instantly apply a curated color + material combination.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 110, maximum: 140), spacing: 10)],
                        spacing: 10
                    ) {
                        ForEach(ColorTheme.presets) { theme in
                            ThemeSwatchView(theme: theme) {
                                config.applyTheme(theme)
                                selectedColor = config.swiftUIColor
                                onUpdate(config)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // ── Icon Labels ───────────────────────────────────────────
                Section("Icon Labels") {
                    Toggle("Show App Name Below Icons", isOn: $config.showLabels)
                        .onChange(of: config.showLabels) { _ in onUpdate(config) }
                    if config.showLabels {
                        Text("Label size scales with icon size. Long names are truncated.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // ── Hover Magnification ───────────────────────────────────
                Section("Hover Magnification") {
                    Toggle("Magnify Icons on Hover", isOn: $config.magnificationEnabled)
                        .onChange(of: config.magnificationEnabled) { _ in onUpdate(config) }

                    if config.magnificationEnabled {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Magnification Scale")
                                Spacer()
                                Text("\(config.magnificationScale, specifier: "%.2f")×")
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $config.magnificationScale, in: 1.05...2.0, step: 0.05)
                                .onChange(of: config.magnificationScale) { _ in onUpdate(config) }
                        }
                    }
                }

                // ── Shape & Padding ───────────────────────────────────────
                Section("Shape & Padding") {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Corner Radius")
                            Spacer()
                            Text("\(Int(config.cornerRadius)) pt")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $config.cornerRadius, in: 0...28, step: 1)
                            .onChange(of: config.cornerRadius) { _ in onUpdate(config) }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Horizontal Padding")
                            Spacer()
                            Text("\(Int(config.paddingH)) pt")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $config.paddingH, in: 4...40, step: 1)
                            .onChange(of: config.paddingH) { _ in onUpdate(config) }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Vertical Padding")
                            Spacer()
                            Text("\(Int(config.paddingV)) pt")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $config.paddingV, in: 4...32, step: 1)
                            .onChange(of: config.paddingV) { _ in onUpdate(config) }
                    }
                }

                // ── Background Style ──────────────────────────────────────
                Section("Background Style") {
                    Picker("Material", selection: $config.backgroundStyle) {
                        ForEach(BackgroundStyle.allCases, id: \.self) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    .onChange(of: config.backgroundStyle) { _ in onUpdate(config) }

                    if config.backgroundStyle == .liquidGlass {
                        HStack(spacing: 8) {
                            Image(systemName: "drop.fill")
                                .foregroundColor(.blue)
                            Text("Liquid Glass renders an animated iridescent shimmer inspired by macOS 26 Tahoe.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // ── Custom Color Tint ─────────────────────────────────────
                Section("Custom Color Tint") {
                    Toggle("Enable Custom Background Color Tint", isOn: $config.useCustomColor)
                        .onChange(of: config.useCustomColor) { _ in onUpdate(config) }

                    if config.useCustomColor {
                        ColorPicker("Dock Tint Color", selection: $selectedColor)
                            .onChange(of: selectedColor) { newColor in
                                config.customColorHex = DockConfig.hexString(from: newColor)
                                onUpdate(config)
                            }

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Color Opacity / Intensity")
                                Spacer()
                                Text("\(Int(config.customColorOpacity * 100))%")
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $config.customColorOpacity, in: 0.05...1.0, step: 0.05)
                                .onChange(of: config.customColorOpacity) { _ in onUpdate(config) }
                        }

                        // Live Preview
                        HStack {
                            Text("Preview")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            ZStack {
                                Rectangle().fill(.ultraThinMaterial)
                                selectedColor.opacity(config.customColorOpacity)
                            }
                            .frame(width: 140, height: 36)
                            .clipShape(RoundedRectangle(cornerRadius: config.cornerRadius))
                            .overlay(
                                RoundedRectangle(cornerRadius: config.cornerRadius)
                                    .stroke(selectedColor.opacity(0.4), lineWidth: 1)
                            )
                            .shadow(color: selectedColor.opacity(config.customColorOpacity * 0.5), radius: 6)
                        }
                        .padding(.top, 4)
                    }
                }

                // ── Sizing & Spacing ──────────────────────────────────────
                Section("Sizing & Spacing") {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Icon Size")
                            Spacer()
                            Text("\(Int(config.iconSize)) pt")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $config.iconSize, in: 36...128, step: 2)
                            .onChange(of: config.iconSize) { _ in onUpdate(config) }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("Item Spacing")
                            Spacer()
                            Text("\(Int(config.spacing)) pt")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $config.spacing, in: 4...32, step: 1)
                            .onChange(of: config.spacing) { _ in onUpdate(config) }
                    }
                }
            }
            .formStyle(.grouped)
            .padding(8)
        }
    }
}

// MARK: - Theme Swatch View
private struct ThemeSwatchView: View {
    let theme: ColorTheme
    let onApply: () -> Void
    @State private var isHovered = false

    var swatchColor: Color {
        theme.useCustomColor
            ? (Color(hex: theme.colorHex) ?? .accentColor)
            : Color.clear
    }

    var body: some View {
        Button(action: onApply) {
            VStack(spacing: 6) {
                ZStack {
                    // Material layer
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .frame(height: 40)

                    // Color tint
                    if theme.useCustomColor {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(swatchColor.opacity(theme.colorOpacity))
                            .frame(height: 40)
                    }

                    // Liquid glass shimmer swatch
                    if theme.backgroundStyle == .liquidGlass {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.purple.opacity(0.2), .blue.opacity(0.15), .teal.opacity(0.2)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 40)
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [.white.opacity(0.25), .clear],
                                    startPoint: .top,
                                    endPoint: .center
                                )
                            )
                            .frame(height: 40)
                    }

                    // Icon
                    Image(systemName: theme.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(theme.useCustomColor ? swatchColor.opacity(3) : .primary)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(
                            isHovered ? Color.accentColor.opacity(0.8) : Color.white.opacity(0.2),
                            lineWidth: isHovered ? 2 : 1
                        )
                )
                .scaleEffect(isHovered ? 1.05 : 1.0)
                .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isHovered)

                Text(theme.name)
                    .font(.system(size: 10, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundColor(.primary.opacity(0.85))
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Layout & Behavior Tab
struct LayoutTabView: View {
    @State private var config: DockConfig
    let dockCount: Int
    let onUpdate: (DockConfig) -> Void
    let onDelete: () -> Void

    init(dock: DockConfig, dockCount: Int, onUpdate: @escaping (DockConfig) -> Void, onDelete: @escaping () -> Void) {
        _config = State(initialValue: dock)
        self.dockCount = dockCount
        self.onUpdate = onUpdate
        self.onDelete = onDelete
    }

    var body: some View {
        Form {
            Section("Dock Identity") {
                TextField("Dock Name", text: $config.name)
                    .onChange(of: config.name) { _ in onUpdate(config) }
            }

            Section("Screen Placement & Orientation") {
                Picker("Position / Edge", selection: $config.edge) {
                    Text("Bottom (Horizontal)").tag(DockEdge.bottom)
                    Text("Top (Horizontal)").tag(DockEdge.top)
                    Text("Left (Vertical)").tag(DockEdge.left)
                    Text("Right (Vertical)").tag(DockEdge.right)
                    Text("Floating (Draggable)").tag(DockEdge.floating)
                }
                .onChange(of: config.edge) { newEdge in
                    config.updateEdge(newEdge)
                    onUpdate(config)
                }

                Picker("Orientation", selection: $config.orientation) {
                    Text("Horizontal").tag(DockOrientation.horizontal)
                    Text("Vertical").tag(DockOrientation.vertical)
                }
                .onChange(of: config.orientation) { _ in onUpdate(config) }

                Text(config.edge == .left || config.edge == .right
                     ? "⚡ Left/Right edge automatically set orientation to Vertical."
                     : (config.edge == .bottom || config.edge == .top
                        ? "⚡ Bottom/Top edge automatically set orientation to Horizontal."
                        : "📍 Free-floating mode: drag anywhere on screen."))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Divider()

                Picker("Target Display", selection: $config.screenIndex) {
                    ForEach(Array(NSScreen.screens.enumerated()), id: \.offset) { index, screen in
                        let role = index == 0 ? "Primary" : "Secondary"
                        Text("Screen \(index + 1) - \(role) (\(Int(screen.frame.width))×\(Int(screen.frame.height)))")
                            .tag(index)
                    }
                }
                .onChange(of: config.screenIndex) { newScreenIndex in
                    if config.name.hasPrefix("Screen ") || config.name.hasPrefix("Dock ") || config.name.contains("Primary") || config.name.contains("Secondary") {
                        let role = newScreenIndex == 0 ? "Primary Dock" : "Secondary Dock"
                        config.name = "Screen \(newScreenIndex + 1) - \(role)"
                    }
                    onUpdate(config)
                }

                Button("Reset Name to Display Role") {
                    let role = config.screenIndex == 0 ? "Primary Dock" : "Secondary Dock"
                    config.name = "Screen \(config.screenIndex + 1) - \(role)"
                    onUpdate(config)
                }
                .font(.caption)
            }

            Section("Behavior") {
                Toggle("Visible on Screen", isOn: $config.isVisible)
                    .onChange(of: config.isVisible) { _ in onUpdate(config) }
                Text(config.isVisible
                     ? "This dock is currently shown on Screen \(config.screenIndex + 1)."
                     : "This dock is hidden. It will stay on Screen \(config.screenIndex + 1) but not display.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Divider()

                Toggle("Auto-hide dock (slide in when mouse hovers over screen edge)", isOn: $config.autoHide)
                    .onChange(of: config.autoHide) { _ in onUpdate(config) }
            }

            if dockCount > 1 {
                Section {
                    Button(role: .destructive, action: onDelete) {
                        Label("Delete Dock", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(8)
    }
}

// MARK: - Pinned Items Tab (Feature 5 & 6)
struct PinnedItemsTabView: View {
    let dock: DockConfig
    let onRemoveItem: (UUID) -> Void
    let onMoveItem: (IndexSet, Int) -> Void
    let onAddSeparator: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Toolbar
            HStack {
                Text("Pinned Items")
                    .font(.headline)
                Spacer()
                // Feature 5: Add Separator button
                Button(action: onAddSeparator) {
                    Label("Add Separator", systemImage: "line.diagonal")
                }
                .help("Insert a visual divider between items")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)

            Divider()

            if dock.items.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "square.dashed")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("No items pinned to this dock")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("Use the 'App Pool' tab or drag applications directly to the dock.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                // Feature 6: Drag-to-reorder via List onMove
                List {
                    ForEach(dock.items) { item in
                        HStack(spacing: 12) {
                            // Separator items render differently
                            if item.isSeparator {
                                Image(systemName: "line.diagonal")
                                    .foregroundColor(.secondary)
                                    .frame(width: 28, height: 28)

                                Text("── Separator ──")
                                    .foregroundColor(.secondary)
                                    .italic()
                            } else {
                                Image(nsImage: item.icon)
                                    .resizable()
                                    .frame(width: 28, height: 28)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.displayName)
                                        .fontWeight(.medium)
                                    Text(item.url.path)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                            }

                            Spacer()

                            Button(role: .destructive, action: {
                                onRemoveItem(item.id)
                            }) {
                                Image(systemName: "trash")
                                    .foregroundColor(.red.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                    }
                    .onMove(perform: onMoveItem)
                }

                Text("Drag rows to reorder items on the dock.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
        }
    }
}

// MARK: - General Tab (Feature 8: Launch at Login)
struct GeneralTabView: View {
    @ObservedObject private var loginManager = LaunchAtLoginManager.shared

    var body: some View {
        Form {
            Section("Startup") {
                Toggle("Launch OrbitDock at Login", isOn: $loginManager.isEnabled)
                Text("OrbitDock will start automatically when you log in to your Mac.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
                LabeledContent("Build", value: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1")

                Link("View Source on GitHub", destination: URL(string: "https://github.com/orbitdock/orbitdock")!)
                    .font(.body)
            }

            Section("Reset") {
                Button("Reset All Settings to Default", role: .destructive) {
                    loginManager.isEnabled = false
                }
                .foregroundColor(.red)
                Text("This will remove all docks and restore the default single dock on launch.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding(8)
    }
}
