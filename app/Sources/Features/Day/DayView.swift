import SwiftUI

struct DayView: View {
    let snapshot: DayViewSnapshot
    var onLog: ((DayHabitRow) -> Void)?

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE d MMMM"
        return formatter
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                ForEach(Array(snapshot.sections.enumerated()), id: \.offset) { _, section in
                    VStack(alignment: .leading, spacing: 10) {
                        Text(section.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        ForEach(section.rows) { row in
                            DayHabitRowView(row: row) {
                                onLog?(row)
                            }
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
    var onLog: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(row.habit.title)
                    .font(.body.weight(.semibold))

                Text(row.scheduleLabel)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(row.progressLabel)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(row.isFinished ? Color.secondary : Color.accentColor)
            }

            Spacer(minLength: 8)

            if !row.isFinished {
                Button("Log", action: onLog)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .opacity(row.isFinished ? 0.72 : 1)
    }
}

#Preview("Day view") {
    DayView(snapshot: DayViewDemo.snapshot(reference: .now))
}
