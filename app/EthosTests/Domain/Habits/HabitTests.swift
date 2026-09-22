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
            try Habit(title: "   ", createdAt: .now)
        }
    }

    @Test
    func creationTrimsTheTitle() throws {
        let habit = try Habit(title: "  Read  ", createdAt: .now)

        #expect(habit.title == "Read")
    }

    @Test
    func anActiveHabitCanPause() throws {
        var habit = try Habit(title: "Read", createdAt: .now)

        habit.pause()

        #expect(habit.lifecycle == .paused)
        #expect(!habit.isActive)
    }

    @Test
    func aPausedHabitCanResume() throws {
        var habit = try Habit(title: "Read", createdAt: .now)
        habit.pause()

        try habit.resume()

        #expect(habit.lifecycle == .active)
        #expect(habit.isActive)
    }

    @Test
    func anArchivedHabitCannotResume() throws {
        var habit = try Habit(title: "Read", createdAt: .now)
        habit.archive()

        #expect(throws: HabitError.cannotResumeArchivedHabit) {
            try habit.resume()
        }
    }
}
