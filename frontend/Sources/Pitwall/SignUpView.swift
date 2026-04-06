import SwiftUI

struct SignUpView: View {
    @EnvironmentObject private var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var username = ""
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var localError: String? = nil

    private let bgColor = Color(red: 0.05, green: 0.05, blue: 0.05)
    private let fieldBg = Color(red: 0.12, green: 0.12, blue: 0.12)
    private let redAccent = Color(red: 0.88, green: 0.1, blue: 0.1)

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {
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
                    .padding(.top, 40)

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

                        TextField("Full Name", text: $fullName)
                            .autocorrectionDisabled()
                            .padding()
                            .background(fieldBg)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .tint(redAccent)

                        TextField("Email", text: $email)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .keyboardType(.emailAddress)
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

                        SecureField("Confirm Password", text: $confirmPassword)
                            .padding()
                            .background(fieldBg)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .tint(redAccent)
                    }
                    .padding(.horizontal, 24)

                    // Error messages
                    let displayError = localError ?? viewModel.errorMessage
                    if let error = displayError {
                        Text(error)
                            .foregroundColor(redAccent)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    // Create Account button
                    Button {
                        localError = nil
                        guard password == confirmPassword else {
                            localError = "Passwords do not match"
                            return
                        }
                        Task {
                            await viewModel.signup(
                                username: username,
                                name: fullName,
                                email: email,
                                password: password
                            )
                        }
                    } label: {
                        ZStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Create Account")
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

                    // Back to Log In
                    Button {
                        dismiss()
                    } label: {
                        Text("Already have an account? ")
                            .foregroundColor(.gray)
                        + Text("Log In")
                            .foregroundColor(redAccent)
                            .bold()
                    }
                    .font(.subheadline)

                    Spacer(minLength: 40)
                }
            }
        }
        .navigationBarHidden(true)
    }
}

#Preview {
    SignUpView()
        .environmentObject(AuthViewModel())
}
