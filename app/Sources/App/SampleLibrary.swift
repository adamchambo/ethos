import Foundation

/// A fixed library so an empty install shows the daily loop instead of a blank Today.
struct SampleLibrary {
    var habits: [Habit]
    var periods: [HabitPeriod]
    var entries: [ProgressEntry]
    var categories: [Category]
    var reminders: [Reminder]
    var reflections: [Reflection]
    var journal: [JournalEntry]

    static func make(now: Date, calendar: Calendar) -> SampleLibrary {
        let builder = Builder(now: now, calendar: calendar)
        builder.build()
        return builder.library
    }
}

private final class Builder {
    let now: Date
    let calendar: Calendar
    var habits: [Habit] = []
    var periods: [HabitPeriod] = []
    var entries: [ProgressEntry] = []
    var categories: [Category] = []
    var reminders: [Reminder] = []
    var reflections: [Reflection] = []
    var journal: [JournalEntry] = []

    init(now: Date, calendar: Calendar) {
        self.now = now
        self.calendar = calendar
    }

    var library: SampleLibrary {
        SampleLibrary(
            habits: habits,
            periods: periods,
            entries: entries,
            categories: categories,
            reminders: reminders,
            reflections: reflections,
            journal: journal
        )
    }

    func build() {
        let health = try! Category(name: "Health", colour: "6B8F71", icon: "heart")
        let work = try! Category(name: "Work", colour: "C46E41", icon: "briefcase")
        let learning = try! Category(name: "Learning", colour: "8A7355", icon: "book")
        categories = [health, work, learning]

        let createdAt = calendar.date(byAdding: .day, value: -10, to: now)!
        let routineItems = [
            ChecklistItem(title: "Make the bed", sortOrder: 0),
            ChecklistItem(title: "Glass of water", sortOrder: 1),
            ChecklistItem(title: "Open the day's work", sortOrder: 2),
            ChecklistItem(title: "Step outside", sortOrder: 3)
        ]
        let vitamins = habit(
            "Take vitamins", createdAt: createdAt, measurement: .boolean, target: 1,
            direction: .build, time: .morning, category: health.id,
            identity: "Someone who looks after the basics.",
            accountability: AccountabilityRule(tone: .direct, consequence: .reflect, requiresConfirmation: false, isEnabled: true)
        )
        let water = habit(
            "Drink water", createdAt: createdAt, measurement: .count, target: 3,
            direction: .build, time: .none, category: health.id
        )
        let routine = habit(
            "Morning routine", createdAt: createdAt, measurement: .boolean, target: 1,
            direction: .build, time: .morning, category: health.id, checklist: routineItems
        )
        let deepWork = habit(
            "Deep work", createdAt: createdAt, measurement: .duration, target: 90,
            direction: .build, time: .morning, category: work.id,
            schedule: .weekly(eligibleWeekdays: [.monday, .tuesday, .wednesday, .thursday, .friday]),
            identity: "Someone who protects the morning for real work.",
            notes: "Ninety minutes, before messages."
        )
        let reading = habit(
            "Read", createdAt: createdAt, measurement: .quantity, target: 20,
            direction: .build, time: .evening, category: learning.id, unit: .custom("pages")
        )
        let phone = habit(
            "No phone in bed", createdAt: createdAt, measurement: .boolean, target: 0,
            direction: .quit, time: .evening, category: health.id,
            accountability: AccountabilityRule(tone: .firm, consequence: .reflect, requiresConfirmation: true, isEnabled: true)
        )
        habits = [vitamins, water, routine, deepWork, reading, phone]

        for ago in stride(from: 6, through: 1, by: -1) {
            let morning = at(daysAgo: ago, hour: 8)
            let midday = at(daysAgo: ago, hour: 12)
            let evening = at(daysAgo: ago, hour: 21)
            let weekday = isWeekday(morning)

            if ago == 5 {
                remember(vitamins, on: morning)
                remember(water, on: midday)
            } else {
                log(vitamins, amount: 1, on: morning)
                log(water, amount: 1, on: midday)
                log(water, amount: 1, on: midday.addingTimeInterval(60))
                log(water, amount: 1, on: midday.addingTimeInterval(120))
                for item in routine.checklist {
                    log(routine, amount: 1, on: morning, checklistItemID: item.id)
                }
                if weekday {
                    log(deepWork, amount: 90, on: morning)
                }
                if ago == 2 {
                    skip(reading, on: evening)
                } else {
                    log(reading, amount: 20, on: evening)
                }
            }

            if ago == 3 {
                log(phone, amount: 1, on: evening)
            } else {
                remember(phone, on: evening)
            }
        }

        let morning = at(daysAgo: 0, hour: 8)
        let midday = at(daysAgo: 0, hour: 12)
        log(vitamins, amount: 1, on: morning)
        log(water, amount: 1, on: midday)
        log(water, amount: 1, on: midday.addingTimeInterval(60))
        log(routine, amount: 1, on: morning, checklistItemID: routine.checklist[0].id)
        log(routine, amount: 1, on: morning, checklistItemID: routine.checklist[1].id)
        if isWeekday(morning) {
            log(deepWork, amount: 45, on: morning)
        }

        periods = closeExpiredPeriods(habits: habits, periods: periods, entries: entries, now: now)

        if let missed = periods.first(where: { $0.habitID == vitamins.id && $0.outcome == .failed }) {
            reflections = try! recordReflection(
                Reflection(
                    periodID: missed.id,
                    type: .failure,
                    response: "Left the bottle in the kitchen and did not go back for it.",
                    createdAt: missed.endsAt
                ),
                existing: []
            )
        }

        journal = [
            try! JournalEntry(
                dayStart: calendar.startOfDay(for: now),
                text: "Vitamins are done. Water and the morning routine are only part way.",
                createdAt: now
            )
        ]
        reminders = [
            try! Reminder(habitID: vitamins.id, time: ClockTime(hour: 8, minute: 0))
        ]
    }

