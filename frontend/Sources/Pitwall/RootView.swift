import SwiftUI

struct RootView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel

    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.07, green: 0.07, blue: 0.07, alpha: 1.0)

        let normalAttr: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor(white: 0.5, alpha: 1)
        ]
        let selectedAttr: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor(red: 0.88, green: 0.1, blue: 0.1, alpha: 1)
        ]
        appearance.stackedLayoutAppearance.normal.titleTextAttributes = normalAttr
        appearance.stackedLayoutAppearance.selected.titleTextAttributes = selectedAttr
        appearance.stackedLayoutAppearance.normal.iconColor = UIColor(white: 0.5, alpha: 1)
        appearance.stackedLayoutAppearance.selected.iconColor = UIColor(red: 0.88, green: 0.1, blue: 0.1, alpha: 1)

        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            ScheduleView()
                .tabItem {
                    Label("Schedule", systemImage: "calendar")
                }

            ProfileView()
                .tabItem {
                    Label("Profile", systemImage: "person.fill")
                }
        }
        .tint(Color(red: 0.88, green: 0.1, blue: 0.1))
    }
}

#Preview {
    RootView()
        .environmentObject(AuthViewModel())
}
