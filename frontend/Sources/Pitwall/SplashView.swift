import SwiftUI

struct SplashView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var opacity: Double = 0
    @State private var showLogin = false

    private let bgColor = Color(red: 0.05, green: 0.05, blue: 0.05)
    private let redAccent = Color(red: 0.88, green: 0.1, blue: 0.1)

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "rocket.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 80, height: 80)
                    .foregroundColor(redAccent)

                Text("PITWALL")
                    .font(.system(size: 36, weight: .black, design: .default))
                    .tracking(8)
                    .foregroundColor(.white)
            }
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeIn(duration: 0.8)) {
                    opacity = 1
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    showLogin = true
                }
            }
        }
        .fullScreenCover(isPresented: $showLogin) {
            if authViewModel.isLoggedIn {
                HomeView()
                    .environmentObject(authViewModel)
            } else {
                LoginView()
                    .environmentObject(authViewModel)
            }
        }
    }
}

#Preview {
    SplashView()
        .environmentObject(AuthViewModel())
}
