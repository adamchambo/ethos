import Foundation

struct DayHabitRow: Equatable, Identifiable, Sendable {
    let habit: Habit
    let goal: Goal
    let schedule: HabitSchedule
    let quickLog: QuickLogSettings
    let placement: DayPlacement
    /// Combined subtitle: `Weekdays · 30/90 min today`.
    let caption: String
    let scheduleLabel: String
    let progressLabel: String
    let trailingAction: DayTrailingAction
    let trailingTitle: String
    let progress: Decimal
    let loggedToday: Bool
    let canUseTrailingAction: Bool
    let checklistStates: [ChecklistItemState]

    var id: UUID { habit.id }

    var isFinished: Bool {
        if case .finished = placement { return true }
        return false
    }

    var expandsChecklist: Bool {
        trailingAction == .expandChecklist
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
    let isFutureDate: Bool

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

private let weekdaySet: Set<Weekday> = [.monday, .tuesday, .wednesday, .thursday, .friday]

/// Schedule fragment shown before the progress status.
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
        if eligibleWeekdays == weekdaySet {
            return "Weekdays"
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
    switch (goal.countingMode, goal.interval) {
    case (.sessions, .week):
        return amount == "1" ? "1 time a week" : "\(amount) times a week"
    case (.days, .week):
        return amount == "1" ? "1 day a week" : "\(amount) days a week"
    case (.sessions, .month):
        return amount == "1" ? "1 time a month" : "\(amount) times a month"
    case (.days, .month):
        return amount == "1" ? "1 day a month" : "\(amount) days a month"
    case (.sessions, .year):
        return amount == "1" ? "1 time a year" : "\(amount) times a year"
    case (.days, .year):
        return amount == "1" ? "1 day a year" : "\(amount) days a year"
    case (_, .day):
        return "Every day"
    }
}

func unitSuffix(_ unitLabel: String) -> String {
    unitLabel.isEmpty ? "" : " \(unitLabel)"
}

/// Progress / status fragment, including units and counting period.
func progressLabel(
    goal: Goal,
    schedule: HabitSchedule,
    quickLog: QuickLogSettings,
    progress: Decimal,
    loggedToday: Bool,
    isFinished: Bool
) -> String {
    let timeframe = goal.interval.progressTimeframePhrase
    let unit = unitSuffix(quickLog.unitLabel)

    if isFinished {
        let target = formatGoalAmount(goal.target)
        return "\(target)/\(target)\(unit) \(timeframe)"
    }

    if goal.measurement == .boolean, progress < goal.target {
        if case .every = schedule, !loggedToday {
            return "Due today"
        }
        return "Not yet"
    }

    if case .every = schedule, progress < goal.target, !loggedToday, goal.interval == .day {
        return "Due today"
    }

    let current = formatGoalAmount(progress)
    let target = formatGoalAmount(goal.target)
    let fraction = "\(current)/\(target)\(unit) \(timeframe)"

    if loggedToday, goal.interval != .day {
        return "Logged today · \(fraction)"
    }

    return fraction
}

func dayRowCaption(scheduleLabel: String, progressLabel: String) -> String {
    "\(scheduleLabel) · \(progressLabel)"
}

func makeDayHabitRow(
    habit: Habit,
    goal: Goal,
    schedule: HabitSchedule,
    quickLog: QuickLogSettings,
    on date: Date,
    periods: [HabitPeriod],
    entries: [ProgressEntry],
    calendar: Calendar,
    now: Date = Date()
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
    let scheduleText = scheduleLabel(schedule: schedule, goal: goal)
    let progressText = progressLabel(
        goal: goal,
        schedule: schedule,
        quickLog: quickLog,
        progress: progress,
        loggedToday: loggedToday,
        isFinished: finished
    )

    return DayHabitRow(
        habit: habit,
        goal: goal,
        schedule: schedule,
        quickLog: quickLog,
        placement: placement,
        caption: dayRowCaption(scheduleLabel: scheduleText, progressLabel: progressText),
        scheduleLabel: scheduleText,
        progressLabel: progressText,
        trailingAction: dayTrailingAction(settings: quickLog),
        trailingTitle: dayTrailingTitle(settings: quickLog),
        progress: progress,
        loggedToday: loggedToday,
        canUseTrailingAction: canUseDayTrailingAction(
            goal: goal,
            settings: quickLog,
            placement: placement,
            progress: progress,
            on: date,
            now: now,
            calendar: calendar
        ),
        checklistStates: checklistItemStates(
            items: quickLog.checklistItems,
            habitID: habit.id,
            entries: entries,
            on: date,
            calendar: calendar
        )
    )
}

struct HabitDefinition: Equatable, Identifiable, Sendable {
    var habit: Habit
    var goal: Goal
    var schedule: HabitSchedule
    var quickLog: QuickLogSettings
    var notes: String

    var id: UUID { habit.id }

    init(
        habit: Habit,
        goal: Goal,
        schedule: HabitSchedule,
        quickLog: QuickLogSettings = .done(),
        notes: String = ""
    ) {
        self.habit = habit
        self.goal = goal
        self.schedule = schedule
        self.quickLog = quickLog
        self.notes = notes
    }
}

func makeDayViewSnapshot(
    definitions: [HabitDefinition],
    on date: Date,
    periods: [HabitPeriod],
    entries: [ProgressEntry],
    calendar: Calendar,
    now: Date = Date()
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
            quickLog: definition.quickLog,
            on: date,
            periods: periods,
            entries: entries,
            calendar: calendar,
            now: now
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
        scheduledTodayCount: scheduled,
        isFutureDate: isFutureDay(date: date, now: now, calendar: calendar)
    )
}
