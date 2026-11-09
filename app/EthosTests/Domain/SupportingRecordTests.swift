import Foundation
import Testing
@testable import Ethos

struct SupportingRecordTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    @Test
    func aProfileDefaultsToMondayAndACategoryRejectsABlankName() throws {
        let profile = LocalProfile(displayName: "  Adam  ")
        #expect(profile.displayName == "Adam")
        #expect(profile.weekStart == .monday)

        let category = try Category(name: " Health ", colour: "#445566", icon: "heart")
        #expect(category.name == "Health")
        #expect(throws: CategoryError.blankName) {
            try Category(name: " ", colour: "#445566", icon: "heart")
        }
    }

    @Test
    func aPeriodKeepsOneReflectionAndADayKeepsOneJournalEntry() throws {
        let periodID = UUID()
        let now = Date(timeIntervalSinceReferenceDate: 50_000)
        let reflection = try Reflection(
            periodID: periodID,
            type: .failure,
            response: " I skipped the gym ",
            createdAt: now
        )
        let recorded = try recordReflection(reflection, existing: [])

        #expect(recorded[0].response == "I skipped the gym")
        #expect(throws: ReflectionError.alreadyRecorded) {
            try recordReflection(reflection, existing: recorded)
        }

        let day = calendar.date(from: DateComponents(year: 2026, month: 10, day: 17, hour: 15))!
        let entry = try recordJournalEntry(
            text: " A long day ",
            on: day,
            existing: [],
            calendar: calendar,
            createdAt: now
        )
        #expect(entry.text == "A long day")
        #expect(entry.dayStart == calendar.startOfDay(for: day))
        #expect(throws: JournalError.alreadyRecorded) {
            try recordJournalEntry(text: "Again", on: day, existing: [entry], calendar: calendar, createdAt: now)
        }
    }

    @Test
    func aReminderIsDueAtItsTimeAndOnItsRepeatInterval() throws {
        let monday = calendar.date(from: DateComponents(year: 2026, month: 9, day: 21, hour: 7))!
        var reminder = Reminder(
            habitID: UUID(),
            time: try ClockTime(hour: 7, minute: 0),
            weekdays: [.monday],
            repeatIntervalMinutes: 30,
            stopsWhenTargetReached: true
        )

        #expect(reminder.isDue(on: monday, calendar: calendar, targetReached: false))
        #expect(reminder.isDue(
            on: monday.addingTimeInterval(30 * 60),
            calendar: calendar,
            targetReached: false
        ))
        #expect(!reminder.isDue(on: monday, calendar: calendar, targetReached: true))
        #expect(!reminder.isDue(
            on: monday.addingTimeInterval(86_400),
            calendar: calendar,
            targetReached: false
        ))

        reminder.skipNext = true
        #expect(!reminder.isDue(on: monday, calendar: calendar, targetReached: false))
    }

    @Test
    func accountabilityStaysOnTheHabitThatConfiguresIt() throws {
        var habit = try Habit(
            title: "Read",
            createdAt: .now,
            goal: try Goal(measurement: .count, target: 1, interval: .day),
            schedule: .daily
        )
        let rule = AccountabilityRule(
            tone: .direct,
            consequence: .reflect,
            requiresConfirmation: true,
            isEnabled: true
        )

        habit.setAccountability(rule)

        #expect(habit.accountability == rule)
        #expect(rule.recoveryAction == nil)
    }

    @Test
    func anOldAccountabilityRuleDecodesWithoutARecoveryAction() throws {
        let json = """
        {"tone":"calm","consequence":"reflect","requiresConfirmation":false,"isEnabled":true}
        """.data(using: .utf8)!

        let rule = try JSONDecoder().decode(AccountabilityRule.self, from: json)

        #expect(rule.tone == .calm)
        #expect(rule.consequence == .reflect)
        #expect(rule.recoveryAction == nil)

        let roundTrip = try JSONDecoder().decode(
            AccountabilityRule.self,
            from: JSONEncoder().encode(AccountabilityRule(
                tone: .firm,
                consequence: .recoveryAction,
                requiresConfirmation: true,
                isEnabled: true,
                recoveryAction: "Walk around the block"
            ))
        )
        #expect(roundTrip.recoveryAction == "Walk around the block")
    }

    @Test
    func revisingAReflectionKeepsItsIdentityAndRejectsBlankOrUnknown() throws {
        let createdAt = Date(timeIntervalSinceReferenceDate: 50_000)
        let original = try Reflection(
            periodID: UUID(),
            type: .failure,
            response: "Left it until later",
            createdAt: createdAt
        )
        let other = try Reflection(
            periodID: UUID(),
            type: .weekly,
            response: "A different note",
            createdAt: createdAt.addingTimeInterval(10)
        )

        let revised = try reviseReflection(id: original.id, response: " Went back for it ", existing: [original, other])

        #expect(revised[0].id == original.id)
        #expect(revised[0].periodID == original.periodID)
        #expect(revised[0].type == .failure)
        #expect(revised[0].createdAt == createdAt)
        #expect(revised[0].response == "Went back for it")
        #expect(revised[1] == other)
        #expect(throws: ReflectionError.blankResponse) {
            try reviseReflection(id: original.id, response: "  ", existing: [original])
        }
        #expect(throws: ReflectionError.unknownReflection) {
            try reviseReflection(id: UUID(), response: "Still here", existing: [original])
        }
    }
}
