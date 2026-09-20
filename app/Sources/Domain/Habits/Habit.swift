import Foundation

enum HabitLifecycle: String, Codable, Sendable {
    case active
    case paused
    case archived
}

enum HabitError: Error, Equatable {
    case blankTitle
    case cannotResumeArchivedHabit
}

struct Habit: Identifiable, Equatable, Sendable {
    let id: UUID
    let createdAt: Date
    private(set) var title: String
    private(set) var lifecycle: HabitLifecycle

    init(
        id: UUID = UUID(),
        title: String,
        createdAt: Date,
        lifecycle: HabitLifecycle = .active
    ) throws {
        let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedTitle.isEmpty else {
            throw HabitError.blankTitle
        }

        self.id = id
        self.title = normalizedTitle
        self.createdAt = createdAt
        self.lifecycle = lifecycle
    }

    var isActive: Bool {
        lifecycle == .active
    }

    mutating func rename(to newTitle: String) throws {
        let normalizedTitle = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedTitle.isEmpty else {
            throw HabitError.blankTitle
        }

        title = normalizedTitle
    }

    mutating func pause() {
        guard lifecycle == .active else { return }
        lifecycle = .paused
    }

    mutating func resume() throws {
        guard lifecycle != .archived else {
            throw HabitError.cannotResumeArchivedHabit
        }

        lifecycle = .active
    }

    mutating func archive() {
        lifecycle = .archived
    }
}
