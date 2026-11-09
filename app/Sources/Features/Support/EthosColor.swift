import SwiftUI

/// The starting palette from the visual design notes: charcoal, warm paper, one copper accent.
/// Success, attention, and failure stay muted, and status is also written in words.
enum EthosColor {
    static let accent = Color(red: 0.769, green: 0.431, blue: 0.255)
    static let success = Color(red: 0.420, green: 0.561, blue: 0.443)
    static let attention = Color(red: 0.769, green: 0.545, blue: 0.275)
    static let failure = Color(red: 0.647, green: 0.286, blue: 0.227)

    static func canvas(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.102, green: 0.090, blue: 0.082)
            : Color(red: 0.965, green: 0.949, blue: 0.918)
    }

    static func surface(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.157, green: 0.141, blue: 0.125)
            : Color(red: 0.992, green: 0.980, blue: 0.961)
    }

    static func ink(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.965, green: 0.949, blue: 0.918)
            : Color(red: 0.122, green: 0.106, blue: 0.094)
    }

    static func secondaryInk(_ scheme: ColorScheme) -> Color {
        scheme == .dark
            ? Color(red: 0.722, green: 0.675, blue: 0.612)
            : Color(red: 0.420, green: 0.376, blue: 0.329)
    }
}

private struct EthosScreenModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(EthosColor.canvas(colorScheme))
            .foregroundStyle(EthosColor.ink(colorScheme))
    }
}

extension View {
    func ethosScreen() -> some View {
        modifier(EthosScreenModifier())
    }
}
