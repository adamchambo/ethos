import Foundation

enum DayViewDemo {
    static func definitions(reference: Date, calendar: Calendar = .current) -> [HabitDefinition] {
        let createdAt = calendar.startOfDay(for: reference)

        return [
            definition(
                id: 1,
                title: "Morning routine",
                createdAt: createdAt,
                dayPart: .morning,
                measurement: .count,
                target: 3,
                interval: .day,
                schedule: .daily,
                quickLog: .checklist([
                    ChecklistItem(title: "Make bed"),
                    ChecklistItem(title: "Stretch"),
                    ChecklistItem(title: "Plan day")
                ])
            ),
            definition(
                id: 2,
                title: "Take vitamins",
                createdAt: createdAt,
                dayPart: .morning,
                measurement: .boolean,
                target: 1,
                interval: .day,
                schedule: .daily,
                quickLog: .done()
            ),
            definition(
                id: 3,
                title: "Deep work",
                createdAt: createdAt,
                dayPart: .afternoon,
                measurement: .duration,
                target: 90,
                interval: .day,
                schedule: .weekly(eligibleWeekdays: [
                    .monday, .tuesday, .wednesday, .thursday, .friday
                ]),
                quickLog: .done(unitLabel: "min", allowBeyond: true)
            ),
            definition(
                id: 4,
                title: "Exercise",
                createdAt: createdAt,
                dayPart: .afternoon,
                measurement: .count,
                target: 5,
                interval: .week,
                countingMode: .sessions,
                schedule: .weekly(eligibleWeekdays: []),
                quickLog: .done()
            ),
            definition(
                id: 5,
                title: "No phone in bed",
                createdAt: createdAt,
                dayPart: .evening,
                measurement: .boolean,
                target: 1,
                interval: .day,
                schedule: .daily,
                quickLog: .slip()
            ),
            definition(
                id: 6,
                title: "Read",
                createdAt: createdAt,
                dayPart: .evening,
                measurement: .quantity,
                target: 20,
                interval: .day,
                schedule: .daily,
                quickLog: .done(unitLabel: "pages")
            ),
            definition(
                id: 7,
                title: "Drink water",
                createdAt: createdAt,
                dayPart: .anytime,
                measurement: .count,
                target: 3,
                interval: .day,
                schedule: .daily,
                quickLog: .done()
            ),
            definition(
                id: 8,
                title: "Water plants",
                createdAt: createdAt,
                dayPart: .anytime,
                measurement: .boolean,
                target: 1,
                interval: .day,
                schedule: .every(days: 3, anchorStart: createdAt),
                quickLog: .done()
            )
        ]
    }

    static func snapshot(
        reference: Date,
        periods: [HabitPeriod] = [],
        entries: [ProgressEntry] = [],
        calendar: Calendar = .current
    ) -> DayViewSnapshot {
        makeDayViewSnapshot(
            definitions: definitions(reference: reference, calendar: calendar),
            on: reference,
            periods: periods,
            entries: entries,
            calendar: calendar
        )
    }

    private static func definition(
        id: Int,
        title: String,
        createdAt: Date,
        dayPart: DayPart,
        measurement: GoalMeasurement,
        target: Decimal,
        interval: GoalInterval,
        countingMode: GoalCountingMode = .sessions,
        schedule: HabitSchedule,
        quickLog: QuickLogSettings
    ) -> HabitDefinition {
        let habitID = placeholderID(id)
        return HabitDefinition(
            habit: try! Habit(
                id: habitID,
                title: title,
                createdAt: createdAt,
                dayPart: dayPart
            ),
            goal: try! Goal(
                habitID: habitID,
                measurement: measurement,
                target: target,
                interval: interval,
                countingMode: countingMode
            ),
            schedule: schedule,
            quickLog: quickLog
        )
    }

    private static func placeholderID(_ value: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", value))!
    }
}
