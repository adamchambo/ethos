import Foundation

/// Records progress against the period covering `date`, without storing it.
func logProgress(
    habit: Habit,
    goal: Goal,
    schedule: HabitSchedule,
    amount: Decimal,
    on date: Date,
    existingPeriods: [HabitPeriod],
    existingEntries: [ProgressEntry],
    calendar: Calendar
) throws -> (period: HabitPeriod, entry: ProgressEntry, entries: [ProgressEntry])? {
    guard var period = resolvePeriod(
        habit: habit,
        goal: goal,
        schedule: schedule,
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
        goal: goal,
        period: period,
        entries: entries,
        now: date,
        isSkipped: false,
        isPaused: !habit.isActive
    )

    switch outcome {
    case .inProgress:
        break
    case .succeeded, .failed, .skipped:
        try period.finalize(as: outcome)
    }

    return (period: period, entry: entry, entries: entries)
}
