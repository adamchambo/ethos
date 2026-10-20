import Foundation

enum CategoryError: Error, Equatable {
    case blankName
    case blankColour
    case blankIcon
}

struct Category: Identifiable, Equatable, Sendable {
    let id: UUID
    var name: String
    var colour: String
    var icon: String

    init(id: UUID = UUID(), name: String, colour: String, icon: String) throws {
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedColour = colour.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedIcon = icon.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !normalizedName.isEmpty else { throw CategoryError.blankName }
        guard !normalizedColour.isEmpty else { throw CategoryError.blankColour }
        guard !normalizedIcon.isEmpty else { throw CategoryError.blankIcon }

        self.id = id
        self.name = normalizedName
        self.colour = normalizedColour
        self.icon = normalizedIcon
    }
}
