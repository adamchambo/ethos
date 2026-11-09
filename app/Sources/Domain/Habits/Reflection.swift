import Foundation

enum ReflectionType: String, Codable, Sendable {
    case failure
    case recovery
    case weekly
}

enum ReflectionError: Error, Equatable {
    case blankResponse
    case alreadyRecorded
    case unknownReflection
}

struct Reflection: Identifiable, Equatable, Sendable, Codable {
    let id: UUID
    let periodID: UUID
    let type: ReflectionType
    let response: String
    let createdAt: Date

    init(
        id: UUID = UUID(),
        periodID: UUID,
        type: ReflectionType,
        response: String,
        createdAt: Date
    ) throws {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ReflectionError.blankResponse
        }

        self.id = id
        self.periodID = periodID
        self.type = type
        self.response = trimmed
        self.createdAt = createdAt
    }
}

/// Keeps a single reflection for a period. A second one for the same period is refused.
func recordReflection(_ reflection: Reflection, existing: [Reflection]) throws -> [Reflection] {
    guard !existing.contains(where: { $0.periodID == reflection.periodID }) else {
        throw ReflectionError.alreadyRecorded
    }
    return existing + [reflection]
}

/// Replaces the text of one reflection. Id, period, type, and creation date stay put.
func reviseReflection(id: UUID, response: String, existing: [Reflection]) throws -> [Reflection] {
    guard let index = existing.firstIndex(where: { $0.id == id }) else {
        throw ReflectionError.unknownReflection
    }

    let current = existing[index]
    let revised = try Reflection(
        id: current.id,
        periodID: current.periodID,
        type: current.type,
        response: response,
        createdAt: current.createdAt
    )
    var updated = existing
    updated[index] = revised
    return updated
}
