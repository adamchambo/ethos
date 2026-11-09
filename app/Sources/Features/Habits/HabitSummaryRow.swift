import SwiftUI

/// The one row layout for a habit in a list: category dot, title, a detail line, and an optional trailing value.
struct HabitSummaryRow: View {
    let habit: Habit
    let categories: [Category]
    let detail: String
    var trailing: String?
    var trailingColor: Color = EthosColor.secondaryInk

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Circle()
                .fill(categoryColor(habit.categoryID, categories: categories))
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(habit.title)
                    .font(.headline)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(EthosColor.secondaryInk)
            }
            Spacer(minLength: 8)
            if let trailing {
                Text(trailing)
                    .font(.subheadline.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(trailingColor)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
