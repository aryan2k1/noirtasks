import AppKit
import EventKit
import SwiftUI

struct CalEvent: Identifiable {
    let id = UUID()
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    let colorHex: String
    var color: Color { Color(hex: colorHex) }

    var timeLabel: String {
        if isAllDay { return "All day" }
        return "\(start.formatted("HH:mm"))–\(end.formatted("HH:mm"))"
    }
}

/// Reads events from Apple Calendar (EventKit) for the next 7 days.
final class EventsProvider: ObservableObject {
    static let shared = EventsProvider()

    @Published var authorized: Bool = false
    @Published var eventsByDay: [Date: [CalEvent]] = [:]

    private let ekStore = EKEventStore()

    private init() {
        authorized = Self.currentlyAuthorized
        if authorized { refresh() }
        NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged, object: nil, queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }
    }

    private static var currentlyAuthorized: Bool {
        let s = EKEventStore.authorizationStatus(for: .event)
        if #available(macOS 14.0, *) {
            return s == .fullAccess
        }
        return s == .authorized
    }

    func connect() {
        if #available(macOS 14.0, *) {
            ekStore.requestFullAccessToEvents { [weak self] granted, _ in
                DispatchQueue.main.async {
                    self?.authorized = granted
                    self?.refresh()
                }
            }
        } else {
            ekStore.requestAccess(to: .event) { [weak self] granted, _ in
                DispatchQueue.main.async {
                    self?.authorized = granted
                    self?.refresh()
                }
            }
        }
    }

    func refresh() {
        guard Self.currentlyAuthorized else { return }
        authorized = true
        let cal = Calendar.current
        let start = Date().startOfDay
        guard let end = cal.date(byAdding: .day, value: 7, to: start) else { return }
        let pred = ekStore.predicateForEvents(withStart: start, end: end, calendars: nil)
        let found = ekStore.events(matching: pred)

        var grouped: [Date: [CalEvent]] = [:]
        for e in found {
            guard let s = e.startDate, let en = e.endDate else { continue }
            let day = max(s.startOfDay, start)
            let hex = hexString(e.calendar?.color) ?? "#7C6CF6"
            grouped[day, default: []].append(
                CalEvent(title: e.title ?? "Event", start: s, end: en, isAllDay: e.isAllDay, colorHex: hex)
            )
        }
        for k in grouped.keys {
            grouped[k]?.sort { $0.start < $1.start }
        }
        eventsByDay = grouped
    }

    func events(on day: Date) -> [CalEvent] {
        eventsByDay[day.startOfDay] ?? []
    }

    private func hexString(_ color: NSColor?) -> String? {
        guard let c = color?.usingColorSpace(.sRGB) else { return nil }
        return String(format: "#%02X%02X%02X",
                      Int(c.redComponent * 255), Int(c.greenComponent * 255), Int(c.blueComponent * 255))
    }
}
