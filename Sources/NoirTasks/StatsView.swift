import SwiftUI

struct StatsView: View {
    @EnvironmentObject var store: Store
    @ObservedObject var notifier = Notifier.shared
    @ObservedObject var events = EventsProvider.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Stats")
                    .font(.largeTitle.bold())
                    .foregroundColor(Theme.text)
                Text("Your progress and settings")
                    .foregroundColor(Theme.textDim)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        statCard(value: "\(store.doneToday)", label: "Done today", icon: "checkmark.circle.fill", color: Color(hex: "#66BB6A"))
                        statCard(value: "\(store.doneThisWeek)", label: "Done this week", icon: "calendar", color: Color(hex: "#4FC3F7"))
                        statCard(value: "\(store.streak)", label: "Day streak 🔥", icon: "flame.fill", color: Color(hex: "#FFB74D"))
                    }

                    chartCard

                    settingsCard
                }
                .padding(.bottom, 20)
            }
        }
        .padding(20)
    }

    private func statCard(value: String, label: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(value)
                .font(.system(size: 30, weight: .bold))
                .foregroundColor(Theme.text)
            Text(label)
                .font(.caption)
                .foregroundColor(Theme.textDim)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.panel))
    }

    private var chartDays: [Date] {
        let cal = Calendar.current
        let today = Date().startOfDay
        return (0..<14).reversed().compactMap { cal.date(byAdding: .day, value: -$0, to: today) }
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("COMPLETED — LAST 14 DAYS")
                .font(.caption.bold())
                .foregroundColor(Theme.textDim)

            let counts = chartDays.map { store.completions(on: $0) }
            let maxCount = max(counts.max() ?? 1, 1)

            HStack(alignment: .bottom, spacing: 8) {
                ForEach(Array(zip(chartDays, counts)), id: \.0) { day, count in
                    VStack(spacing: 4) {
                        Text(count > 0 ? "\(count)" : " ")
                            .font(.caption2)
                            .foregroundColor(Theme.textDim)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(count > 0 ? Theme.accent : Theme.card)
                            .frame(height: max(6, CGFloat(count) / CGFloat(maxCount) * 90))
                        Text(day.formatted("EE"))
                            .font(.caption2)
                            .foregroundColor(day.isSameDay(as: Date()) ? Theme.accent : Theme.textDim)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 130, alignment: .bottom)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.panel))
    }

    private var settingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SETTINGS")
                .font(.caption.bold())
                .foregroundColor(Theme.textDim)

            Toggle("Notify me about tasks due today", isOn: $notifier.enabled)
                .toggleStyle(.switch)
            if notifier.enabled {
                Picker("Notification time", selection: $notifier.hour) {
                    ForEach(6..<22, id: \.self) { h in
                        Text(String(format: "%02d:00", h)).tag(h)
                    }
                }
                .frame(maxWidth: 260)
            }

            Divider().background(Color.white.opacity(0.06))

            HStack {
                Image(systemName: "calendar")
                    .foregroundColor(Theme.accent)
                if events.authorized {
                    Text("Apple Calendar connected — events show in Today and Week views")
                        .foregroundColor(Theme.textDim)
                } else {
                    Button("Connect Apple Calendar (show events in Today & Week)") {
                        events.connect()
                    }
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.panel))
    }
}
