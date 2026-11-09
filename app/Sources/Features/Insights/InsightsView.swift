import SwiftUI

struct InsightsView: View {
    let service: HabitProgressService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var range = StatisticsRange.week

    var body: some View {
        let habits = service.habits.filter { $0.lifecycle != .archived }
        let overall = service.outcomes(in: range, containing: .now, calendar: service.calendar)
        let current = habits.map { service.streak(habitID: $0.id) }.max() ?? 0
        let longest = habits.map { service.best(habitID: $0.id) }.max() ?? 0

        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 14) {
                        Picker("Range", selection: $range) {
                            ForEach(StatisticsRange.allCases, id: \.self) { range in
                                Text(range.label).tag(range)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text(windowText(for: range))
                            .font(.subheadline)
                            .foregroundStyle(EthosColor.secondaryInk)
                            .contentTransition(.numericText())

                        HStack(alignment: .firstTextBaseline) {
                            headline(
                                rateText(completionRate(succeeded: overall.succeeded, failed: overall.failed)),
                                caption: "completion"
                            )
                            headline(
                                "\(current) / \(longest)",
                                caption: "all-time current / longest"
                            )
                        }

                        if overall.succeeded + overall.failed > 0 {
                            Text("\(overall.succeeded) done, \(overall.failed) missed. Skips are left out.")
                                .font(.subheadline)
                                .monospacedDigit()
                                .foregroundStyle(EthosColor.secondaryInk)
                                .contentTransition(.numericText())
                        }
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 20, bottom: 8, trailing: 20))
                }

                Section("Habits") {
                    if habits.isEmpty {
                        Text("Streaks and completion show up after you add a habit.")
                            .foregroundStyle(EthosColor.secondaryInk)
                    } else {
                        ForEach(habits) { habit in
                            let outcomes = service.outcomes(
                                in: range,
                                containing: .now,
                                calendar: service.calendar,
                                habitID: habit.id
                            )
                            NavigationLink(value: habit.id) {
                                HabitSummaryRow(
                                    habit: habit,
                                    categories: service.categories,
                                    detail: "Streak \(service.streak(habitID: habit.id)) · Best \(service.best(habitID: habit.id))",
                                    trailing: rateText(completionRate(succeeded: outcomes.succeeded, failed: outcomes.failed))
                                )
                            }
                        }
                    }
                }
                .ethosRows()
            }
            .ethosScreen()
            .navigationTitle("Insights")
            .navigationDestination(for: UUID.self) { id in
                HabitDetailView(service: service, habitID: id)
            }
            .animation(reduceMotion ? nil : .default, value: range)
        }
    }

    private func headline(_ value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value)
                .font(.system(size: 40, weight: .semibold))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(caption)
                .font(.subheadline)
                .foregroundStyle(EthosColor.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func completionRate(succeeded: Int, failed: Int) -> Decimal? {
        let total = succeeded + failed
        guard total > 0 else { return nil }
        return Decimal(succeeded) / Decimal(total)
    }

    private func windowText(for range: StatisticsRange, now: Date = .now) -> String {
        let calendar = service.calendar
        let window = range.window(
            containing: now,
            calendar: calendar,
            weekStartsOn: service.profile.weekStart
        )

        switch range {
        case .today:
            guard let window else { return "Since you started" }
            return "\(weekdayName(window.startsAt, calendar: calendar)) \(day(window.startsAt, calendar: calendar)) \(monthName(window.startsAt, calendar: calendar))"
        case .week:
            guard let window else { return "Since you started" }
            // The window is half-open, so the last labelled day is the one before endsAt.
            let lastDay = calendar.date(byAdding: .day, value: -1, to: window.endsAt) ?? window.startsAt
            return weekSpan(from: window.startsAt, to: lastDay, calendar: calendar, now: now)
        case .month:
            guard let window else { return "Since you started" }
            return "\(monthName(window.startsAt, calendar: calendar)) \(year(window.startsAt, calendar: calendar))"
        case .year:
            guard let window else { return "Since you started" }
            return String(year(window.startsAt, calendar: calendar))
        case .all:
            return "Since you started"
        }
    }

    private func weekSpan(from start: Date, to end: Date, calendar: Calendar, now: Date) -> String {
        let startDay = day(start, calendar: calendar)
        let endDay = day(end, calendar: calendar)
        let sameMonth = calendar.isDate(start, equalTo: end, toGranularity: .month)
        let sameYear = calendar.isDate(start, equalTo: end, toGranularity: .year)
        let currentYear = calendar.isDate(start, equalTo: now, toGranularity: .year) && sameYear

        if sameMonth {
            let span = "\(startDay)–\(endDay) \(monthName(start, calendar: calendar))"
            return currentYear ? span : "\(span) \(year(start, calendar: calendar))"
        }
        if sameYear {
            let span = "\(startDay) \(monthName(start, calendar: calendar))–\(endDay) \(monthName(end, calendar: calendar))"
            return currentYear ? span : "\(span) \(year(start, calendar: calendar))"
        }
        return "\(startDay) \(monthName(start, calendar: calendar)) \(year(start, calendar: calendar))–\(endDay) \(monthName(end, calendar: calendar)) \(year(end, calendar: calendar))"
    }

    private func day(_ date: Date, calendar: Calendar) -> Int {
        calendar.component(.day, from: date)
    }

    private func year(_ date: Date, calendar: Calendar) -> Int {
        calendar.component(.year, from: date)
    }

    private func monthName(_ date: Date, calendar: Calendar) -> String {
        date.formatted(format(calendar).month(.wide))
    }

    private func weekdayName(_ date: Date, calendar: Calendar) -> String {
        date.formatted(format(calendar).weekday(.wide))
    }

    private func format(_ calendar: Calendar) -> Date.FormatStyle {
        var style = Date.FormatStyle()
        style.locale = calendar.locale ?? .current
        style.timeZone = calendar.timeZone
        return style
    }
}
