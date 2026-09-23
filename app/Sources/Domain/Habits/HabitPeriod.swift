import Foundation

enum HabitPeriodOutcome: String, Codable, Sendable {
    case inProgress
    case succeeded
    case failed
    case skipped
}

enum HabitPeriodError: Error, Equatable {
    case invalidDateRange
    case alreadyFinalized
    case cannotFinalizeAsInProgress
}

/// The evaluation window for a habit. Its outcome remains provisional until finalized.
struct HabitPeriod: Identifiable, Equatable, Sendable {
    let id: UUID
    let habitID: UUID
    let startsAt: Date
    let endsAt: Date
    private(set) var outcome: HabitPeriodOutcome

    init(
        id: UUID = UUID(),
        habitID: UUID,
        startsAt: Date,
        endsAt: Date,
        outcome: HabitPeriodOutcome = .inProgress
    ) throws {
        guard startsAt < endsAt else {
            throw HabitPeriodError.invalidDateRange
        }

        self.id = id
        self.habitID = habitID
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.outcome = outcome
    }

    var isFinalized: Bool {
        outcome != .inProgress
    }

    mutating func finalize(as outcome: HabitPeriodOutcome) throws {
        guard !isFinalized else {
            throw HabitPeriodError.alreadyFinalized
        }

        guard outcome != .inProgress else {
            throw HabitPeriodError.cannotFinalizeAsInProgress
        }

        self.outcome = outcome
    }
}
