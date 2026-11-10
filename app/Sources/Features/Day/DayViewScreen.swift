import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct DayViewScreen: View {
    @State private var store: HabitStore
    @State private var path: [UUID] = []
    @State private var expandedChecklistIDs: Set<UUID> = []
    @State private var showUndo = false

    init(store: HabitStore? = nil) {
        let calendar = Calendar.current
        _store = State(
            initialValue: store ?? HabitStore(
                definitions: DayViewDemo.definitions(reference: Date(), calendar: calendar),
                selectedDate: Date(),
                calendar: calendar
            )
        )
    }

    var body: some View {
        NavigationStack(path: $path) {
            DayView(
                snapshot: store.snapshot,
                expandedChecklistIDs: expandedChecklistIDs,
                onTrailingAction: handleTrailingAction,
                onToggleChecklistItem: { row, item in
                    if store.toggleChecklistItem(habitID: row.id, itemID: item.id) {
                        pulseSuccess()
                        showUndo = true
                    }
                },
                onOpenDetail: { row in path.append(row.id) }
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        store.shiftDay(-1)
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .accessibilityLabel("Previous day")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        store.shiftDay(1)
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .accessibilityLabel("Next day")
                }
            }
            .safeAreaInset(edge: .bottom) {
                feedbackBanner
            }
            .navigationDestination(for: UUID.self) { habitID in
                HabitDetailView(store: store, habitID: habitID)
            }
        }
    }

    @ViewBuilder
    private var feedbackBanner: some View {
        if let message = store.lastErrorMessage {
            Text(message)
                .font(.footnote)
                .padding(12)
                .frame(maxWidth: .infinity)
                .background(.red.opacity(0.12))
        } else if showUndo {
            HStack {
                Text("Logged")
                Spacer()
                Button("Undo") {
                    if store.undoLastLog() {
                        showUndo = false
                    }
                }
                .bold()
            }
            .font(.footnote)
            .padding(12)
            .background(.ultraThinMaterial)
        }
    }

    private func handleTrailingAction(_ row: DayHabitRow) {
        switch row.trailingAction {
        case .expandChecklist:
            if expandedChecklistIDs.contains(row.id) {
                expandedChecklistIDs.remove(row.id)
            } else {
                expandedChecklistIDs.insert(row.id)
            }
        case .complete, .slip:
            if store.completeFromDay(row: row) {
                showUndo = true
                pulseSuccess()
            } else {
                showUndo = false
            }
        case .none:
            break
        }
    }

    private func pulseSuccess() {
        guard store.hapticsEnabled else { return }
        #if canImport(UIKit)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }
}

#Preview {
    DayViewScreen()
}
