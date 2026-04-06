import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var viewModel: AuthViewModel
    @State private var username = ""
    @State private var password = ""

    private let bgColor = Color(red: 0.05, green: 0.05, blue: 0.05)
    private let fieldBg = Color(red: 0.12, green: 0.12, blue: 0.12)
    private let redAccent = Color(red: 0.88, green: 0.1, blue: 0.1)

    var body: some View {
        NavigationStack {
            ZStack {
                bgColor.ignoresSafeArea()

                VStack(spacing: 32) {
                    Spacer()

                    // Logo
                    VStack(spacing: 10) {
                        Image(systemName: "rocket.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 36, height: 36)
                            .foregroundColor(redAccent)

                        Text("PITWALL")
                            .font(.system(size: 24, weight: .black, design: .default))
                            .tracking(6)
                            .foregroundColor(.white)
                    }

                    Spacer()

                    // Fields
                    VStack(spacing: 16) {
                        TextField("Username", text: $username)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding()
                            .background(fieldBg)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .tint(redAccent)

                        SecureField("Password", text: $password)
                            .padding()
                            .background(fieldBg)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .tint(redAccent)
                    }
                    .padding(.horizontal, 24)

                    // Error message
                    if let error = viewModel.errorMessage {
                        Text(error)
                            .foregroundColor(redAccent)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    // Log In button
                    Button {
                        Task {
                            await viewModel.login(username: username, password: password)
                        }
                    } label: {
                        ZStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Log In")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(redAccent)
                        .cornerRadius(12)
                    }
                    .disabled(viewModel.isLoading)
                    .padding(.horizontal, 24)

                    // Sign Up link
                    NavigationLink {
                        SignUpView()
                            .environmentObject(viewModel)
                    } label: {
                        Text("Don't have an account? ")
                            .foregroundColor(.gray)
                        + Text("Sign Up")
                            .foregroundColor(redAccent)
                            .bold()
                    }
                    .font(.subheadline)

                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthViewModel())
}
