#if canImport(XCTest)
import Foundation
import XCTest
@testable import MultiDock

final class DockManagerTests: XCTestCase {
    func testPinnedItemDisplayName() {
        let url = URL(fileURLWithPath: "/System/Applications/Calculator.app")
        let item = PinnedItem(url: url)
        XCTAssertEqual(item.displayName, "Calculator")

        let customItem = PinnedItem(url: url, customName: "My Calc")
        XCTAssertEqual(customItem.displayName, "My Calc")
    }

    func testEdgeOrientationRules() {
        var config = DockConfig(orientation: .horizontal, edge: .bottom)
        XCTAssertEqual(config.orientation, .horizontal)

        config.updateEdge(.left)
        XCTAssertEqual(config.orientation, .vertical)

        config.updateEdge(.right)
        XCTAssertEqual(config.orientation, .vertical)

        config.updateEdge(.top)
        XCTAssertEqual(config.orientation, .horizontal)

        config.updateEdge(.bottom)
        XCTAssertEqual(config.orientation, .horizontal)
    }

    func testDockConfigSerialization() throws {
        let item = PinnedItem(url: URL(fileURLWithPath: "/Applications/Safari.app"))
        let config = DockConfig(
            name: "Test Dock",
            orientation: .vertical,
            edge: .left,
            screenIndex: 1,
            iconSize: 64,
            spacing: 8,
            autoHide: true,
            backgroundStyle: .dark,
            items: [item]
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(config)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(DockConfig.self, from: data)

        XCTAssertEqual(decoded.id, config.id)
        XCTAssertEqual(decoded.name, "Test Dock")
        XCTAssertEqual(decoded.orientation, .vertical)
        XCTAssertEqual(decoded.edge, .left)
        XCTAssertEqual(decoded.screenIndex, 1)
        XCTAssertEqual(decoded.iconSize, 64)
        XCTAssertEqual(decoded.spacing, 8)
        XCTAssertEqual(decoded.autoHide, true)
        XCTAssertEqual(decoded.backgroundStyle, .dark)
        XCTAssertEqual(decoded.items.count, 1)
        XCTAssertEqual(decoded.items.first?.url, item.url)
    }

    @MainActor
    func testDockManagerOperations() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        let storageUrl = tempDir.appendingPathComponent("docks.json")

        let manager = DockManager(storageUrl: storageUrl)
        XCTAssertEqual(manager.docks.count, 1)

        let initialId = manager.docks[0].id
        let newItem = PinnedItem(url: URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"))
        manager.addItem(newItem, to: initialId)

        XCTAssertTrue(manager.docks[0].items.contains(where: { $0.url == newItem.url }))

        manager.addDock()
        XCTAssertEqual(manager.docks.count, 2)

        let secondDockId = manager.docks[1].id
        manager.removeDock(id: secondDockId)
        XCTAssertEqual(manager.docks.count, 1)

        try? FileManager.default.removeItem(at: tempDir)
    }

    func testSecurityUrlSchemeValidation() {
        // Safe URLs
        let safeWeb = PinnedItem(url: URL(string: "https://github.com/multidock")!)
        XCTAssertTrue(safeWeb.isSafeToLaunch)

        let safeFile = PinnedItem(url: URL(fileURLWithPath: "/System/Applications/Calculator.app"))
        XCTAssertTrue(safeFile.isSafeToLaunch)

        // Unsafe schemes must be blocked
        let unsafeJs = PinnedItem(url: URL(string: "javascript:alert(1)")!)
        XCTAssertFalse(unsafeJs.isSafeToLaunch)

        let unsafeAppleScript = PinnedItem(url: URL(string: "applescript:do_shell_script")!)
        XCTAssertFalse(unsafeAppleScript.isSafeToLaunch)

        let unsafeData = PinnedItem(url: URL(string: "data:text/html;base64,PHNjcmlwdD4=")!)
        XCTAssertFalse(unsafeData.isSafeToLaunch)

        // Non-existent file path must be blocked
        let missingFile = PinnedItem(url: URL(fileURLWithPath: "/non/existent/malicious/app.sh"))
        XCTAssertFalse(missingFile.isSafeToLaunch)
    }

    func testSecurityCustomIconValidation() {
        // Non-existent or invalid extensions must be rejected
        XCTAssertFalse(PinnedItem.isValidIconPath("/tmp/malicious.sh"))
        XCTAssertFalse(PinnedItem.isValidIconPath("/tmp/malicious.exe"))
        XCTAssertFalse(PinnedItem.isValidIconPath(nil))
        XCTAssertFalse(PinnedItem.isValidIconPath(""))
    }

    func testSecurityDockConfigBoundsClamping() throws {
        let json = """
        {
            "id": "\(UUID().uuidString)",
            "name": "Extreme Values Dock",
            "orientation": "horizontal",
            "edge": "bottom",
            "screenIndex": 999,
            "iconSize": 50000.0,
            "spacing": -50.0,
            "backgroundStyle": "glass",
            "customColorOpacity": 9.99,
            "magnificationScale": 100.0,
            "cornerRadius": 500.0,
            "paddingH": 200.0,
            "paddingV": 200.0,
            "items": []
        }
        """.data(using: .utf8)!

        let decoded = try JSONDecoder().decode(DockConfig.self, from: json)
        XCTAssertLessThanOrEqual(decoded.screenIndex, 32)
        XCTAssertLessThanOrEqual(decoded.iconSize, 256.0)
        XCTAssertGreaterThanOrEqual(decoded.spacing, 0.0)
        XCTAssertLessThanOrEqual(decoded.customColorOpacity, 1.0)
        XCTAssertLessThanOrEqual(decoded.magnificationScale, 3.0)
        XCTAssertLessThanOrEqual(decoded.cornerRadius, 64.0)
        XCTAssertLessThanOrEqual(decoded.paddingH, 64.0)
        XCTAssertLessThanOrEqual(decoded.paddingV, 64.0)
    }
}
#endif

