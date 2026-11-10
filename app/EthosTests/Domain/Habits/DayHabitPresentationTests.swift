import Foundation
import Testing
@testable import Ethos

struct DayHabitPresentationTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    @Test
    func scheduleLabelsCoverDailyWeeklyFixedAndInterval() throws {
        let habitID = UUID()
        let daily = try Goal(habitID: habitID, measurement: .count, target: 1, interval: .day)
        let weeklySessions = try Goal(
            habitID: habitID, measurement: .count, target: 5, interval: .week, countingMode: .sessions
        )
        let weeklyDays = try Goal(
            habitID: habitID, measurement: .count, target: 5, interval: .week, countingMode: .days
        )

        #expect(scheduleLabel(schedule: .daily, goal: daily) == "Every day")
        #expect(
            scheduleLabel(schedule: .weekly(eligibleWeekdays: []), goal: weeklySessions)
                == "5 times a week"
        )
        #expect(
            scheduleLabel(schedule: .daily, goal: weeklyDays)
                == "5 days a week"
        )
        #expect(
            scheduleLabel(
                schedule: .weekly(eligibleWeekdays: [.monday, .wednesday, .friday]),
                goal: daily
            ) == "Mon, Wed, Fri"
        )
        #expect(
            scheduleLabel(
                schedule: .weekly(eligibleWeekdays: [
                    .monday, .tuesday, .wednesday, .thursday, .friday
                ]),
                goal: daily
            ) == "Weekdays"
        )
        #expect(
            scheduleLabel(
                schedule: .every(days: 3, anchorStart: date(2026, 11, 1)),
                goal: daily
            ) == "Every 3 days"
        )
    }

    @Test
    func captionsMatchDayRowExamples() throws {
        let day = date(2026, 11, 10)
        let deepWork = try Habit(title: "Deep work", createdAt: day, dayPart: .afternoon)
        let deepGoal = try Goal(
            habitID: deepWork.id, measurement: .duration, target: 90, interval: .day
        )
        let deepRow = try #require(makeDayHabitRow(
            habit: deepWork,
            goal: deepGoal,
            schedule: .weekly(eligibleWeekdays: [
                .monday, .tuesday, .wednesday, .thursday, .friday
            ]),
            quickLog: .increment(15, unitLabel: "min"),
            on: day,
            periods: [],
            entries: [
                try ProgressEntry(habitID: deepWork.id, occurredAt: day, amount: 30)
            ],
            calendar: calendar,
            now: day
        ))
        #expect(deepRow.caption == "Weekdays · 30/90 min today")
        #expect(deepRow.quickActionTitle == "+15 min")

        let exercise = try Habit(title: "Exercise", createdAt: day, dayPart: .afternoon)
        let exerciseGoal = try Goal(
            habitID: exercise.id, measurement: .count, target: 5, interval: .week
        )
        let monday = date(2026, 11, 9)
        let exerciseRow = try #require(makeDayHabitRow(
            habit: exercise,
            goal: exerciseGoal,
            schedule: .weekly(eligibleWeekdays: []),
            quickLog: .increment(1),
            on: day,
            periods: [],
            entries: [
                try ProgressEntry(habitID: exercise.id, occurredAt: monday, amount: 2),
                try ProgressEntry(habitID: exercise.id, occurredAt: day, amount: 1)
            ],
            calendar: calendar,
            now: day
        ))
        #expect(exerciseRow.caption == "5 times a week · Logged today · 3/5 this week")
        #expect(exerciseRow.quickActionTitle == "+1")

        let vitamins = try Habit(title: "Take vitamins", createdAt: day, dayPart: .morning)
        let vitaminsRow = try #require(makeDayHabitRow(
            habit: vitamins,
            goal: try Goal(habitID: vitamins.id, measurement: .boolean, target: 1, interval: .day),
            schedule: .daily,
            quickLog: .done(),
            on: day,
            periods: [],
            entries: [],
            calendar: calendar,
            now: day
        ))
        #expect(vitaminsRow.caption == "Every day · Not yet")
        #expect(vitaminsRow.quickActionTitle == "Done")

        let plants = try Habit(title: "Water plants", createdAt: day, dayPart: .anytime)
        let plantsRow = try #require(makeDayHabitRow(
            habit: plants,
            goal: try Goal(habitID: plants.id, measurement: .boolean, target: 1, interval: .day),
            schedule: .every(days: 3, anchorStart: day),
            quickLog: .done(),
            on: day,
            periods: [],
            entries: [],
            calendar: calendar,
            now: day
        ))
        #expect(plantsRow.caption == "Every 3 days · Due today")
        #expect(plantsRow.quickActionTitle == "Done")
    }

    @Test
    func quitHabitsUseSlipAction() throws {
        let day = date(2026, 11, 10)
        let habit = try Habit(title: "No phone in bed", createdAt: day, dayPart: .evening)
        let row = try #require(makeDayHabitRow(
            habit: habit,
            goal: try Goal(habitID: habit.id, measurement: .boolean, target: 1, interval: .day),
            schedule: .daily,
            quickLog: .slip(),
            on: day,
            periods: [],
            entries: [],
            calendar: calendar,
            now: day
        ))
        #expect(row.quickActionTitle == "Slip")
    }

    @Test
    func futureDatesDisableQuickLog() throws {
        let today = date(2026, 11, 10)
        let tomorrow = date(2026, 11, 11)
        let habit = try Habit(title: "Read", createdAt: today, dayPart: .evening)
        let row = try #require(makeDayHabitRow(
            habit: habit,
            goal: try Goal(habitID: habit.id, measurement: .count, target: 1, interval: .day),
            schedule: .daily,
            quickLog: .done(),
            on: tomorrow,
            periods: [],
            entries: [],
            calendar: calendar,
            now: today
        ))
        #expect(!row.canQuickLog)
        #expect(isFutureDay(date: tomorrow, now: today, calendar: calendar))
    }

    @Test
    func flexibleWeeklyStaysVisibleUntilTargetThenMovesToFinished() throws {
        let monday = date(2026, 11, 9)
        let tuesday = date(2026, 11, 10)
        let habit = try Habit(title: "Exercise", createdAt: monday, dayPart: .afternoon)
        let goal = try Goal(
            habitID: habit.id,
            measurement: .count,
            target: 2,
            interval: .week,
            countingMode: .sessions
        )
        let schedule = HabitSchedule.weekly(eligibleWeekdays: [])
        let first = try ProgressEntry(habitID: habit.id, occurredAt: monday, amount: 1)

        let open = try #require(makeDayHabitRow(
            habit: habit, goal: goal, schedule: schedule, quickLog: .increment(1),
            on: tuesday, periods: [], entries: [first], calendar: calendar, now: tuesday
        ))
        #expect(open.placement == .inProgress(.afternoon))
        #expect(open.progressLabel == "1/2 this week")
        #expect(!countsAsDailyCommitment(goal: goal))

        let second = try ProgressEntry(habitID: habit.id, occurredAt: tuesday, amount: 1)
        let done = try #require(makeDayHabitRow(
            habit: habit, goal: goal, schedule: schedule, quickLog: .increment(1),
            on: tuesday, periods: [], entries: [first, second], calendar: calendar, now: tuesday
        ))
        #expect(done.placement == .finished)
        #expect(done.progressLabel == "2/2 this week")
    }

    @Test
    func daySnapshotKeepsGroupsAndExcludesFlexibleWeeklyFromDailyOpenCount() throws {
        let day = date(2026, 11, 10)
        let morning = try Habit(title: "Vitamins", createdAt: day, dayPart: .morning)
        let exercise = try Habit(title: "Exercise", createdAt: day, dayPart: .afternoon)
        let definitions = [
            HabitDefinition(
                habit: morning,
                goal: try Goal(habitID: morning.id, measurement: .count, target: 1, interval: .day),
                schedule: .daily,
                quickLog: .done()
            ),
            HabitDefinition(
                habit: exercise,
                goal: try Goal(
                    habitID: exercise.id,
                    measurement: .count,
                    target: 5,
                    interval: .week
                ),
                schedule: .weekly(eligibleWeekdays: []),
                quickLog: .increment(1)
            )
        ]

        let snapshot = makeDayViewSnapshot(
            definitions: definitions,
            on: day,
            periods: [],
            entries: [],
            calendar: calendar,
            now: day
        )

        #expect(snapshot.morning.map(\.habit.title) == ["Vitamins"])
        #expect(snapshot.afternoon.map(\.habit.title) == ["Exercise"])
        #expect(snapshot.scheduledTodayCount == 2)
        #expect(snapshot.unfinishedDailyCommitments == 1)
        #expect(snapshot.morning[0].scheduleLabel == "Every day")
        #expect(snapshot.afternoon[0].caption == "5 times a week · 0/5 this week")
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
