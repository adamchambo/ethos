import Foundation

struct DayHabitRow: Equatable, Identifiable, Sendable {
    let habit: Habit
    let goal: Goal
    let schedule: HabitSchedule
    let placement: DayPlacement
    let scheduleLabel: String
    let progressLabel: String
    let progress: Decimal
    let loggedToday: Bool

    var id: UUID { habit.id }

    var isFinished: Bool {
        if case .finished = placement { return true }
        return false
    }
}

struct DayViewSnapshot: Equatable, Sendable {
    let date: Date
    let morning: [DayHabitRow]
    let afternoon: [DayHabitRow]
    let evening: [DayHabitRow]
    let anytime: [DayHabitRow]
    let finished: [DayHabitRow]
    /// Habits that still need something today — excludes flexible week/month targets.
    let unfinishedDailyCommitments: Int
    let scheduledTodayCount: Int

    var sections: [(title: String, rows: [DayHabitRow])] {
        [
            ("Morning", morning),
            ("Afternoon", afternoon),
            ("Evening", evening),
            ("Anytime", anytime),
            ("Finished", finished)
        ].filter { !$0.rows.isEmpty }
    }
}

func formatGoalAmount(_ value: Decimal) -> String {
    var value = value
    var rounded = Decimal()
    NSDecimalRound(&rounded, &value, 0, .plain)
    if rounded == value {
        return "\(NSDecimalNumber(decimal: value).intValue)"
    }
    return NSDecimalNumber(decimal: value).stringValue
}

/// Schedule copy shown under the habit name.
func scheduleLabel(schedule: HabitSchedule, goal: Goal) -> String {
    switch schedule {
    case .daily:
        if goal.interval == .day {
            return "Every day"
        }
        return flexiblePeriodScheduleLabel(goal: goal)

    case let .weekly(eligibleWeekdays):
        if eligibleWeekdays.isEmpty {
            if goal.interval == .day {
                return "Every day"
            }
            return flexiblePeriodScheduleLabel(goal: goal)
        }

        return Weekday.allCases
            .filter { eligibleWeekdays.contains($0) }
            .map(\.shortName)
            .joined(separator: ", ")

    case let .every(days, _):
        return days == 1 ? "Every day" : "Every \(days) days"
    }
}

private func flexiblePeriodScheduleLabel(goal: Goal) -> String {
    let amount = formatGoalAmount(goal.target)
    let unit: String
    switch (goal.countingMode, goal.interval) {
    case (.sessions, .week):
        unit = amount == "1" ? "1 time a week" : "\(amount) times a week"
    case (.days, .week):
        unit = amount == "1" ? "1 day a week" : "\(amount) days a week"
    case (.sessions, .month):
        unit = amount == "1" ? "1 time a month" : "\(amount) times a month"
    case (.days, .month):
        unit = amount == "1" ? "1 day a month" : "\(amount) days a month"
    case (.sessions, .year):
        unit = amount == "1" ? "1 time a year" : "\(amount) times a year"
    case (.days, .year):
        unit = amount == "1" ? "1 day a year" : "\(amount) days a year"
    case (_, .day):
        return "Every day"
    }
    return "\(unit) · Any day"
}

/// Progress copy for the row, including today's activity for open weekly targets.
func progressLabel(
    goal: Goal,
    progress: Decimal,
    loggedToday: Bool,
    isFinished: Bool
) -> String {
    let current = formatGoalAmount(min(progress, goal.target))
    let target = formatGoalAmount(goal.target)
    let timeframe = goal.interval.progressTimeframePhrase
    let fraction = "\(current)/\(target) \(timeframe)"

    if isFinished {
        return "\(target)/\(target) \(timeframe)"
    }

    if loggedToday, goal.interval != .day {
        return "Logged today · \(fraction)"
    }

    return fraction
}

func makeDayHabitRow(
    habit: Habit,
    goal: Goal,
    schedule: HabitSchedule,
    on date: Date,
    periods: [HabitPeriod],
    entries: [ProgressEntry],
    calendar: Calendar
) -> DayHabitRow? {
    let period = resolvePeriod(
        habit: habit,
        goal: goal,
        schedule: schedule,
        on: date,
        existing: periods,
        calendar: calendar
    )

    let placement = dayPlacement(
        habit: habit,
        goal: goal,
        schedule: schedule,
        on: date,
        period: period,
        entries: entries,
        calendar: calendar
    )

    guard placement != .hidden else { return nil }

    let progress: Decimal
    if let period {
        progress = progressTowardGoal(
            goal: goal,
            period: period,
            entries: entries,
            calendar: calendar
        )
    } else {
        progress = 0
    }

    let loggedToday = hasLoggedOnDay(
        habitID: habit.id,
        day: date,
        entries: entries,
        calendar: calendar
    )
    let finished = placement == .finished

    return DayHabitRow(
        habit: habit,
        goal: goal,
        schedule: schedule,
        placement: placement,
        scheduleLabel: scheduleLabel(schedule: schedule, goal: goal),
        progressLabel: progressLabel(
            goal: goal,
            progress: progress,
            loggedToday: loggedToday,
            isFinished: finished
        ),
        progress: progress,
        loggedToday: loggedToday
    )
}

struct HabitDefinition: Equatable, Sendable {
    var habit: Habit
    var goal: Goal
    var schedule: HabitSchedule
}

func makeDayViewSnapshot(
    definitions: [HabitDefinition],
    on date: Date,
    periods: [HabitPeriod],
    entries: [ProgressEntry],
    calendar: Calendar
) -> DayViewSnapshot {
    var morning: [DayHabitRow] = []
    var afternoon: [DayHabitRow] = []
    var evening: [DayHabitRow] = []
    var anytime: [DayHabitRow] = []
    var finished: [DayHabitRow] = []
    var unfinishedDaily = 0
    var scheduled = 0

    for definition in definitions {
        guard let row = makeDayHabitRow(
            habit: definition.habit,
            goal: definition.goal,
            schedule: definition.schedule,
            on: date,
            periods: periods,
            entries: entries,
            calendar: calendar
        ) else {
            continue
        }

        scheduled += 1

        switch row.placement {
        case .hidden:
            break
        case .finished:
            finished.append(row)
        case let .inProgress(part):
            if countsAsDailyCommitment(goal: definition.goal) {
                unfinishedDaily += 1
            }
            switch part {
            case .morning: morning.append(row)
            case .afternoon: afternoon.append(row)
            case .evening: evening.append(row)
            case .anytime: anytime.append(row)
            }
        }
    }

    return DayViewSnapshot(
        date: date,
        morning: morning,
        afternoon: afternoon,
        evening: evening,
        anytime: anytime,
        finished: finished,
        unfinishedDailyCommitments: unfinishedDaily,
        scheduledTodayCount: scheduled
    )
}
