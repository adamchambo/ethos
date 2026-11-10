import Foundation

/// Progress toward a goal inside one period.
///
/// Logs keep their individual dates; this total belongs to the period window.
func progressTowardGoal(
    goal: Goal,
    period: HabitPeriod,
    entries: [ProgressEntry],
    calendar: Calendar
) -> Decimal {
    let matching = entries.filter {
        $0.habitID == period.habitID
            && $0.occurredAt >= period.startsAt
            && $0.occurredAt < period.endsAt
    }

    switch goal.countingMode {
    case .sessions:
        return matching.reduce(Decimal.zero) { $0 + $1.amount }

    case .days:
        var days = Set<Date>()
        for entry in matching {
            days.insert(calendar.startOfDay(for: entry.occurredAt))
        }
        return Decimal(days.count)
    }
}

func hasLoggedOnDay(
    habitID: UUID,
    day: Date,
    entries: [ProgressEntry],
    calendar: Calendar
) -> Bool {
    let start = calendar.startOfDay(for: day)
    guard let end = calendar.date(byAdding: .day, value: 1, to: start) else {
        return false
    }

    return entries.contains {
        $0.habitID == habitID && $0.occurredAt >= start && $0.occurredAt < end
    }
}
