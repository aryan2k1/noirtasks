import AppKit
import SwiftUI

/// What a desktop widget shows: one list, or everything due today.
enum WidgetKind: Hashable {
    case list(UUID)
    case today

    var key: String {
        switch self {
        case .list(let id): return "list-\(id.uuidString)"
        case .today: return "today"
        }
    }

    static func from(key: String) -> WidgetKind? {
        if key == "today" { return .today }
        if key.hasPrefix("list-"), let id = UUID(uuidString: String(key.dropFirst(5))) {
            return .list(id)
        }
        return nil
    }
}

/// A borderless, non-activating panel that can still take keyboard focus
/// (so the widget's quick-add field works).
final class WidgetPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

/// Manages floating desktop widgets.
final class WidgetManager: ObservableObject {
    static let shared = WidgetManager()

    @Published private(set) var openKinds: Set<WidgetKind> = []
    @Published private(set) var pinnedKeys: Set<String> = []

    private var panels: [WidgetKind: WidgetPanel] = [:]
    private let openKey = "openWidgetKeys"
    private let pinnedKey = "pinnedWidgetKeys"

    private init() {
        pinnedKeys = Set(UserDefaults.standard.stringArray(forKey: pinnedKey) ?? [])
    }

    func isOpen(_ kind: WidgetKind) -> Bool { openKinds.contains(kind) }
    func isPinned(_ kind: WidgetKind) -> Bool { pinnedKeys.contains(kind.key) }

    func toggle(_ kind: WidgetKind) {
        isOpen(kind) ? close(kind) : open(kind)
    }

    func open(_ kind: WidgetKind) {
        guard panels[kind] == nil else { return }
        if case .list(let id) = kind, Store.shared.list(with: id) == nil { return }

        let panel = WidgetPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 380),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.becomesKeyOnlyIfNeeded = true
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false

        let root = WidgetView(kind: kind)
            .environmentObject(Store.shared)
            .environmentObject(self)
        panel.contentView = NSHostingView(rootView: root)

        panel.setFrameAutosaveName("noir-widget-\(kind.key)")
        if panel.frame.origin == .zero, let screen = NSScreen.main {
            let x = screen.visibleFrame.maxX - 320
            let y = screen.visibleFrame.maxY - 420 - CGFloat(panels.count) * 40
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        applyLevel(panel, pinned: isPinned(kind))
        panel.orderFrontRegardless()

        panels[kind] = panel
        openKinds.insert(kind)
        persistOpen()
    }

    func close(_ kind: WidgetKind) {
        panels[kind]?.close()
        panels[kind] = nil
        openKinds.remove(kind)
        persistOpen()
    }

    /// Pinned = glued to the desktop (sits with desktop icons, under app windows).
    /// Unpinned = floats above other windows.
    func togglePin(_ kind: WidgetKind) {
        if pinnedKeys.contains(kind.key) {
            pinnedKeys.remove(kind.key)
        } else {
            pinnedKeys.insert(kind.key)
        }
        UserDefaults.standard.set(Array(pinnedKeys), forKey: pinnedKey)
        if let panel = panels[kind] {
            applyLevel(panel, pinned: isPinned(kind))
            panel.orderFrontRegardless()
        }
    }

    func restoreWidgets() {
        let saved = UserDefaults.standard.stringArray(forKey: openKey) ?? []
        for kind in saved.compactMap(WidgetKind.from(key:)) {
            open(kind)
        }
    }

    /// Brings the main app window forward from a widget.
    func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first { !($0 is WidgetPanel) && $0.canBecomeMain }?.makeKeyAndOrderFront(nil)
    }

    private func applyLevel(_ panel: NSPanel, pinned: Bool) {
        if pinned {
            panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.desktopIconWindow)))
        } else {
            panel.level = .floating
        }
    }

    private func persistOpen() {
        UserDefaults.standard.set(openKinds.map(\.key), forKey: openKey)
    }
}
