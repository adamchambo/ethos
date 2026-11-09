import SwiftUI

struct AppTabs: View {
    let service: HabitProgressService
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TabView {
            Tab("Day", systemImage: "sun.max") {
                DayView(service: service)
            }
            Tab("Insights", systemImage: "chart.bar") {
                InsightsView(service: service)
            }
            Tab("Habits", systemImage: "list.bullet") {
                HabitsView(service: service)
            }
            Tab("My Ethos", systemImage: "person") {
                MyEthosView(service: service)
            }
            Tab("Settings", systemImage: "gearshape") {
                SettingsView(service: service)
            }
        }
        .fullScreenCover(isPresented: Binding(
            get: { !service.didFinishOnboarding },
            set: { _ in }
        )) {
            OnboardingView(service: service)
                .interactiveDismissDisabled()
        }
        .onAppear { service.prepare(now: .now) }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                service.prepare(now: .now)
            }
        }
    }
}
