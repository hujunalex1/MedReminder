import SwiftUI

@main
@MainActor
struct MedReminderApp: App {

    @State private var store = MedicationStore()

    init() {
        NotificationManager.shared.requestPermission()
    }

    var body: some Scene {
        MenuBarExtra {
            ContentView()
                .environment(store)
        } label: {
            Image(nsImage: AppIconImage.menuBar)
        }
        .menuBarExtraStyle(.window)
    }
}
