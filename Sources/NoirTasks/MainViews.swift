import SwiftUI

enum SidebarSelection: Hashable {
    case today
    case week
    case stats
    case list(UUID)
    case tag(String)
}

// MARK: - Content view

struct ContentView: View {
    @EnvironmentObject var store: Store
    @ObservedObject var widgets = WidgetManager.shared
    @State private var selection: SidebarSelection? = .today
    @State private var showingNewList = false

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.bg)
        }
        .sheet(isPresented: $showingNewList) {
            NewListSheet()
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    CalendarBridge.openCalendar()
                } label: {
                    Label("Apple Calendar", systemImage: "calendar")
                }
                .help("Open Apple Calendar")
            }
        }
    }

    private var sidebar: some View {
        List(selection: $selection) {
            Section("Views") {
                Label("Today", systemImage: "sun.max.fill")
                    .tag(SidebarSelection.today)
                Label("This Week", systemImage: "calendar.day.timeline.left")
                    .tag(SidebarSelection.week)
                Label("Stats", systemImage: "chart.bar.fill")
                    .tag(SidebarSelection.stats)
            }
            Section("My Lists") {
                ForEach(store.lists) { list in
                    HStack {
                        Circle().fill(list.color).frame(width: 10, height: 10)
                        Text(list.name)
                        Spacer()
                        if widgets.isOpen(.list(list.id)) {
                            Image(systemName: "rectangle.on.rectangle")
                                .font(.caption2)
                                .foregroundColor(Theme.accent)
                        }
                        Text("\(list.remaining)")
                            .font(.caption)
                            .foregroundColor(Theme.textDim)
                    }
                    .tag(SidebarSelection.list(list.id))
                    .contextMenu {
                        Button(widgets.isOpen(.list(list.id)) ? "Close Desktop Widget" : "Show as Desktop Widget") {
                            widgets.toggle(.list(list.id))
                        }
                        Divider()
                        Button("Delete List", role: .destructive) {
                            if selection == .list(list.id) { selection = .today }
                            store.deleteList(list.id)
                        }
                    }
                }
                Button {
                    showingNewList = true
                } label: {
                    Label("New List", systemImage: "plus")
                        .foregroundColor(Theme.textDim)
                }
                .buttonStyle(.plain)
            }
            if !store.allTags.isEmpty {
                Section("Tags") {
                    ForEach(store.allTags, id: \.self) { tag in
                        Label("#\(tag)", systemImage: "number")
                            .tag(SidebarSelection.tag(tag))
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 190, ideal: 220)
    }

    @ViewBuilder
    private var detail: some View {
        switch selection {
        case .today, .none:
            DailyView()
        case .week:
            WeeklyView()
        case .stats:
            StatsView()
        case .list(let id):
            if store.list(with: id) != nil {
                ListDetailView(listID: id)
            } else {
                DailyView()
            }
        case .tag(let tag):
            TagView(tag: tag)
        }
    }
}

// MARK: - Daily view

struct DailyView: View {
    @EnvironmentObject var store: Store
    @ObservedObject var widgets = WidgetManager.shared
    @ObservedObject var events = EventsProvider.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today")
                        .font(.largeTitle.bold())
                        .foregroundColor(Theme.text)
                    Text(Date().formatted("EEEE d MMMM yyyy"))
                        .foregroundColor(Theme.textDim)
                }
                Spacer()
                Button {
                    widgets.toggle(.today)
                } label: {
                    Label(
                        widgets.isOpen(.today) ? "Close Widget" : "Desktop Widget",
                        systemImage: widgets.isOpen(.today) ? "rectangle.on.rectangle.slash" : "rectangle.on.rectangle"
                    )
                }
                .help("Show today's tasks as a floating desktop widget")
                Button {
                    CalendarBridge.showInCalendar(date: Date())
                } label: {
                    Label("Today in Calendar", systemImage: "arrow.up.forward.app")
                }
                .help("Show today in Apple Calendar")
            }

            QuickAddBar(defaultDue: Date())

            ScrollView {
                VStack(spacing: 6) {
                    if events.authorized {
                        let evs = events.events(on: Date())
                        if !evs.isEmpty {
                            SectionHeader(title: "Calendar", count: evs.count)
                            ForEach(evs) { EventRow(event: $0) }
                        }
                    } else {
                        Button {
                            events.connect()
                        } label: {
                            Label("Show Apple Calendar events here", systemImage: "calendar.badge.plus")
                                .font(.caption)
                                .foregroundColor(Theme.accent)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    let overdue = store.overdueRefs
                    if !overdue.isEmpty {
                        SectionHeader(title: "Overdue", count: overdue.count)
                        ForEach(overdue) { TaskRow(taskRef: $0, showListBadge: true) }
                    }

                    let today = store.refs(dueOn: Date())
                    SectionHeader(title: "Due Today", count: today.filter { !$0.item.isDone }.count)
                    if today.isEmpty {
                        Text("Nothing due today — enjoy it.")
                            .foregroundColor(Theme.textDim)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                    }
                    ForEach(today) { TaskRow(taskRef: $0, showListBadge: true) }

                    let noDate = store.noDateRefs
                    if !noDate.isEmpty {
                        SectionHeader(title: "No Due Date", count: noDate.count)
                        ForEach(noDate) { TaskRow(taskRef: $0, showListBadge: true) }
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .padding(20)
        .onAppear { events.refresh() }
    }
}

// MARK: - Tag view

struct TagView: View {
    @EnvironmentObject var store: Store
    let tag: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("#\(tag)")
                    .font(.largeTitle.bold())
                    .foregroundColor(Theme.accent)
                Text("Tagged tasks across all lists")
                    .foregroundColor(Theme.textDim)
            }

            ScrollView {
                VStack(spacing: 6) {
                    let refs = store.refs(tagged: tag)
                    ForEach(refs) { TaskRow(taskRef: $0, showListBadge: true) }
                }
                .padding(.bottom, 20)
            }
        }
        .padding(20)
    }
}

// MARK: - Weekly view

struct WeeklyView: View {
    @EnvironmentObject var store: Store
    @ObservedObject var events = EventsProvider.shared

    private var days: [Date] {
        let start = Date().startOfDay
        return (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: start) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("This Week")
                        .font(.largeTitle.bold())
                        .foregroundColor(Theme.text)
                    Text("The next 7 days — right-click a task or use ⏱ to give it a time slot")
                        .foregroundColor(Theme.textDim)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            ScrollView(.horizontal, showsIndicators: true) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(days, id: \.self) { day in
                        DayColumn(day: day)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .onAppear { events.refresh() }
    }
}

struct DayColumn: View {
    @EnvironmentObject var store: Store
    @ObservedObject var events = EventsProvider.shared
    let day: Date

    @State private var quickText = ""

    private var isToday: Bool { day.isSameDay(as: Date()) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                CalendarBridge.showInCalendar(date: day)
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(day.formatted("EEEE"))
                            .font(.headline)
                            .foregroundColor(isToday ? Theme.accent : Theme.text)
                        Text(day.formatted("d MMM"))
                            .font(.caption)
                            .foregroundColor(Theme.textDim)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.forward.app")
                        .font(.caption)
                        .foregroundColor(Theme.textDim)
                }
            }
            .buttonStyle(.plain)
            .help("Show this day in Apple Calendar")

            ForEach(events.events(on: day)) { ev in
                HStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(ev.color)
                        .frame(width: 3, height: 24)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(ev.title)
                            .font(.caption)
                            .foregroundColor(Theme.text)
                            .lineLimit(1)
                        Text(ev.timeLabel)
                            .font(.caption2)
                            .foregroundColor(Theme.textDim)
                    }
                    Spacer(minLength: 0)
                }
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 6).fill(Theme.card.opacity(0.45)))
            }

            let refs = store.weekRefs(on: day)
            if refs.isEmpty && events.events(on: day).isEmpty {
                Text("—")
                    .foregroundColor(Theme.textDim)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            ForEach(refs) { ref in
                WeekTaskCard(taskRef: ref, day: day)
            }

            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.caption)
                    .foregroundColor(Theme.textDim)
                TextField("Add…", text: $quickText)
                    .textFieldStyle(.plain)
                    .font(.callout)
                    .onSubmit {
                        if let first = store.lists.first {
                            store.addItem(to: first.id, title: quickText, due: day)
                        }
                        quickText = ""
                    }
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Theme.card.opacity(0.6)))

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(width: 220, alignment: .top)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isToday ? Theme.panel : Theme.panel.opacity(0.55))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isToday ? Theme.accent.opacity(0.5) : .clear, lineWidth: 1)
                )
        )
    }
}

