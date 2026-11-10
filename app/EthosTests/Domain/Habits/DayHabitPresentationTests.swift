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
    func captionsAndTrailingActionsMatchCheckOffModel() throws {
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
            quickLog: .done(unitLabel: "min"),
            on: day,
            periods: [],
            entries: [
                try ProgressEntry(habitID: deepWork.id, occurredAt: day, amount: 30)
            ],
            calendar: calendar,
            now: day
        ))
        #expect(deepRow.caption == "Weekdays · 30/90 min today")
        #expect(deepRow.trailingTitle == "Done")
        #expect(remainingToComplete(goal: deepGoal, progress: 30) == 60)

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
        #expect(vitaminsRow.trailingTitle == "Done")

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
        #expect(plantsRow.trailingTitle == "Done")
    }

    @Test
    func checklistItemsStayVisibleWhenComplete() throws {
        let day = date(2026, 11, 10)
        let makeBed = ChecklistItem(title: "Make bed")
        let stretch = ChecklistItem(title: "Stretch")
        let habit = try Habit(title: "Morning routine", createdAt: day, dayPart: .morning)
        let goal = try Goal(habitID: habit.id, measurement: .count, target: 2, interval: .day)
        let entry = try ProgressEntry(
            habitID: habit.id,
            occurredAt: day,
            amount: 1,
            checklistItemID: makeBed.id
        )

        let states = checklistItemStates(
            items: [makeBed, stretch],
            habitID: habit.id,
            entries: [entry],
            on: day,
            calendar: calendar
        )
        #expect(states.count == 2)
        #expect(states[0].isComplete)
        #expect(!states[1].isComplete)

        let row = try #require(makeDayHabitRow(
            habit: habit,
            goal: goal,
            schedule: .daily,
            quickLog: .checklist([makeBed, stretch]),
            on: day,
            periods: [],
            entries: [entry],
            calendar: calendar,
            now: day
        ))
        #expect(row.trailingAction == .expandChecklist)
        #expect(row.checklistStates.map(\.isComplete) == [true, false])
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
        #expect(row.trailingTitle == "Slip")
    }

    @Test
    func futureDatesDisableTrailingActions() throws {
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
        #expect(!row.canUseTrailingAction)
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
            habit: habit, goal: goal, schedule: schedule, quickLog: .done(),
            on: tuesday, periods: [], entries: [first], calendar: calendar, now: tuesday
        ))
        #expect(open.placement == .inProgress(.afternoon))
        #expect(open.progressLabel == "1/2 this week")

        let second = try ProgressEntry(habitID: habit.id, occurredAt: tuesday, amount: 1)
        let done = try #require(makeDayHabitRow(
            habit: habit, goal: goal, schedule: schedule, quickLog: .done(),
            on: tuesday, periods: [], entries: [first, second], calendar: calendar, now: tuesday
        ))
        #expect(done.placement == .finished)
        #expect(done.progressLabel == "2/2 this week")
    }

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }
}
