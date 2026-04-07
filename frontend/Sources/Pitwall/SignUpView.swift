import SwiftUI

// MARK: - F1 Models

struct F1Driver: Identifiable, Decodable, Sendable {
    let driverId: String
    let givenName: String
    let familyName: String
    let code: String?
    let nationality: String?

    var id: String { driverId }
    var displayName: String {
        "\(givenName) \(familyName)" + (code.map { " (\($0))" } ?? "")
    }
}

struct F1Team: Identifiable, Decodable, Sendable {
    let constructorId: String
    let name: String
    let nationality: String?

    var id: String { constructorId }
}

// MARK: - Jolpica / Ergast response wrappers

private struct DriverResponse: Decodable {
    let MRData: MRDriverData
}

private struct MRDriverData: Decodable {
    let DriverTable: DriverTable
}

private struct DriverTable: Decodable {
    let Drivers: [F1Driver]
}

private struct ConstructorResponse: Decodable {
    let MRData: MRConstructorData
}

private struct MRConstructorData: Decodable {
    let ConstructorTable: ConstructorTable
}

private struct ConstructorTable: Decodable {
    let Constructors: [F1Team]
}

// MARK: - SignUpView

struct SignUpView: View {
    @EnvironmentObject private var viewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss

    // Account fields
    @State private var username = ""
    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    // F1 preference fields
    @State private var drivers: [F1Driver] = []
    @State private var teams: [F1Team] = []
    @State private var selectedDriver: String = ""   // driverId, "" = none
    @State private var selectedTeam: String = ""      // constructorId, "" = none
    @State private var isLoadingF1Data = false

    @State private var localError: String? = nil

    // Theme constants matching the rest of the app
    private let bgColor = Color(red: 0.05, green: 0.05, blue: 0.05)
    private let fieldBg = Color(red: 0.12, green: 0.12, blue: 0.12)
    private let redAccent = Color(red: 0.88, green: 0.1, blue: 0.1)

    /// Drivers optionally filtered to the currently-selected team.
    /// Falls back to the full list when no team is selected or when the
    /// Jolpica API doesn't carry constructor info (it doesn't in the
    /// standalone drivers endpoint, so we keep all drivers visible).
    private var filteredDrivers: [F1Driver] {
        drivers // The drivers endpoint doesn't include team info, so show all.
    }

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

                    // ── Account fields ──────────────────────────────
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

                    // ── Favourite Team picker ───────────────────────
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Favourite Team")
                            .font(.headline)
                            .foregroundColor(.white)

                        if isLoadingF1Data && teams.isEmpty {
                            ProgressView()
                                .tint(redAccent)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else {
                            Picker("Select Team", selection: $selectedTeam) {
                                Text("None").tag("")
                                ForEach(teams) { team in
                                    Text(team.name).tag(team.constructorId)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(fieldBg)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .tint(redAccent)
                        }
                    }
                    .padding(.horizontal, 24)

                    // ── Favourite Driver picker ─────────────────────
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Favourite Driver")
                            .font(.headline)
                            .foregroundColor(.white)

                        if isLoadingF1Data && drivers.isEmpty {
                            ProgressView()
                                .tint(redAccent)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                        } else {
                            Picker("Select Driver", selection: $selectedDriver) {
                                Text("None").tag("")
                                ForEach(filteredDrivers) { driver in
                                    Text(driver.displayName).tag(driver.driverId)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(fieldBg)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                            .tint(redAccent)
                        }
                    }
                    .padding(.horizontal, 24)

                    // ── Error messages ───────────────────────────────
                    let displayError = localError ?? viewModel.errorMessage
                    if let error = displayError {
                        Text(error)
                            .foregroundColor(redAccent)
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    // ── Create Account button ───────────────────────
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
                                password: password,
                                favDriver: selectedDriver.isEmpty ? nil : selectedDriver,
                                favTeam: selectedTeam.isEmpty ? nil : selectedTeam
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

                    // ── Back to Log In ───────────────────────────────
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
        .task {
            await loadF1Data()
        }
    }

    // MARK: - Jolpica data fetching

    private func loadF1Data() async {
        isLoadingF1Data = true
        defer { isLoadingF1Data = false }

        async let fetchedDrivers = fetchDrivers()
        async let fetchedTeams = fetchTeams()

        let (driverResult, teamResult) = await (fetchedDrivers, fetchedTeams)
        drivers = driverResult
        teams = teamResult
    }

    private func fetchDrivers() async -> [F1Driver] {
        guard let url = URL(string: "https://api.jolpi.ca/ergast/f1/current/drivers.json") else {
            return []
        }
        do {
            let (data, _) = try await URLSession.shared.data(for: URLRequest(url: url))
            let response = try JSONDecoder().decode(DriverResponse.self, from: data)
            return response.MRData.DriverTable.Drivers
        } catch {
            print("[SignUpView] Failed to fetch drivers: \(error)")
            return []
        }
    }

    private func fetchTeams() async -> [F1Team] {
        guard let url = URL(string: "https://api.jolpi.ca/ergast/f1/current/constructors.json") else {
            return []
        }
        do {
            let (data, _) = try await URLSession.shared.data(for: URLRequest(url: url))
            let response = try JSONDecoder().decode(ConstructorResponse.self, from: data)
            return response.MRData.ConstructorTable.Constructors
        } catch {
            print("[SignUpView] Failed to fetch constructors: \(error)")
            return []
        }
    }
}

#Preview {
    SignUpView()
        .environmentObject(AuthViewModel())
}
