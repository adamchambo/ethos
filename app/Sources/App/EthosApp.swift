import SwiftUI

@main struct EthosApp: App {
    @State private var progressService = HabitProgressService()

    var body: some Scene {
        WindowGroup {
            ContentView(service: progressService)
        }
    }
}
