import SwiftUI

// MARK: - Task row

struct TaskRow: View {
    @EnvironmentObject var store: Store
    let taskRef: TaskRef
    var showListBadge = false

    @State private var hovering = false
    @State private var expanded = false
    @State private var subtaskText = ""

    private var item: TodoItem { taskRef.item }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            mainRow
            if expanded {
                subtaskSection
            }
        }
        .background(RoundedRectangle(cornerRadius: 10).fill(hovering ? Theme.cardHover : Theme.card))
        .onHover { hovering = $0 }
        .contextMenu { menu }
    }

    private var mainRow: some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    store.toggleItem(item.id, in: taskRef.listID)
                }
            } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(item.isDone ? Theme.textDim : taskRef.color)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    if item.priority != .none {
                        Image(systemName: "flag.fill")
                            .font(.caption)
                            .foregroundColor(item.priority.color)
                    }
                    Text(item.title)
                        .foregroundColor(item.isDone ? Theme.textDim : Theme.text)
                        .strikethrough(item.isDone, color: Theme.textDim)
                    if item.recurrence != .none {
                        Image(systemName: "repeat")
                            .font(.caption)
                            .foregroundColor(Theme.accent)
                            .help(item.recurrence.label)
                    }
                }
                HStack(spacing: 8) {
                    if let due = item.dueDate {
                        Label(dueLabel(due), systemImage: "calendar")
                            .font(.caption)
                            .foregroundColor(isOverdue(due) ? Theme.danger : Theme.textDim)
                    }
                    if showListBadge {
                        HStack(spacing: 4) {
                            Circle().fill(taskRef.color).frame(width: 6, height: 6)
                            Text(taskRef.listName)
                        }
                        .font(.caption)
                        .foregroundColor(Theme.textDim)
                    }
                    ForEach(item.tags, id: \.self) { tag in
                        Text("#\(tag)")
                            .font(.caption)
                            .foregroundColor(Theme.accent)
                    }
                    if !item.subtasks.isEmpty {
                        Text("\(item.subtasks.filter(\.isDone).count)/\(item.subtasks.count)")
                            .font(.caption)
                            .foregroundColor(Theme.textDim)
                    }
                }
                if let progress = item.subtaskProgress {
                    ProgressView(value: progress)
                        .tint(taskRef.color)
                        .frame(maxWidth: 160)
                }
            }

            Spacer()

            if hovering {
                HStack(spacing: 10) {
                    Button {
                        CalendarBridge.addToCalendar(title: item.title, notes: item.notes, dueDate: item.dueDate)
                    } label: {
                        Image(systemName: "calendar.badge.plus")
                            .foregroundColor(Theme.accent)
                    }
                    .buttonStyle(.plain)
                    .help("Add to Apple Calendar")

                    if let due = item.dueDate {
                        Button {
                            CalendarBridge.showInCalendar(date: due)
                        } label: {
                            Image(systemName: "arrow.up.forward.app")
                                .foregroundColor(Theme.textDim)
                        }
                        .buttonStyle(.plain)
                        .help("Show this day in Apple Calendar")
                    }

                    Button {
                        store.deleteItem(item.id, in: taskRef.listID)
                    } label: {
                        Image(systemName: "trash")
                            .foregroundColor(Theme.danger.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .help("Delete task")
                }
            }

            if hovering || !item.subtasks.isEmpty {
                Button {
                    withAnimation(.easeOut(duration: 0.15)) { expanded.toggle() }
                } label: {
                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundColor(Theme.textDim)
                }
                .buttonStyle(.plain)
                .help("Subtasks")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private var subtaskSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(item.subtasks) { sub in
                HStack(spacing: 8) {
                    Button {
                        store.toggleSubtask(sub.id, of: item.id, in: taskRef.listID)
                    } label: {
                        Image(systemName: sub.isDone ? "checkmark.circle.fill" : "circle")
                            .font(.callout)
                            .foregroundColor(sub.isDone ? Theme.textDim : taskRef.color.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    Text(sub.title)
                        .font(.callout)
                        .foregroundColor(sub.isDone ? Theme.textDim : Theme.text)
                        .strikethrough(sub.isDone, color: Theme.textDim)
                    Spacer()
                    Button {
                        store.deleteSubtask(sub.id, of: item.id, in: taskRef.listID)
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption2)
                            .foregroundColor(Theme.textDim)
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.caption)
                    .foregroundColor(Theme.textDim)
                TextField("Add a step…", text: $subtaskText)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .onSubmit {
                        store.addSubtask(subtaskText, to: item.id, in: taskRef.listID)
                        subtaskText = ""
                    }
            }
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var menu: some View {
        Menu("Priority") {
            ForEach(Priority.allCases, id: \.self) { p in
                Button {
                    store.setPriority(p, for: item.id, in: taskRef.listID)
                } label: {
                    if item.priority == p {
                        Label(p.label, systemImage: "checkmark")
                    } else {
                        Text(p.label)
                    }
                }
            }
        }
        Menu("Repeat") {
            ForEach(Recurrence.allCases, id: \.self) { r in
                Button {
                    store.setRecurrence(r, for: item.id, in: taskRef.listID)
                } label: {
                    if item.recurrence == r {
                        Label(r.label, systemImage: "checkmark")
                    } else {
                        Text(r.label)
                    }
                }
            }
        }
        Button("Add Subtask") { expanded = true }
        Divider()
        Button("Add to Apple Calendar") {
            CalendarBridge.addToCalendar(title: item.title, notes: item.notes, dueDate: item.dueDate)
        }
        Divider()
        Button("Delete", role: .destructive) {
            store.deleteItem(item.id, in: taskRef.listID)
        }
    }

    private func isOverdue(_ due: Date) -> Bool {
        !item.isDone && due.startOfDay < Date().startOfDay
    }

    private func dueLabel(_ date: Date) -> String {
        if date.isSameDay(as: Date()) { return "Today" }
        if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()),
           date.isSameDay(as: tomorrow) { return "Tomorrow" }
        return date.formatted("EEE d MMM")
    }
}

// MARK: - Quick add bar

struct QuickAddBar: View {
    @EnvironmentObject var store: Store

    var fixedListID: UUID? = nil
    var defaultDue: Date? = nil
    var showsDatePicker = true

    @State private var text = ""
    @State private var hasDue: Bool
    @State private var due: Date
    @State private var selectedList: UUID? = nil
    @State private var priority: Priority = .none
    @State private var recurrence: Recurrence = .none

    init(fixedListID: UUID? = nil, defaultDue: Date? = nil, showsDatePicker: Bool = true) {
        self.fixedListID = fixedListID
        self.defaultDue = defaultDue
        self.showsDatePicker = showsDatePicker
        _hasDue = State(initialValue: defaultDue != nil)
        _due = State(initialValue: defaultDue ?? Date())
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "plus.circle.fill")
                .foregroundColor(Theme.accent)
            TextField("Add a task…  (#tag for tags)", text: $text)
                .textFieldStyle(.plain)
                .foregroundColor(Theme.text)
                .onSubmit(submit)

            if fixedListID == nil && !store.lists.isEmpty {
                Menu {
                    ForEach(store.lists) { list in
                        Button(list.name) { selectedList = list.id }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Circle().fill(currentListColor).frame(width: 8, height: 8)
                        Text(currentListName)
                            .font(.caption)
                    }
                    .foregroundColor(Theme.textDim)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }

            Menu {
                ForEach(Priority.allCases, id: \.self) { p in
                    Button(p.label) { priority = p }
                }
            } label: {
                Image(systemName: priority == .none ? "flag" : "flag.fill")
                    .foregroundColor(priority == .none ? Theme.textDim : priority.color)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Priority")

            Menu {
                ForEach(Recurrence.allCases, id: \.self) { r in
                    Button(r.label) { recurrence = r }
                }
            } label: {
                Image(systemName: "repeat")
                    .foregroundColor(recurrence == .none ? Theme.textDim : Theme.accent)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Repeat")

            if showsDatePicker {
                Toggle(isOn: $hasDue) {
                    Image(systemName: "calendar")
                }
                .toggleStyle(.button)
                .help("Set a due date")
                if hasDue {
                    DatePicker("", selection: $due, displayedComponents: .date)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                }
            }

            Button(action: submit) {
                Text("Add")
                    .font(.callout.bold())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Theme.accent))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.panel))
    }

    private var resolvedListID: UUID? {
        fixedListID ?? selectedList ?? store.lists.first?.id
    }

    private var currentListName: String {
        guard let id = resolvedListID, let list = store.list(with: id) else { return "List" }
        return list.name
    }

    private var currentListColor: Color {
        guard let id = resolvedListID, let list = store.list(with: id) else { return Theme.accent }
        return list.color
    }

    private func submit() {
        guard let listID = resolvedListID else { return }
        store.addItem(to: listID, title: text, due: hasDue ? due : nil,
                      priority: priority, recurrence: recurrence)
        text = ""
        priority = .none
        recurrence = .none
    }
}

// MARK: - Time block editor (weekly view)

struct TimeBlockEditor: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    let taskRef: TaskRef
    let day: Date

    @State private var start: Date
    @State private var minutes: Int

    init(taskRef: TaskRef, day: Date) {
        self.taskRef = taskRef
        self.day = day
        let nine = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: day) ?? day
        _start = State(initialValue: taskRef.item.blockStart ?? nine)
        _minutes = State(initialValue: taskRef.item.blockMinutes ?? 60)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Time slot")
                .font(.headline)
            DatePicker("Start", selection: $start, displayedComponents: .hourAndMinute)
            Stepper("\(minutes) min", value: $minutes, in: 15...240, step: 15)
            HStack {
                Button("Clear") {
                    store.setBlock(taskRef.item.id, in: taskRef.listID, start: nil, minutes: nil)
                    dismiss()
                }
                Spacer()
                Button("Save") {
                    let cal = Calendar.current
                    let c = cal.dateComponents([.hour, .minute], from: start)
                    let onDay = cal.date(bySettingHour: c.hour ?? 9, minute: c.minute ?? 0, second: 0, of: day)
                    store.setBlock(taskRef.item.id, in: taskRef.listID, start: onDay, minutes: minutes)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 240)
    }
}

// MARK: - Calendar event row

struct EventRow: View {
    let event: CalEvent

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 2)
                .fill(event.color)
                .frame(width: 4, height: 30)
            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .foregroundColor(Theme.text)
                    .lineLimit(1)
                Text(event.timeLabel)
                    .font(.caption)
                    .foregroundColor(Theme.textDim)
            }
            Spacer()
            Image(systemName: "calendar")
                .foregroundColor(Theme.textDim)
                .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 10).fill(Theme.card.opacity(0.6)))
    }
}

