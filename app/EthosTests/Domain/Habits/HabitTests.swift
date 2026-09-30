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
