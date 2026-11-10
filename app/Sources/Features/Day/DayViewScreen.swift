import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct DayViewScreen: View {
    @State private var store: HabitStore
    @State private var path: [UUID] = []
    @State private var checklistRow: DayHabitRow?
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
                onQuickLog: handleQuickLog,
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
            .sheet(item: $checklistRow) { row in
                ChecklistSheet(store: store, row: row)
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

    private func handleQuickLog(_ row: DayHabitRow) {
        if row.opensChecklist {
            checklistRow = row
            return
        }

        let succeeded = store.quickLog(row: row)
        if succeeded {
            showUndo = true
            if store.hapticsEnabled {
                #if canImport(UIKit)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                #endif
            }
        } else {
            showUndo = false
        }
    }
}

private struct ChecklistSheet: View {
    @Bindable var store: HabitStore
    let row: DayHabitRow
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Choose an item to log") {
                    ForEach(row.quickLog.checklistItems) { item in
                        Button(item.title) {
                            if store.logChecklistItem(habitID: row.id, item: item) {
                                dismiss()
                            }
                        }
                    }
                }
            }
            .navigationTitle(row.habit.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    DayViewScreen()
}