    private func habit(
        _ title: String,
        createdAt: Date,
        measurement: GoalMeasurement,
        target: Decimal,
        direction: HabitDirection,
        time: TimeOfDay,
        category: UUID,
        schedule: HabitSchedule = .daily,
        identity: String? = nil,
        notes: String? = nil,
        checklist: [ChecklistItem] = [],
        unit: GoalUnit? = nil,
        accountability: AccountabilityRule? = nil
    ) -> Habit {
        try! Habit(
            title: title,
            createdAt: createdAt,
            goal: Goal(measurement: measurement, target: target, interval: .day, unit: unit),
            schedule: schedule,
            direction: direction,
            timeOfDay: time,
            identityStatement: identity,
            notes: notes,
            categoryID: category,
            checklist: checklist,
            accountability: accountability
        )
    }

    private func at(daysAgo: Int, hour: Int) -> Date {
        let day = calendar.date(byAdding: .day, value: -daysAgo, to: now)!
        return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day)!
    }

    private func isWeekday(_ date: Date) -> Bool {
        guard let weekday = Weekday(foundationWeekday: calendar.component(.weekday, from: date)) else {
            return false
        }
        return (Weekday.monday.rawValue...Weekday.friday.rawValue).contains(weekday.rawValue)
    }

    private func remember(_ habit: Habit, on date: Date) {
        guard let period = resolvePeriod(habit: habit, on: date, existing: periods, calendar: calendar),
              !periods.contains(where: { $0.id == period.id })
        else { return }
        periods.append(period)
    }

    private func log(_ habit: Habit, amount: Decimal, on date: Date, checklistItemID: UUID? = nil) {
        let result = try! logProgress(
            habit: habit,
            amount: amount,
            on: date,
            existingPeriods: periods,
            existingEntries: entries,
            calendar: calendar,
            checklistItemID: checklistItemID
        )
        guard let result else { return }
        if let index = periods.firstIndex(where: { $0.id == result.period.id }) {
            periods[index] = result.period
        } else {
            periods.append(result.period)
        }
        entries = result.entries
    }

    private func skip(_ habit: Habit, on date: Date) {
        remember(habit, on: date)
        guard let index = periods.firstIndex(where: {
            $0.habitID == habit.id && $0.startsAt <= date && date < $0.endsAt
        }) else { return }
        try! periods[index].skip()
    }
}
