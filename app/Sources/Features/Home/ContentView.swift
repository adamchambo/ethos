import SwiftUI
import Playgrounds

struct ContentView: View {
    let service: HabitProgressService
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List(service.habits) { habit in
                let today = Date.now
                let calendar = Calendar.current
                let current = service.progress(habitID: habit.id, on: today, calendar: calendar)
                let period = service.periods.first {
                    $0.habitID == habit.id && $0.startsAt <= today && today < $0.endsAt
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(habit.title)
                        .font(.headline)
                    Text("Progress: \(current.formatted()) / \(habit.goal.target.formatted())")
                    Text("Streak: \(service.streak(habitID: habit.id))")
                    Text("Completion rate: \(service.rate(habitID: habit.id).map { ($0 * 100).formatted() + "%" } ?? "—")")
                    Button("Log 1") {
                        do {
                            try service.log(habitID: habit.id, amount: 1, on: .now, calendar: .current)
                        } catch {
                            errorMessage = error.localizedDescription
                        }
                    }
                    .disabled(period?.isFinalized == true)
                }
            }
            .navigationTitle("Today")
            .alert("Unable to log progress", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }
}

#Preview {
    let now = Date.now
    let demoHabits = [
        try! Habit(
            title: "Take vitamins",
            createdAt: now,
            goal: Goal(measurement: .boolean, target: 1, interval: .day),
            schedule: .daily
        ),
        try! Habit(
            title: "Drink water",
            createdAt: now,
            goal: Goal(measurement: .count, target: 3, interval: .day),
            schedule: .daily
        )
    ]
    ContentView(service: HabitProgressService(habits: demoHabits, now: now))
}

#Playground {
    _ = 1 + 2
}
