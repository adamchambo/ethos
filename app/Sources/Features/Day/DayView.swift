import SwiftUI

struct DayView: View {
    let snapshot: DayViewSnapshot
    var onQuickLog: ((DayHabitRow) -> Void)?
    var onOpenDetail: ((DayHabitRow) -> Void)?

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE d MMMM"
        return formatter
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                if snapshot.isFutureDate {
                    Text("Browsing a future day — logging is disabled.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ForEach(Array(snapshot.sections.enumerated()), id: \.offset) { _, section in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(section.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        ForEach(section.rows) { row in
                            DayHabitRowView(
                                row: row,
                                onQuickLog: { onQuickLog?(row) },
                                onOpenDetail: { onOpenDetail?(row) }
                            )
                        }
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(Self.dateFormatter.string(from: snapshot.date))
                .font(.title2.weight(.semibold))

            Text(summaryText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var summaryText: String {
        let scheduled = snapshot.scheduledTodayCount
        let unfinished = snapshot.unfinishedDailyCommitments
        if unfinished == 0 {
            return "\(scheduled) scheduled · daily commitments done"
        }
        return "\(scheduled) scheduled · \(unfinished) daily still open"
    }
}

private struct DayHabitRowView: View {
    let row: DayHabitRow
    var onQuickLog: () -> Void
    var onOpenDetail: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Button(action: onOpenDetail) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(row.habit.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text(row.caption)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(row.habit.title). \(row.caption). Open details.")

            if row.canQuickLog {
                Button(action: onQuickLog) {
                    Text(row.quickActionTitle)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .accessibilityLabel("Quick log \(row.quickActionTitle) for \(row.habit.title)")
            } else if row.isFinished {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Finished")
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .opacity(row.isFinished ? 0.78 : 1)
    }
}

#Preview("Day view") {
    DayView(snapshot: DayViewDemo.snapshot(reference: .now))
}