struct WeekTaskCard: View {
    @EnvironmentObject var store: Store
    let taskRef: TaskRef
    let day: Date

    @State private var showingBlock = false
    @State private var hovering = false

    private var item: TodoItem { taskRef.item }

    var body: some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    store.toggleItem(item.id, in: taskRef.listID)
                }
            } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(item.isDone ? Theme.textDim : taskRef.color)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    if item.priority != .none {
                        Image(systemName: "flag.fill")
                            .font(.caption2)
                            .foregroundColor(item.priority.color)
                    }
                    Text(item.title)
                        .font(.callout)
                        .foregroundColor(item.isDone ? Theme.textDim : Theme.text)
                        .strikethrough(item.isDone, color: Theme.textDim)
                        .lineLimit(2)
                }
                HStack(spacing: 6) {
                    if let bs = item.blockStart, let bm = item.blockMinutes,
                       let end = Calendar.current.date(byAdding: .minute, value: bm, to: bs) {
                        Text("\(bs.formatted("HH:mm"))–\(end.formatted("HH:mm"))")
                            .font(.caption2.bold())
                            .foregroundColor(Theme.accent)
                    }
                    Text(taskRef.listName)
                        .font(.caption2)
                        .foregroundColor(Theme.textDim)
                }
            }
            Spacer(minLength: 0)

            if hovering || item.blockStart != nil {
                Button {
                    showingBlock = true
                } label: {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundColor(item.blockStart != nil ? Theme.accent : Theme.textDim)
                }
                .buttonStyle(.plain)
                .help("Set a time slot")
                .popover(isPresented: $showingBlock) {
                    TimeBlockEditor(taskRef: taskRef, day: day)
                        .environmentObject(store)
                }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.card))
        .onHover { hovering = $0 }
    }
}

