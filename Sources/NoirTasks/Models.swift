import Foundation
import SwiftUI

// MARK: - Supporting types

enum Priority: Int, Codable, CaseIterable, Comparable {
    case none = 0, low, medium, high

    static func < (a: Priority, b: Priority) -> Bool { a.rawValue < b.rawValue }

    var label: String {
        switch self {
        case .none: return "None"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }

    var color: Color {
        switch self {
        case .none: return Theme.textDim
        case .low: return Color(hex: "#4FC3F7")
        case .medium: return Color(hex: "#FFB74D")
        case .high: return Theme.danger
        }
    }
}

enum Recurrence: String, Codable, CaseIterable {
    case none, daily, weekdays, weekly, monthly

    var label: String {
        switch self {
        case .none: return "Never"
        case .daily: return "Every day"
        case .weekdays: return "Weekdays"
        case .weekly: return "Every week"
        case .monthly: return "Every month"
        }
    }

    func next(after date: Date) -> Date? {
        let cal = Calendar.current
        switch self {
        case .none:
            return nil
        case .daily:
            return cal.date(byAdding: .day, value: 1, to: date)
        case .weekdays:
            var d = date
            repeat {
                guard let n = cal.date(byAdding: .day, value: 1, to: d) else { return nil }
                d = n
            } while cal.isDateInWeekend(d)
            return d
        case .weekly:
            return cal.date(byAdding: .day, value: 7, to: date)
        case .monthly:
            return cal.date(byAdding: .month, value: 1, to: date)
        }
    }
}

struct Subtask: Identifiable, Codable, Equatable, Hashable {
    var id = UUID()
    var title: String
    var isDone: Bool = false
}

// MARK: - Core models

struct TodoItem: Identifiable, Equatable, Hashable {
    var id = UUID()
    var title: String
    var notes: String = ""
    var isDone: Bool = false
    var dueDate: Date? = nil
    var createdAt: Date = Date()
    var priority: Priority = .none
    var tags: [String] = []
    var subtasks: [Subtask] = []
    var recurrence: Recurrence = .none
    var blockStart: Date? = nil
    var blockMinutes: Int? = nil
    var completedAt: Date? = nil

    var subtaskProgress: Double? {
        guard !subtasks.isEmpty else { return nil }
        return Double(subtasks.filter(\.isDone).count) / Double(subtasks.count)
    }
}

extension TodoItem: Codable {
    enum CodingKeys: String, CodingKey {
        case id, title, notes, isDone, dueDate, createdAt, priority, tags,
             subtasks, recurrence, blockStart, blockMinutes, completedAt
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? ""
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        isDone = try c.decodeIfPresent(Bool.self, forKey: .isDone) ?? false
        dueDate = try c.decodeIfPresent(Date.self, forKey: .dueDate)
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        priority = try c.decodeIfPresent(Priority.self, forKey: .priority) ?? Priority.none
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        subtasks = try c.decodeIfPresent([Subtask].self, forKey: .subtasks) ?? []
        recurrence = try c.decodeIfPresent(Recurrence.self, forKey: .recurrence) ?? Recurrence.none
        blockStart = try c.decodeIfPresent(Date.self, forKey: .blockStart)
        blockMinutes = try c.decodeIfPresent(Int.self, forKey: .blockMinutes)
        completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(notes, forKey: .notes)
        try c.encode(isDone, forKey: .isDone)
        try c.encodeIfPresent(dueDate, forKey: .dueDate)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(priority, forKey: .priority)
        try c.encode(tags, forKey: .tags)
        try c.encode(subtasks, forKey: .subtasks)
        try c.encode(recurrence, forKey: .recurrence)
        try c.encodeIfPresent(blockStart, forKey: .blockStart)
        try c.encodeIfPresent(blockMinutes, forKey: .blockMinutes)
        try c.encodeIfPresent(completedAt, forKey: .completedAt)
    }
}

struct TodoList: Identifiable, Codable, Equatable, Hashable {
    var id = UUID()
    var name: String
    var colorHex: String = Palette.defaultHex
    var items: [TodoItem] = []

    var color: Color { Color(hex: colorHex) }
    var remaining: Int { items.filter { !$0.isDone }.count }
}

struct TaskRef: Identifiable {
    let listID: UUID
    let listName: String
    let colorHex: String
    let item: TodoItem
    var id: UUID { item.id }
    var color: Color { Color(hex: colorHex) }
}

/// On-disk envelope (v2). v1 was a bare `[TodoList]` array.
private struct AppData: Codable {
    var lists: [TodoList] = []
    var completionLog: [Date] = []
}

// MARK: - Store

final class Store: ObservableObject {
    static let shared = Store()

