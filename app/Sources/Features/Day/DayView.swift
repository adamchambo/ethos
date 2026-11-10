import SwiftUI

struct DayView: View {
    let snapshot: DayViewSnapshot
    var expandedChecklistIDs: Set<UUID> = []
    var onTrailingAction: ((DayHabitRow) -> Void)?
    var onToggleChecklistItem: ((DayHabitRow, ChecklistItemState) -> Void)?
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
                                isExpanded: expandedChecklistIDs.contains(row.id),
                                onTrailingAction: { onTrailingAction?(row) },
                                onToggleChecklistItem: { item in
                                    onToggleChecklistItem?(row, item)
                                },
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
    var isExpanded: Bool
    var onTrailingAction: () -> Void
    var onToggleChecklistItem: (ChecklistItemState) -> Void
    var onOpenDetail: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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

                trailingControl
            }

            if row.expandsChecklist, isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(row.checklistStates) { state in
                        Button {
                            onToggleChecklistItem(state)
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: state.isComplete ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(state.isComplete ? Color.accentColor : Color.secondary)
                                Text(state.item.title)
                                    .strikethrough(state.isComplete)
                                    .foregroundStyle(state.isComplete ? Color.secondary : Color.primary)
                                Spacer()
                            }
                            .padding(.vertical, 8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(
                            state.isComplete
                                ? "\(state.item.title), completed"
                                : "\(state.item.title), not completed"
                        )
                    }
                }
                .padding(.leading, 4)
            }
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .opacity(row.isFinished ? 0.78 : 1)
    }

    @ViewBuilder
    private var trailingControl: some View {
        if row.isFinished, row.trailingAction != .expandChecklist {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.secondary)
                .accessibilityLabel("Finished")
        } else if row.canUseTrailingAction || row.expandsChecklist {
            Button(action: onTrailingAction) {
                if row.expandsChecklist {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                } else {
                    Text(row.trailingTitle)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .accessibilityLabel(
                row.expandsChecklist
                    ? (isExpanded ? "Hide checklist" : "Show checklist")
                    : "\(row.trailingTitle) \(row.habit.title)"
            )
        }
    }
}

#Preview("Day view") {
    DayView(snapshot: DayViewDemo.snapshot(reference: .now))
}