// MARK: - List detail view

struct ListDetailView: View {
    @EnvironmentObject var store: Store
    @ObservedObject var widgets = WidgetManager.shared
    let listID: UUID

    @State private var showCompleted = true

    var body: some View {
        Group {
            if let list = store.list(with: listID) {
                content(for: list)
            }
        }
        .padding(20)
    }

    private func content(for list: TodoList) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Circle().fill(list.color).frame(width: 14, height: 14)
                Text(list.name)
                    .font(.largeTitle.bold())
                    .foregroundColor(Theme.text)
                Text("\(list.remaining) to do")
                    .foregroundColor(Theme.textDim)
                Spacer()
                Button {
                    widgets.toggle(.list(list.id))
                } label: {
                    Label(
                        widgets.isOpen(.list(list.id)) ? "Close Widget" : "Desktop Widget",
                        systemImage: widgets.isOpen(.list(list.id)) ? "rectangle.on.rectangle.slash" : "rectangle.on.rectangle"
                    )
                }
                .help("Show this list as a floating desktop widget")
            }

            QuickAddBar(fixedListID: list.id)

            ScrollView {
                VStack(spacing: 6) {
                    let active = list.items.filter { !$0.isDone }
                    let done = list.items.filter { $0.isDone }

                    SectionHeader(title: "To Do", count: active.count)
                    if active.isEmpty {
                        Text("All done ✓")
                            .foregroundColor(Theme.textDim)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                    }
                    ForEach(active) { item in
                        TaskRow(taskRef: TaskRef(listID: list.id, listName: list.name, colorHex: list.colorHex, item: item))
                    }

                    if !done.isEmpty {
                        HStack {
                            SectionHeader(title: "Completed", count: done.count)
                            Button(showCompleted ? "Hide" : "Show") {
                                withAnimation { showCompleted.toggle() }
                            }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundColor(Theme.accent)
                            Button("Clear") {
                                store.clearCompleted(in: list.id)
                            }
                            .buttonStyle(.plain)
                            .font(.caption)
                            .foregroundColor(Theme.danger.opacity(0.8))
                        }
                        if showCompleted {
                            ForEach(done) { item in
                                TaskRow(taskRef: TaskRef(listID: list.id, listName: list.name, colorHex: list.colorHex, item: item))
                            }
                        }
                    }
                }
                .padding(.bottom, 20)
            }
        }
    }
}
