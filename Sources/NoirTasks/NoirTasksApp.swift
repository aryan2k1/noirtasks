import SwiftUI
import AppKit

@main
struct NoirTasksApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var store = Store.shared

    var body: some Scene {
        WindowGroup("NoirTasks") {
            ContentView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
                .frame(minWidth: 900, minHeight: 560)
                .background(Theme.bg)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Open Apple Calendar") {
                    CalendarBridge.openCalendar()
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])
            }
        }

        MenuBarExtra("NoirTasks", systemImage: "checklist") {
            MenuBarPanel()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        if Notifier.shared.enabled {
            Notifier.shared.requestAuth()
            Notifier.shared.reschedule()
        }
        // Restore any widgets that were open last session.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            WidgetManager.shared.restoreWidgets()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Keep running so desktop widgets and the menu-bar item stay alive.
        false
    }
}
