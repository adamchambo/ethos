import SwiftUI

/// In-memory Day screen for exercising the presentation rules in the simulator.
struct DayViewScreen: View {
    @State private var selectedDate = Date()
    @State private var periods: [HabitPeriod] = []
    @State private var entries: [ProgressEntry] = []

    private var calendar: Calendar { .current }

    private var definitions: [HabitDefinition] {
        DayViewDemo.definitions(reference: selectedDate, calendar: calendar)
    }

    private var snapshot: DayViewSnapshot {
        makeDayViewSnapshot(
            definitions: definitions,
            on: selectedDate,
            periods: periods,
            entries: entries,
            calendar: calendar
        )
    }

    var body: some View {
        NavigationStack {
            DayView(snapshot: snapshot, onLog: log)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            shiftDay(-1)
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        .accessibilityLabel("Yesterday")
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            shiftDay(1)
                        } label: {
                            Image(systemName: "chevron.right")
                        }
                        .accessibilityLabel("Tomorrow")
                    }
                }
        }
    }

    private func shiftDay(_ value: Int) {
        guard let next = calendar.date(byAdding: .day, value: value, to: selectedDate) else {
            return
        }
        selectedDate = next
    }

    private func log(_ row: DayHabitRow) {
        let amount: Decimal = row.goal.countingMode == .days ? 1 : 1
        guard let result = try? logProgress(
            habit: row.habit,
            goal: row.goal,
            schedule: row.schedule,
            amount: amount,
            on: selectedDate,
            existingPeriods: periods,
            existingEntries: entries,
            calendar: calendar
        ) else {
            return
        }

        if let index = periods.firstIndex(where: {
            $0.habitID == result.period.habitID
                && $0.startsAt == result.period.startsAt
                && $0.endsAt == result.period.endsAt
        }) {
            periods[index] = result.period
        } else {
            periods.append(result.period)
        }
        entries = result.entries
    }
}

#Preview {
    DayViewScreen()
}
