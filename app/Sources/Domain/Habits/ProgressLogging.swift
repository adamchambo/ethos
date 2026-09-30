import Foundation

/// Records progress against the period covering `date`, without storing it.
func logProgress(
    habit: Habit,
    amount: Decimal,
    on date: Date,
    existingPeriods: [HabitPeriod],
    existingEntries: [ProgressEntry],
    calendar: Calendar
) throws -> (period: HabitPeriod, entry: ProgressEntry, entries: [ProgressEntry])? {
    guard var period = resolvePeriod(
        habit: habit,
        on: date,
        existing: existingPeriods,
        calendar: calendar
    ) else {
        return nil
    }

    guard !period.isFinalized else {
        throw HabitPeriodError.alreadyFinalized
    }

    let entry = try ProgressEntry(habitID: habit.id, occurredAt: date, amount: amount)
    let entries = existingEntries + [entry]
    let outcome = evaluatePeriod(
        habit: habit,
        period: period,
        entries: entries,
        now: date,
        isSkipped: false
    )

    switch outcome {
    case .inProgress:
        break
    case .succeeded, .failed, .skipped:
        try period.finalize(as: outcome)
    }

    return (period: period, entry: entry, entries: entries)
}
