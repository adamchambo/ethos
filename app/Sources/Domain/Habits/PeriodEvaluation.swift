import Foundation

func progressEntries(in period: HabitPeriod, from entries: [ProgressEntry]) -> [ProgressEntry] {
    entries.filter {
        $0.habitID == period.habitID
            && $0.occurredAt >= period.startsAt
            && $0.occurredAt < period.endsAt
    }
}

/// Amount logged directly against the habit. Checklist-item entries are a separate success path.
func goalTotal(in period: HabitPeriod, entries: [ProgressEntry]) -> Decimal {
    progressEntries(in: period, from: entries)
        .filter { $0.checklistItemID == nil }
        .reduce(.zero) { $0 + $1.amount }
}

/// Total logged divided by the target. A zero target (avoid entirely) is 0 with no slips,
/// and the slip total otherwise, so a slip still reads as more than a full target.
func progressFraction(
    habit: Habit,
    period: HabitPeriod,
    entries: [ProgressEntry]
) -> Decimal {
    let total = goalTotal(in: period, entries: entries)
    guard habit.goal.target > .zero else {
        return total == .zero ? .zero : total
    }
    return total / habit.goal.target
}

/// The fraction to show. The cap is a display choice on the goal, not a stored value.
func displayedProgressFraction(
    habit: Habit,
    period: HabitPeriod,
    entries: [ProgressEntry]
) -> Decimal {
    let fraction = progressFraction(habit: habit, period: period, entries: entries)
    guard habit.goal.target > .zero, !habit.goal.allowsOverCompletion else {
        return fraction
    }
    return min(fraction, 1)
}

/// Returns the current outcome for a period without finalizing it.
func evaluatePeriod(
    habit: Habit,
    period: HabitPeriod,
    entries: [ProgressEntry],
    now: Date,
    isSkipped: Bool
) -> HabitPeriodOutcome {
    if isSkipped { return .skipped }
    if !habit.isActive { return .inProgress }

    let total = goalTotal(in: period, entries: entries)

    switch habit.direction {
    case .quit:
        if total > habit.goal.target { return .failed }
        if now >= period.endsAt { return .succeeded }
        return .inProgress

    case .build:
        let targetReached = total >= habit.goal.target || checklistSatisfied(habit: habit, period: period, entries: entries)
        if habit.goal.interval == .week && now < period.endsAt {
            return .inProgress
        }
        if targetReached { return .succeeded }
        if now >= period.endsAt { return .failed }
        return .inProgress
    }
}

private func checklistSatisfied(habit: Habit, period: HabitPeriod, entries: [ProgressEntry]) -> Bool {
    let active = habit.checklist.filter(\.isActive)
    guard !active.isEmpty else { return false }

    let completed = Set(progressEntries(in: period, from: entries).compactMap(\.checklistItemID))
    return active.allSatisfy { completed.contains($0.id) }
}
