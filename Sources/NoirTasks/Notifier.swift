import Foundation
import UserNotifications

/// Schedules a macOS notification for each incomplete task on the morning of its due date.
final class Notifier: ObservableObject {
    static let shared = Notifier()

    @Published var enabled: Bool {
        didSet {
            UserDefaults.standard.set(enabled, forKey: "notifyEnabled")
            if enabled {
                requestAuth()
                reschedule()
            } else {
                clear()
            }
        }
    }

    /// Hour of the day (24h) notifications fire on the due date.
    @Published var hour: Int {
        didSet {
            UserDefaults.standard.set(hour, forKey: "notifyHour")
            reschedule()
        }
    }

    // Notifications need a real app bundle; guard against running as a bare binary.
    private var available: Bool { Bundle.main.bundleIdentifier != nil }

    private init() {
        enabled = UserDefaults.standard.bool(forKey: "notifyEnabled")
        let h = UserDefaults.standard.integer(forKey: "notifyHour")
        hour = h == 0 ? 9 : h
    }

    func requestAuth() {
        guard available else { return }
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func clear() {
        guard available else { return }
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    func reschedule() {
        guard available, enabled else { return }
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let today = Date().startOfDay
        var count = 0
        for ref in Store.shared.allRefs where !ref.item.isDone {
            guard let due = ref.item.dueDate, due.startOfDay >= today else { continue }
            if count >= 60 { break }

            var comps = Calendar.current.dateComponents([.year, .month, .day], from: due)
            comps.hour = hour
            comps.minute = 0

            let content = UNMutableNotificationContent()
            content.title = ref.item.title
            content.body = "Due today · \(ref.listName)"
            content.sound = .default

            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            center.add(UNNotificationRequest(
                identifier: ref.item.id.uuidString, content: content, trigger: trigger
            ))
            count += 1
        }
    }
}
