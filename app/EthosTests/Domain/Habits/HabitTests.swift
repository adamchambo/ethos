//
//  HabitTests.swift
//  EthosTests
//
//  Created by Adam on 21/9/2026.
//

import Foundation
import Testing
@testable import Ethos

struct HabitTests {
    @Test
    func creationRejectsABlankTitle() {
        #expect(throws: HabitError.blankTitle) {
            try Habit(title: "   ", createdAt: .now, goal: try makeGoal(), schedule: .daily)
        }
    }

    @Test
    func creationTrimsTheTitleAndKeepsItsGoalAndSchedule() throws {
        let goal = try makeGoal()
        let habit = try Habit(title: "  Read  ", createdAt: .now, goal: goal, schedule: .daily)

        #expect(habit.title == "Read")
        #expect(habit.goal == goal)
        #expect(habit.schedule == .daily)
    }

    @Test
    func anActiveHabitCanPause() throws {
        var habit = try makeHabit()

        habit.pause()

        #expect(habit.lifecycle == .paused)
        #expect(!habit.isActive)
    }

    @Test
    func aPausedHabitCanResume() throws {
        var habit = try makeHabit()
        habit.pause()

        try habit.resume()

        #expect(habit.lifecycle == .active)
        #expect(habit.isActive)
    }

    @Test
    func aBuildHabitRejectsAZeroTargetButAQuitHabitAllowsIt() throws {
        let avoid = try Goal(measurement: .count, target: 0, interval: .day)

        #expect(throws: HabitError.nonPositiveBuildTarget) {
            try Habit(title: "Read", createdAt: .now, goal: avoid, schedule: .daily)
        }

        let quit = try Habit(
            title: "Smoking",
            createdAt: .now,
            goal: avoid,
            schedule: .daily,
            direction: .quit
        )
        #expect(quit.direction == .quit)
        #expect(quit.goal.target == 0)
    }

    @Test
    func changingTheGoalLeavesAnExistingPeriodAlone() throws {
        var habit = try makeHabit()
        let period = try HabitPeriod(
            habitID: habit.id,
            startsAt: habit.createdAt,
            endsAt: habit.createdAt.addingTimeInterval(86_400),
            outcome: .succeeded
        )
        let replacement = try Goal(measurement: .count, target: 4, interval: .week)

        try habit.changeGoal(to: replacement)

        #expect(habit.goal == replacement)
        #expect(period.outcome == .succeeded)
    }

    @Test
    func creationRejectsAnEndDateThatIsNotAfterTheStart() throws {
        let start = Date(timeIntervalSinceReferenceDate: 1_000)

        #expect(throws: HabitError.endDateNotAfterStartDate) {
            try Habit(
                title: "Read",
                createdAt: start,
                goal: try makeGoal(),
                schedule: .daily,
                endDate: start
            )
        }
    }

    @Test
    func creationRejectsACustomTimeThatDoesNotMoveForward() throws {
        #expect(throws: HabitError.invalidTimeRange) {
            try Habit(
                title: "Read",
                createdAt: .now,
                goal: try makeGoal(),
                schedule: .daily,
                timeOfDay: .custom(
                    start: try ClockTime(hour: 10, minute: 0),
                    end: try ClockTime(hour: 9, minute: 0)
                )
            )
        }
    }

    @Test
    func blankIdentityAndNotesAreStoredAsNothing() throws {
        let habit = try Habit(
            title: "Read",
            createdAt: .now,
            goal: try makeGoal(),
            schedule: .daily,
            identityStatement: "  ",
            notes: "  "
        )

        #expect(habit.identityStatement == nil)
        #expect(habit.notes == nil)
        #expect(habit.startDate == habit.createdAt)
    }

    @Test
    func anArchivedHabitCannotResume() throws {
        var habit = try makeHabit()
        habit.archive()

        #expect(throws: HabitError.cannotResumeArchivedHabit) {
            try habit.resume()
        }
    }

    private func makeHabit() throws -> Habit {
        try Habit(title: "Read", createdAt: .now, goal: try makeGoal(), schedule: .daily)
    }

    private func makeGoal() throws -> Goal {
        try Goal(measurement: .count, target: 1, interval: .day)
    }
}
