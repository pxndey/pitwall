import SwiftUI

struct OnboardingView: View {

    @Environment(\.dismiss) var dismiss
    @State private var currentPage = 0

    private let bg  = Color(red: 0.05, green: 0.05, blue: 0.05)
    private let red = Color(red: 0.88, green: 0.1, blue: 0.1)

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            TabView(selection: $currentPage) {
                onboardingPage(
                    icon: "rocket.fill",
                    title: "Welcome to Pitwall",
                    description: "Your AI-powered F1 co-watcher"
                )
                .tag(0)

                onboardingPage(
                    icon: "bubble.left.and.bubble.right.fill",
                    title: "AI Race Engineer",
                    description: "Ask about standings, results, strategy, and terminology"
                )
                .tag(1)

                onboardingPage(
                    icon: "calendar",
                    title: "Race Schedule",
                    description: "Track every race weekend with notifications"
                )
                .tag(2)

                // Final page with Get Started button
                VStack(spacing: 24) {
                    Spacer()

                    Image(systemName: "heart.fill")
                        .font(.system(size: 40))
                        .foregroundColor(red)

                    Text("Your Preferences")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)

                    Text("Set your favourite driver and team for personalized insights")
                        .font(.system(size: 16))
                        .foregroundColor(Color(white: 0.55))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    Spacer()

                    Button {
                        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
                        dismiss()
                    } label: {
                        Text("Get Started")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(red)
                            .clipShape(Capsule())
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 60)
                }
                .tag(3)
            }
            .tabViewStyle(.page)
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
    }

    private func onboardingPage(icon: String, title: String, description: String) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: icon)
                .font(.system(size: 40))
                .foregroundColor(red)

            Text(title)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)

            Text(description)
                .font(.system(size: 16))
                .foregroundColor(Color(white: 0.55))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
            Spacer()
        }
    }
}

#Preview {
    OnboardingView()
}
