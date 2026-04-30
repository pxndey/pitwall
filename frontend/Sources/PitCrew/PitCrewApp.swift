import SwiftUI

@main
struct PitCrewApp: App {
    @StateObject private var authViewModel = AuthViewModel()

    var body: some Scene {
        WindowGroup {
            SplashView()
                .environmentObject(authViewModel)
                .task {
                    await NotificationManager.shared.requestPermission()
                }
        }
    }
}
