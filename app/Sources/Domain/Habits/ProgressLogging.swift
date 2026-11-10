import Foundation

/// Records progress against the period covering `date`.
func logProgress(
    habit: Habit,
    goal: Goal,
    schedule: HabitSchedule,
    amount: Decimal,
    on date: Date,
    existingPeriods: [HabitPeriod],
    existingEntries: [ProgressEntry],
    calendar: Calendar,
    allowLoggingBeyondTarget: Bool = false,
    checklistItemID: UUID? = nil,
    now: Date = Date()
) throws -> QuickLogSuccess? {
    if isFutureDay(date: date, now: now, calendar: calendar) {
        throw QuickLogError.futureDate
    }

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

    let currentProgress = progressTowardGoal(
        goal: goal,
        period: period,
        entries: existingEntries,
        calendar: calendar
    )

    if currentProgress >= goal.target, !allowLoggingBeyondTarget {
        throw QuickLogError.targetReached
    }

    if period.isFinalized {
        guard period.outcome == .succeeded, allowLoggingBeyondTarget else {
            throw QuickLogError.alreadyFinalized
        }
    }

    let entry = try ProgressEntry(
        habitID: habit.id,
        occurredAt: date,
        amount: amount,
        checklistItemID: checklistItemID
    )
    let entries = existingEntries + [entry]
    let outcome = evaluatePeriod(
        goal: goal,
        period: period,
        entries: entries,
        now: max(date, now),
        isSkipped: false,
        isPaused: !habit.isActive,
        calendar: calendar
    )

    if period.isFinalized {
        period.recalculateOutcome(outcome == .inProgress ? .succeeded : outcome)
    } else {
        switch outcome {
        case .inProgress:
            break
        case .succeeded, .failed, .skipped:
            try period.finalize(as: outcome)
        }
    }

    var periods = existingPeriods
    if let index = periods.firstIndex(where: {
        $0.id == period.id
            || ($0.habitID == period.habitID && $0.startsAt == period.startsAt && $0.endsAt == period.endsAt)
    }) {
        periods[index] = period
    } else {
        periods.append(period)
    }

    return QuickLogSuccess(period: period, entry: entry, entries: entries, periods: periods)
}

/// Completes the open period in one action by logging the remaining amount.
func completeHabitProgress(
    habit: Habit,
    goal: Goal,
    schedule: HabitSchedule,
    on date: Date,
    existingPeriods: [HabitPeriod],
    existingEntries: [ProgressEntry],
    calendar: Calendar,
    allowLoggingBeyondTarget: Bool = false,
    now: Date = Date()
) throws -> QuickLogSuccess? {
    guard let period = resolvePeriod(
        habit: habit,
        goal: goal,
        schedule: schedule,
        on: date,
        existing: existingPeriods,
        calendar: calendar
    ) else {
        return nil
    }

    let progress = progressTowardGoal(
        goal: goal,
        period: period,
        entries: existingEntries,
        calendar: calendar
    )
    let remaining = remainingToComplete(goal: goal, progress: progress)
    guard remaining > 0 else {
        throw QuickLogError.nothingToComplete
    }

    return try logProgress(
        habit: habit,
        goal: goal,
        schedule: schedule,
        amount: remaining,
        on: date,
        existingPeriods: existingPeriods,
        existingEntries: existingEntries,
        calendar: calendar,
        allowLoggingBeyondTarget: allowLoggingBeyondTarget,
        now: now
    )
}

/// Removes one dated entry and recalculates the affected period outcome.
func undoProgress(
    entryID: UUID,
    habit: Habit,
    goal: Goal,
    schedule: HabitSchedule,
    existingPeriods: [HabitPeriod],
    existingEntries: [ProgressEntry],
    calendar: Calendar,
    now: Date = Date()
) throws -> (periods: [HabitPeriod], entries: [ProgressEntry], removed: ProgressEntry) {
    guard let removed = existingEntries.first(where: { $0.id == entryID }) else {
        throw ProgressEntryError.missingEntry
    }

    let entries = existingEntries.filter { $0.id != entryID }
    var periods = existingPeriods

    guard var period = resolvePeriod(
        habit: habit,
        goal: goal,
        schedule: schedule,
        on: removed.occurredAt,
        existing: periods,
        calendar: calendar
    ) else {
        return (periods: periods, entries: entries, removed: removed)
    }

    let outcome = evaluatePeriod(
        goal: goal,
        period: period,
        entries: entries,
        now: max(removed.occurredAt, now),
        isSkipped: false,
        isPaused: !habit.isActive,
        calendar: calendar
    )
    period.recalculateOutcome(outcome)

    if let index = periods.firstIndex(where: {
        $0.id == period.id
            || ($0.habitID == period.habitID && $0.startsAt == period.startsAt && $0.endsAt == period.endsAt)
    }) {
        periods[index] = period
    } else {
        periods.append(period)
    }

    return (periods: periods, entries: entries, removed: removed)
}
