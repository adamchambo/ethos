import SwiftUI
import UIKit

/// The palette from the visual design notes: charcoal, warm paper, one copper accent.
/// Every colour adapts to light and dark on its own, so sheets and system-drawn rows match
/// without reading the colour scheme. `*Fill` tones are for bars and dots; the plain
/// status colours are darker or lighter so text stays above 4.5:1 on `surface`.
enum EthosColor {
    static let accent = adaptive(light: 0xA85A30, dark: 0xD27C4E)

    static let success = adaptive(light: 0x4A6B50, dark: 0x8DB394)
    static let attention = adaptive(light: 0x8F5E1F, dark: 0xD9A15C)
    static let failure = adaptive(light: 0x8E3A2E, dark: 0xD97A6A)

    static let successFill = adaptive(light: 0x6B8F71, dark: 0x7FA386)
    static let attentionFill = adaptive(light: 0xC48B46, dark: 0xC9924E)
    static let failureFill = adaptive(light: 0xA5493A, dark: 0xC0614F)

    static let canvas = adaptive(light: 0xF6F2EA, dark: 0x1A1715)
    static let surface = adaptive(light: 0xFDFAF5, dark: 0x282420)
    static let track = adaptive(light: 0xE8E1D6, dark: 0x3A342E)
    static let secondaryInk = adaptive(light: 0x6B6054, dark: 0xB8AC9C)

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

extension View {
    /// Paints the warm canvas behind a List or Form. Row colour is set per section with `ethosRows()`.
    func ethosScreen() -> some View {
        scrollContentBackground(.hidden)
            .background(EthosColor.canvas)
    }

    func ethosRows() -> some View {
        listRowBackground(EthosColor.surface)
    }
}

/// Animates a state change unless the person has asked for reduced motion.
func ethosAnimate<Result>(_ reduceMotion: Bool, _ body: () throws -> Result) rethrows -> Result {
    try withAnimation(reduceMotion ? nil : .snappy(duration: 0.3), body)
}

extension HabitPeriodOutcome {
    func statusColor(hasProgress: Bool) -> Color {
        switch self {
        case .succeeded: EthosColor.success
        case .failed: EthosColor.failure
        case .skipped: EthosColor.secondaryInk
        case .inProgress: hasProgress ? EthosColor.attention : EthosColor.secondaryInk
        }
    }

    func fillColor(hasProgress: Bool) -> Color {
        switch self {
        case .succeeded: EthosColor.successFill
        case .failed: EthosColor.failureFill
        case .skipped: EthosColor.track
        case .inProgress: hasProgress ? EthosColor.attentionFill : EthosColor.track
        }
    }
}