// MARK: - New list sheet

struct NewListSheet: View {
    @EnvironmentObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var colorHex = Palette.defaultHex

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("New List")
                .font(.title2.bold())
                .foregroundColor(Theme.text)

            TextField("List name", text: $name)
                .textFieldStyle(.roundedBorder)

            HStack(spacing: 10) {
                ForEach(Palette.hexes, id: \.self) { hex in
                    Button {
                        colorHex = hex
                    } label: {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 22, height: 22)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: colorHex == hex ? 2 : 0)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Create") {
                    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    store.addList(name: trimmed, colorHex: colorHex)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 340)
        .background(Theme.panel)
    }
}

// MARK: - Section header

struct SectionHeader: View {
    let title: String
    var count: Int? = nil

    var body: some View {
        HStack(spacing: 6) {
            Text(title.uppercased())
                .font(.caption.bold())
                .foregroundColor(Theme.textDim)
            if let count {
                Text("\(count)")
                    .font(.caption2.bold())
                    .foregroundColor(Theme.textDim)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Theme.card))
            }
            Spacer()
        }
        .padding(.top, 8)
    }
}

// MARK: - Menu bar quick add

struct MenuBarPanel: View {
    @EnvironmentObject var store: Store

    @State private var text = ""
    @State private var dueToday = true
    @State private var selectedList: UUID? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Add")
                .font(.headline)
            TextField("Task…  (#tag for tags)", text: $text)
                .textFieldStyle(.roundedBorder)
                .onSubmit(submit)
            HStack {
                Menu {
                    ForEach(store.lists) { list in
                        Button(list.name) { selectedList = list.id }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Circle().fill(listColor).frame(width: 8, height: 8)
                        Text(listName)
                    }
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                Toggle("Due today", isOn: $dueToday)
                    .toggleStyle(.checkbox)
                Spacer()
                Button("Add", action: submit)
                    .keyboardShortcut(.defaultAction)
            }
            Divider()
            HStack {
                let due = store.overdueRefs.count
                    + store.refs(dueOn: Date()).filter { !$0.item.isDone }.count
                Text("\(due) due today")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button("Open NoirTasks") {
                    WidgetManager.shared.showMainWindow()
                }
            }
        }
        .padding(14)
        .frame(width: 320)
    }

    private var resolvedListID: UUID? { selectedList ?? store.lists.first?.id }

    private var listName: String {
        guard let id = resolvedListID, let list = store.list(with: id) else { return "List" }
        return list.name
    }

    private var listColor: Color {
        guard let id = resolvedListID, let list = store.list(with: id) else { return Theme.accent }
        return list.color
    }

    private func submit() {
        guard let listID = resolvedListID else { return }
        store.addItem(to: listID, title: text, due: dueToday ? Date() : nil)
        text = ""
    }
}
