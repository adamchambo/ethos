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
                == "5 times a week · Any day"
        )
        #expect(
            scheduleLabel(schedule: .daily, goal: weeklyDays)
                == "5 days a week · Any day"
        )
        #expect(
            scheduleLabel(
                schedule: .weekly(eligibleWeekdays: [.monday, .wednesday, .friday]),
                goal: daily
            ) == "Mon, Wed, Fri"
        )
        #expect(
            scheduleLabel(
                schedule: .every(days: 3, anchorStart: date(2026, 11, 1)),
                goal: daily
            ) == "Every 3 days"
        )
    }

    @Test
    func progressLabelsIncludeTimeframeAndLoggedToday() throws {
        let habitID = UUID()
        let weekly = try Goal(habitID: habitID, measurement: .count, target: 5, interval: .week)
        let daily = try Goal(habitID: habitID, measurement: .count, target: 3, interval: .day)

        #expect(progressLabel(
            goal: weekly, progress: 3, loggedToday: false, isFinished: false
        ) == "3/5 this week")
        #expect(progressLabel(
            goal: weekly, progress: 3, loggedToday: true, isFinished: false
        ) == "Logged today · 3/5 this week")
        #expect(progressLabel(
            goal: weekly, progress: 5, loggedToday: true, isFinished: true
        ) == "5/5 this week")
        #expect(progressLabel(
            goal: daily, progress: 2, loggedToday: true, isFinished: false
        ) == "2/3 today")
    }

    @Test
    func flexibleWeeklyStaysVisibleUntilTargetThenMovesToFinished() throws {
        let monday = date(2026, 11, 9)
        let tuesday = date(2026, 11, 10)
        let habit = try Habit(
            title: "Exercise",
            createdAt: monday,
            dayPart: .afternoon
        )
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
            habit: habit, goal: goal, schedule: schedule, on: tuesday,
            periods: [], entries: [first], calendar: calendar
        ))
        #expect(open.placement == .inProgress(.afternoon))
        // First entry is Monday; Tuesday should not say "Logged today".
        #expect(open.progressLabel == "1/2 this week")
        #expect(!countsAsDailyCommitment(goal: goal))

        let second = try ProgressEntry(habitID: habit.id, occurredAt: tuesday, amount: 1)
        let done = try #require(makeDayHabitRow(
            habit: habit, goal: goal, schedule: schedule, on: tuesday,
            periods: [], entries: [first, second], calendar: calendar
        ))
        #expect(done.placement == .finished)
        #expect(done.progressLabel == "2/2 this week")
    }

    @Test
    func fixedWeekdaysAndIntervalHabitsOnlyAppearWhenDue() throws {
        let monday = date(2026, 11, 9)
        let tuesday = date(2026, 11, 10)
        let habit = try Habit(title: "Deep work", createdAt: monday, dayPart: .afternoon)
        let goal = try Goal(habitID: habit.id, measurement: .count, target: 1, interval: .day)
        let fixed = HabitSchedule.weekly(eligibleWeekdays: [.monday, .wednesday, .friday])

        #expect(makeDayHabitRow(
            habit: habit, goal: goal, schedule: fixed, on: monday,
            periods: [], entries: [], calendar: calendar
        ) != nil)
        #expect(makeDayHabitRow(
            habit: habit, goal: goal, schedule: fixed, on: tuesday,
            periods: [], entries: [], calendar: calendar
        ) == nil)

        let interval = HabitSchedule.every(days: 3, anchorStart: monday)
        #expect(makeDayHabitRow(
            habit: habit, goal: goal, schedule: interval, on: monday,
            periods: [], entries: [], calendar: calendar
        ) != nil)
        #expect(makeDayHabitRow(
            habit: habit, goal: goal, schedule: interval, on: tuesday,
            periods: [], entries: [], calendar: calendar
        ) == nil)
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
                schedule: .daily
            ),
            HabitDefinition(
                habit: exercise,
                goal: try Goal(
                    habitID: exercise.id,
                    measurement: .count,
                    target: 5,
                    interval: .week
                ),
                schedule: .weekly(eligibleWeekdays: [])
            )
        ]

        let snapshot = makeDayViewSnapshot(
            definitions: definitions,
            on: day,
            periods: [],
            entries: [],
            calendar: calendar
        )

        #expect(snapshot.morning.map(\.habit.title) == ["Vitamins"])
        #expect(snapshot.afternoon.map(\.habit.title) == ["Exercise"])
        #expect(snapshot.scheduledTodayCount == 2)
        #expect(snapshot.unfinishedDailyCommitments == 1)
        #expect(snapshot.morning[0].scheduleLabel == "Every day")
        #expect(snapshot.afternoon[0].scheduleLabel == "5 times a week · Any day")
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
