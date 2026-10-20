import Foundation

enum ProgressActionError: Error, Equatable {
    case nothingRemaining
    case notAvailableForQuit
}

/// Records progress against the period covering `date`, without storing it.
func logProgress(
    habit: Habit,
    amount: Decimal,
    on date: Date,
    existingPeriods: [HabitPeriod],
    existingEntries: [ProgressEntry],
    calendar: Calendar,
    checklistItemID: UUID? = nil,
    note: String? = nil
) throws -> (period: HabitPeriod, entry: ProgressEntry, entries: [ProgressEntry])? {
    if let checklistItemID {
        guard habit.checklist.contains(where: { $0.id == checklistItemID && $0.isActive }) else {
            throw HabitError.unknownChecklistItem
        }
    }

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

    let entry = try ProgressEntry(
        habitID: habit.id,
        occurredAt: date,
        amount: amount,
        checklistItemID: checklistItemID,
        note: note
    )
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

/// Logs whatever is still required to reach the target. Quit habits have no quick completion.
func quickComplete(
    habit: Habit,
    on date: Date,
    existingPeriods: [HabitPeriod],
    existingEntries: [ProgressEntry],
    calendar: Calendar
) throws -> (period: HabitPeriod, entry: ProgressEntry, entries: [ProgressEntry])? {
    guard habit.direction == .build else {
        throw ProgressActionError.notAvailableForQuit
    }

    guard let period = resolvePeriod(
        habit: habit,
        on: date,
        existing: existingPeriods,
        calendar: calendar
    ) else {
        return nil
    }

    let remaining = habit.goal.target - goalTotal(in: period, entries: existingEntries)
    guard remaining > .zero else {
        throw ProgressActionError.nothingRemaining
    }

    return try logProgress(
        habit: habit,
        amount: remaining,
        on: date,
        existingPeriods: existingPeriods,
        existingEntries: existingEntries,
        calendar: calendar
    )
}

/// Reopens a succeeded period and drops its entries. Only while the window is still open.
func uncomplete(
    period: HabitPeriod,
    entries: [ProgressEntry],
    now: Date
) throws -> (period: HabitPeriod, entries: [ProgressEntry]) {
    guard now < period.endsAt else {
        throw HabitPeriodError.periodClosed
    }

    var reopened = period
    try reopened.reopen()
    let remaining = entries.filter { entry in
        entry.habitID != period.habitID
            || entry.occurredAt < period.startsAt
            || entry.occurredAt >= period.endsAt
    }
    return (reopened, remaining)
}

/// Finalizes in-progress periods whose window has ended. A paused or archived habit stays in progress.
func closeExpiredPeriods(
    habits: [Habit],
    periods: [HabitPeriod],
    entries: [ProgressEntry],
    now: Date
) -> [HabitPeriod] {
    periods.map { period in
        guard !period.isFinalized, now >= period.endsAt else { return period }
        guard let habit = habits.first(where: { $0.id == period.habitID }), habit.isActive else {
            return period
        }

        let outcome = evaluatePeriod(
            habit: habit,
            period: period,
            entries: entries,
            now: now,
            isSkipped: false
        )
        guard outcome == .succeeded || outcome == .failed else { return period }

        var closed = period
        try? closed.finalize(as: outcome)
        return closed
    }
}
