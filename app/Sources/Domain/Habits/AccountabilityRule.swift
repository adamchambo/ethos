import Foundation

enum AccountabilityTone: String, Codable, Sendable, CaseIterable {
    case calm
    case direct
    case firm
}

enum AccountabilityConsequence: String, Codable, Sendable, CaseIterable {
    case none
    case reflect
    case recoveryAction
    case directFeedback
}

/// Local accountability for one habit. Financial and social consequences are deferred.
struct AccountabilityRule: Equatable, Codable, Sendable {
    var tone: AccountabilityTone
    var consequence: AccountabilityConsequence
    var requiresConfirmation: Bool
    var isEnabled: Bool
    var recoveryAction: String?

    init(
        tone: AccountabilityTone,
        consequence: AccountabilityConsequence,
        requiresConfirmation: Bool,
        isEnabled: Bool,
        recoveryAction: String? = nil
    ) {
        self.tone = tone
        self.consequence = consequence
        self.requiresConfirmation = requiresConfirmation
        self.isEnabled = isEnabled
        self.recoveryAction = recoveryAction
    }
}
