import AppKit
import Foundation

enum CalendarBridge {

    /// Opens the Apple Calendar app.
    static func openCalendar() {
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.iCal") {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    /// Exports a task as an all-day .ics event and hands it to Apple Calendar,
    /// which shows its native "Add Event" dialog.
    static func addToCalendar(title: String, notes: String, dueDate: Date?) {
        let day = dueDate ?? Date()
        let cal = Calendar.current
        let nextDay = cal.date(byAdding: .day, value: 1, to: day.startOfDay) ?? day

        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd"
        let stamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: ":", with: "")

        let escapedTitle = title.replacingOccurrences(of: ",", with: "\\,")
        let desc = notes.isEmpty ? "Added from NoirTasks" : notes.replacingOccurrences(of: "\n", with: "\\n")

        let ics = """
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:-//NoirTasks//EN
        BEGIN:VEVENT
        UID:\(UUID().uuidString)@noirtasks
        DTSTAMP:\(stamp)
        DTSTART;VALUE=DATE:\(f.string(from: day))
        DTEND;VALUE=DATE:\(f.string(from: nextDay))
        SUMMARY:\(escapedTitle)
        DESCRIPTION:\(desc)
        END:VEVENT
        END:VCALENDAR
        """

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("NoirTasks-\(UUID().uuidString.prefix(8)).ics")
        do {
            try ics.data(using: .utf8)?.write(to: url)
            NSWorkspace.shared.open(url)
        } catch {
            NSSound.beep()
        }
    }

    /// Jumps Apple Calendar to a specific day (day view) via AppleScript.
    /// macOS will ask once for permission to control Calendar.
    static func showInCalendar(date: Date) {
        let c = Calendar.current.dateComponents([.year, .month, .day], from: date)
        guard let y = c.year, let m = c.month, let d = c.day else { return }
        let src = """
        tell application "Calendar"
            activate
            set targetDate to current date
            set year of targetDate to \(y)
            set month of targetDate to \(m)
            set day of targetDate to \(d)
            switch view to day view
            view calendar at targetDate
        end tell
        """
        DispatchQueue.main.async {
            var err: NSDictionary?
            NSAppleScript(source: src)?.executeAndReturnError(&err)
            if err != nil {
                // Fall back to just opening Calendar if automation permission was denied.
                openCalendar()
            }
        }
    }
}
