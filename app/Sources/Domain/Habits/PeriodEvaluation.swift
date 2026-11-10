import Foundation

/// Returns the current outcome for a period without mutating stored state.
///
/// Weekly (and longer) targets succeed as soon as progress reaches the target.
/// They only fail once the period has ended with a shortfall — they are never
/// marked missed on an individual evening while the period is still open.
func evaluatePeriod(
    goal: Goal,
    period: HabitPeriod,
    entries: [ProgressEntry],
    now: Date,
    isSkipped: Bool,
    isPaused: Bool,
    calendar: Calendar = Calendar(identifier: .gregorian)
) -> HabitPeriodOutcome {
    if isSkipped { return .skipped }
    if isPaused { return .inProgress }

    let total = progressTowardGoal(
        goal: goal,
        period: period,
        entries: entries,
        calendar: calendar
    )

    if total >= goal.target { return .succeeded }
    if now >= period.endsAt { return .failed }
    return .inProgress
}
