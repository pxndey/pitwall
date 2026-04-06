import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var viewModel: AuthViewModel

    private let bgColor = Color(red: 0.05, green: 0.05, blue: 0.05)
    private let redAccent = Color(red: 0.88, green: 0.1, blue: 0.1)

    var body: some View {
        ZStack(alignment: .topTrailing) {
            bgColor.ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "rocket.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundColor(redAccent)

                Text("PITWALL")
                    .font(.system(size: 36, weight: .black, design: .default))
                    .tracking(8)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Logout button
            Button {
                viewModel.logout()
            } label: {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .padding()
            }
            .padding(.top, 8)
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
}