    @Published var lists: [TodoList] = [] {
        didSet { scheduleSave() }
    }
    @Published var completionLog: [Date] = [] {
        didSet { scheduleSave() }
    }

    private var saveWork: DispatchWorkItem?
    private let fileURL: URL

    private init() {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("NoirTasks", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent("data.json")
        load()
    }

    // MARK: - Persistence

    private func load() {
        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .iso8601
        if let data = try? Data(contentsOf: fileURL) {
            if let decoded = try? dec.decode(AppData.self, from: data) {
                lists = decoded.lists
                completionLog = decoded.completionLog
                return
            }
            if let legacy = try? dec.decode([TodoList].self, from: data) {
                lists = legacy
                return
            }
        }
        lists = Store.sampleLists()
    }

    private func scheduleSave() {
        saveWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.save() }
        saveWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
    }

    private func save() {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .iso8601
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? enc.encode(AppData(lists: lists, completionLog: completionLog)) {
            try? data.write(to: fileURL, options: .atomic)
        }
        Notifier.shared.reschedule()
    }

    // MARK: - Queries

    func list(with id: UUID) -> TodoList? {
        lists.first { $0.id == id }
    }

    var allRefs: [TaskRef] {
        lists.flatMap { list in
            list.items.map { TaskRef(listID: list.id, listName: list.name, colorHex: list.colorHex, item: $0) }
        }
    }

    private func sortRefs(_ refs: [TaskRef]) -> [TaskRef] {
        refs.sorted {
            if $0.item.isDone != $1.item.isDone { return !$0.item.isDone }
            if $0.item.priority != $1.item.priority { return $0.item.priority > $1.item.priority }
            return $0.item.createdAt < $1.item.createdAt
        }
    }

    func refs(dueOn day: Date) -> [TaskRef] {
        sortRefs(allRefs.filter { $0.item.dueDate?.isSameDay(as: day) == true })
    }

    /// Week-view ordering: time-blocked tasks first (by start time), then priority.
    func weekRefs(on day: Date) -> [TaskRef] {
        refs(dueOn: day).sorted {
            if $0.item.isDone != $1.item.isDone { return !$0.item.isDone }
            switch ($0.item.blockStart, $1.item.blockStart) {
            case let (a?, b?): return a < b
            case (.some, Optional.none): return true
            case (Optional.none, .some): return false
            default:
                if $0.item.priority != $1.item.priority { return $0.item.priority > $1.item.priority }
                return $0.item.createdAt < $1.item.createdAt
            }
        }
    }

    var overdueRefs: [TaskRef] {
        let today = Date().startOfDay
        return sortRefs(allRefs.filter {
            guard let due = $0.item.dueDate, !$0.item.isDone else { return false }
            return due.startOfDay < today
        })
    }

    var noDateRefs: [TaskRef] {
        sortRefs(allRefs.filter { $0.item.dueDate == nil && !$0.item.isDone })
    }

    var allTags: [String] {
        Array(Set(allRefs.flatMap { $0.item.tags })).sorted()
    }

    func refs(tagged tag: String) -> [TaskRef] {
        sortRefs(allRefs.filter { $0.item.tags.contains(tag) })
    }

    // MARK: - Stats

    func completions(on day: Date) -> Int {
        completionLog.filter { $0.isSameDay(as: day) }.count
    }

    var doneToday: Int { completions(on: Date()) }

    var doneThisWeek: Int {
        let cal = Calendar.current
        guard let weekAgo = cal.date(byAdding: .day, value: -6, to: Date().startOfDay) else { return 0 }
        return completionLog.filter { $0 >= weekAgo }.count
    }

    /// Consecutive days (ending today or yesterday) with at least one completion.
    var streak: Int {
        let cal = Calendar.current
        let days = Set(completionLog.map { $0.startOfDay })
        var day = Date().startOfDay
        if !days.contains(day) {
            guard let y = cal.date(byAdding: .day, value: -1, to: day) else { return 0 }
            day = y
        }
        var count = 0
        while days.contains(day) {
            count += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: day) else { break }
            day = prev
        }
        return count
    }

    // MARK: - Mutations

    private func withItem(_ itemID: UUID, in listID: UUID, _ mutate: (inout TodoItem) -> Void) {
        guard let li = lists.firstIndex(where: { $0.id == listID }),
              let ti = lists[li].items.firstIndex(where: { $0.id == itemID }) else { return }
        mutate(&lists[li].items[ti])
    }

    func addList(name: String, colorHex: String) {
        lists.append(TodoList(name: name, colorHex: colorHex))
    }

