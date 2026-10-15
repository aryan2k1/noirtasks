import SwiftUI

/// Content of a floating desktop widget — either one list, or "Today" across all lists.
struct WidgetView: View {
    @EnvironmentObject var store: Store
    @EnvironmentObject var widgets: WidgetManager
    @ObservedObject var events = EventsProvider.shared
    let kind: WidgetKind

    @State private var quickText = ""

    var body: some View {
        Group {
            switch kind {
            case .list(let id):
                if let list = store.list(with: id) {
                    listContent(list)
                } else {
                    Text("List deleted")
                        .foregroundColor(Theme.textDim)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            case .today:
                todayContent
            }
        }
        .frame(width: 280, height: 380)
        .background(
            ZStack {
                Glass()
                Theme.panel.opacity(0.55)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
        )
        .preferredColorScheme(.dark)
    }

    // MARK: - List widget

    private func listContent(_ list: TodoList) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            header(title: list.name, color: list.color, count: list.remaining)
            Divider().background(Color.white.opacity(0.06))
            ScrollView {
                VStack(spacing: 4) {
                    let refs = list.items.filter { !$0.isDone }.map {
                        TaskRef(listID: list.id, listName: list.name, colorHex: list.colorHex, item: $0)
                    }
                    if refs.isEmpty { allClear }
                    ForEach(refs) { widgetRow($0) }
                }
                .padding(8)
            }
            Divider().background(Color.white.opacity(0.06))
            quickAdd { store.addItem(to: list.id, title: $0, due: nil) }
        }
    }

    // MARK: - Today widget

    private var todayContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            header(title: "Today", color: Theme.accent, count: todayRefs.count)
            Divider().background(Color.white.opacity(0.06))
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    let evs = events.events(on: Date())
                    if !evs.isEmpty {
                        ForEach(evs.prefix(3)) { ev in
                            HStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(ev.color)
                                    .frame(width: 3, height: 22)
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
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                        }
                        Divider().background(Color.white.opacity(0.06)).padding(.vertical, 2)
                    }
                    if todayRefs.isEmpty { allClear }
                    ForEach(todayRefs) { widgetRow($0, showListDot: true) }
                }
                .padding(8)
            }
            Divider().background(Color.white.opacity(0.06))
            quickAdd { text in
                if let first = store.lists.first {
                    store.addItem(to: first.id, title: text, due: Date())
                }
            }
        }
    }

    private var todayRefs: [TaskRef] {
        (store.overdueRefs + store.refs(dueOn: Date()).filter { !$0.item.isDone })
    }

    // MARK: - Pieces

    private var allClear: some View {
        Text("All clear ✓")
            .font(.callout)
            .foregroundColor(Theme.textDim)
            .frame(maxWidth: .infinity)
            .padding(.top, 24)
    }

    private func header(title: String, color: Color, count: Int) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(title)
                .font(.headline)
                .foregroundColor(Theme.text)
            Text("\(count)")
                .font(.caption.bold())
                .foregroundColor(Theme.textDim)
            Spacer()
            Button {
                widgets.togglePin(kind)
            } label: {
                Image(systemName: widgets.isPinned(kind) ? "pin.fill" : "pin")
                    .foregroundColor(widgets.isPinned(kind) ? Theme.accent : Theme.textDim)
            }
            .buttonStyle(.plain)
            .help(widgets.isPinned(kind)
                  ? "Pinned to desktop — click to float above windows"
                  : "Floating — click to pin to desktop")
            Button {
                widgets.showMainWindow()
            } label: {
                Image(systemName: "macwindow")
                    .foregroundColor(Theme.textDim)
            }
            .buttonStyle(.plain)
            .help("Open NoirTasks")
            Button {
                widgets.close(kind)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(Theme.textDim)
            }
            .buttonStyle(.plain)
            .help("Close widget")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func widgetRow(_ ref: TaskRef, showListDot: Bool = false) -> some View {
        HStack(spacing: 8) {
            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    store.toggleItem(ref.item.id, in: ref.listID)
                }
            } label: {
                Image(systemName: "circle")
                    .foregroundColor(ref.color)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    if ref.item.priority == .high {
                        Image(systemName: "flag.fill")
                            .font(.caption2)
                            .foregroundColor(Priority.high.color)
                    }
                    Text(ref.item.title)
                        .font(.callout)
                        .foregroundColor(Theme.text)
                        .lineLimit(2)
                }
                HStack(spacing: 6) {
                    if let due = ref.item.dueDate {
                        Text(dueLabel(due))
                            .font(.caption2)
                            .foregroundColor(due.startOfDay < Date().startOfDay ? Theme.danger : Theme.textDim)
                    }
                    if showListDot {
                        Text(ref.listName)
                            .font(.caption2)
                            .foregroundColor(Theme.textDim)
                    }
                    if let progress = ref.item.subtaskProgress {
                        Text("\(Int(progress * 100))%")
                            .font(.caption2)
                            .foregroundColor(Theme.accent)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(Theme.card.opacity(0.75)))
    }

    private func quickAdd(_ submit: @escaping (String) -> Void) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "plus")
                .font(.caption)
                .foregroundColor(Theme.textDim)
            TextField("Quick add…", text: $quickText)
                .textFieldStyle(.plain)
                .font(.callout)
                .foregroundColor(Theme.text)
                .onSubmit {
                    submit(quickText)
                    quickText = ""
                }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func dueLabel(_ date: Date) -> String {
        if date.isSameDay(as: Date()) { return "Today" }
        if let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date()),
           date.isSameDay(as: tomorrow) { return "Tomorrow" }
        return date.formatted("EEE d MMM")
    }
}