    func deleteList(_ id: UUID) {
        lists.removeAll { $0.id == id }
        WidgetManager.shared.close(.list(id))
    }

    /// Words starting with # become tags, e.g. "Revise IS-LM #ECON3008".
    static func parseTags(from raw: String) -> (title: String, tags: [String]) {
        var tags: [String] = []
        var words: [String] = []
        for w in raw.split(separator: " ") {
            if w.hasPrefix("#"), w.count > 1 {
                tags.append(String(w.dropFirst()).lowercased())
            } else {
                words.append(String(w))
            }
        }
        return (words.joined(separator: " "), tags)
    }

    func addItem(to listID: UUID, title raw: String, due: Date?,
                 priority: Priority = .none, recurrence: Recurrence = .none) {
        let (title, tags) = Store.parseTags(from: raw.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !title.isEmpty, let idx = lists.firstIndex(where: { $0.id == listID }) else { return }
        lists[idx].items.append(
            TodoItem(title: title, dueDate: due, priority: priority, tags: tags, recurrence: recurrence)
        )
    }

    func toggleItem(_ itemID: UUID, in listID: UUID) {
        var completed = false
        withItem(itemID, in: listID) { item in
            if item.isDone {
                item.isDone = false
                item.completedAt = nil
            } else {
                completed = true
                item.completedAt = Date()
                if item.recurrence != .none {
                    // Recurring: log the completion and roll forward instead of finishing.
                    let base = max(item.dueDate ?? Date().startOfDay, Date().startOfDay)
                    item.dueDate = item.recurrence.next(after: base)
                    item.subtasks = item.subtasks.map { var s = $0; s.isDone = false; return s }
                } else {
                    item.isDone = true
                }
            }
        }
        if completed { completionLog.append(Date()) }
    }

    func deleteItem(_ itemID: UUID, in listID: UUID) {
        guard let li = lists.firstIndex(where: { $0.id == listID }) else { return }
        lists[li].items.removeAll { $0.id == itemID }
    }

    func clearCompleted(in listID: UUID) {
        guard let li = lists.firstIndex(where: { $0.id == listID }) else { return }
        lists[li].items.removeAll { $0.isDone }
    }

    func setPriority(_ p: Priority, for itemID: UUID, in listID: UUID) {
        withItem(itemID, in: listID) { $0.priority = p }
    }

    func setRecurrence(_ r: Recurrence, for itemID: UUID, in listID: UUID) {
        withItem(itemID, in: listID) { $0.recurrence = r }
    }

    func setBlock(_ itemID: UUID, in listID: UUID, start: Date?, minutes: Int?) {
        withItem(itemID, in: listID) {
            $0.blockStart = start
            $0.blockMinutes = minutes
        }
    }

    func addSubtask(_ title: String, to itemID: UUID, in listID: UUID) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        withItem(itemID, in: listID) { $0.subtasks.append(Subtask(title: trimmed)) }
    }

    func toggleSubtask(_ subID: UUID, of itemID: UUID, in listID: UUID) {
        withItem(itemID, in: listID) { item in
            if let si = item.subtasks.firstIndex(where: { $0.id == subID }) {
                item.subtasks[si].isDone.toggle()
            }
        }
    }

    func deleteSubtask(_ subID: UUID, of itemID: UUID, in listID: UUID) {
        withItem(itemID, in: listID) { $0.subtasks.removeAll { $0.id == subID } }
    }

    // MARK: - Sample data

    private static func sampleLists() -> [TodoList] {
        let today = Date().startOfDay
        let cal = Calendar.current
        var uni = TodoList(name: "University", colorHex: "#7C6CF6")
        uni.items = [
            TodoItem(title: "Review lecture notes", dueDate: today, priority: .medium, tags: ["revision"]),
            TodoItem(title: "Problem set questions", dueDate: cal.date(byAdding: .day, value: 2, to: today), priority: .high),
            TodoItem(title: "Dissertation reading", dueDate: cal.date(byAdding: .day, value: 4, to: today), tags: ["dissertation"],
                     subtasks: [Subtask(title: "Find 3 papers"), Subtask(title: "Skim abstracts"), Subtask(title: "Notes on best one")])
        ]
        var personal = TodoList(name: "Personal", colorHex: "#4FC3F7")
        personal.items = [
            TodoItem(title: "Gym session", dueDate: today, recurrence: .weekdays),
            TodoItem(title: "Call home")
        ]
        var errands = TodoList(name: "Errands", colorHex: "#FFB74D")
        errands.items = [
            TodoItem(title: "Food shop", dueDate: cal.date(byAdding: .day, value: 1, to: today))
        ]
        return [uni, personal, errands]
    }
}
