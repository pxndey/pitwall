import SwiftUI

// MARK: - Models

private struct UserOut: Decodable {
    let id: Int
    let username: String
    let name: String?
    let email: String?
    let fav_driver: String?
    let fav_team: String?
    let created_at: String?
}

// MARK: - ProfileViewModel

@MainActor
class ProfileViewModel: ObservableObject {
    @Published var username: String = ""
    @Published var name: String = ""
    @Published var email: String = ""
    @Published var favDriver: String = ""
    @Published var favTeam: String = ""
    @Published var createdAt: Date? = nil
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var successMessage: String? = nil

    private let baseURL = "http://localhost:8000/api/auth"

    private var token: String? {
        UserDefaults.standard.string(forKey: "access_token")
    }

    func loadProfile() async {
        guard let token else {
            errorMessage = "Not authenticated"
            return
        }
        guard let url = URL(string: "\(baseURL)/me") else {
            errorMessage = "Invalid URL"
            return
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let user = try JSONDecoder().decode(UserOut.self, from: data)
            username = user.username
            name = user.name ?? ""
            email = user.email ?? ""
            favDriver = user.fav_driver ?? ""
            favTeam = user.fav_team ?? ""
            if let raw = user.created_at {
                createdAt = parseDate(raw)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateProfile(
        name: String?,
        email: String?,
        password: String?,
        favDriver: String?,
        favTeam: String?
    ) async {
        guard let token else {
            errorMessage = "Not authenticated"
            return
        }
        guard let url = URL(string: "\(baseURL)/me") else {
            errorMessage = "Invalid URL"
            return
        }

        isLoading = true
        errorMessage = nil
        successMessage = nil
        defer { isLoading = false }

        var body: [String: String] = [:]
        if let name, !name.isEmpty { body["name"] = name }
        if let email, !email.isEmpty { body["email"] = email }
        if let password, !password.isEmpty { body["password"] = password }
        if let favDriver, !favDriver.isEmpty { body["fav_driver"] = favDriver }
        if let favTeam, !favTeam.isEmpty { body["fav_team"] = favTeam }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (data, _) = try await URLSession.shared.data(for: request)
            let user = try JSONDecoder().decode(UserOut.self, from: data)
            self.name = user.name ?? ""
            self.email = user.email ?? ""
            self.favDriver = user.fav_driver ?? ""
            self.favTeam = user.fav_team ?? ""
            successMessage = "Profile updated successfully"
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteAccount() async -> Bool {
        guard let token else { return false }
        guard let url = URL(string: "\(baseURL)/me") else { return false }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                return true
            }
            return false
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    // MARK: - Helpers

    private func parseDate(_ raw: String) -> Date? {
        // Try ISO8601 with fractional seconds first, then without
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: raw) { return d }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: raw)
    }
}

// MARK: - UpdateDetailsView

struct UpdateDetailsView: View {
    @ObservedObject var profileViewModel: ProfileViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var email: String
    @State private var newPassword: String = ""
    @State private var favDriver: String
    @State private var favTeam: String

    private let accent = Color(red: 0.88, green: 0.1, blue: 0.1)
    private let bg = Color(red: 0.05, green: 0.05, blue: 0.05)
    private let rowBg = Color(red: 0.1, green: 0.1, blue: 0.1)

    init(profileViewModel: ProfileViewModel) {
        self.profileViewModel = profileViewModel
        _name = State(initialValue: profileViewModel.name)
        _email = State(initialValue: profileViewModel.email)
        _favDriver = State(initialValue: profileViewModel.favDriver)
        _favTeam = State(initialValue: profileViewModel.favTeam)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                bg.ignoresSafeArea()

                List {
                    Section("Personal Info") {
                        styledTextField("Full Name", text: $name)
                        styledTextField("Email", text: $email)
                            .keyboardType(.emailAddress)
                            .autocapitalization(.none)
                    }
                    .listRowBackground(rowBg)

                    Section("Security") {
                        styledSecureField("New Password (optional)", text: $newPassword)
                    }
                    .listRowBackground(rowBg)

                    Section("F1 Preferences") {
                        styledTextField("Favourite Driver", text: $favDriver)
                        styledTextField("Favourite Team", text: $favTeam)
                    }
                    .listRowBackground(rowBg)

                    if let err = profileViewModel.errorMessage {
                        Section {
                            Text(err)
                                .foregroundStyle(.red)
                                .font(.footnote)
                        }
                        .listRowBackground(rowBg)
                    }

                    if let success = profileViewModel.successMessage {
                        Section {
                            Text(success)
                                .foregroundStyle(.green)
                                .font(.footnote)
                        }
                        .listRowBackground(rowBg)
                    }

                    Section {
                        Button {
                            Task {
                                await profileViewModel.updateProfile(
                                    name: name,
                                    email: email,
                                    password: newPassword.isEmpty ? nil : newPassword,
                                    favDriver: favDriver,
                                    favTeam: favTeam
                                )
                                if profileViewModel.errorMessage == nil {
                                    dismiss()
                                }
                            }
                        } label: {
                            HStack {
                                Spacer()
                                if profileViewModel.isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text("Save Changes")
                                        .foregroundStyle(.white)
                                        .fontWeight(.semibold)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 6)
                        }
                        .disabled(profileViewModel.isLoading)
                        .listRowBackground(accent)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Update Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(accent)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func styledTextField(_ placeholder: String, text: Binding<String>) -> some View {
        TextField(placeholder, text: text)
            .foregroundStyle(.white)
            .tint(Color(red: 0.88, green: 0.1, blue: 0.1))
    }

    @ViewBuilder
    private func styledSecureField(_ placeholder: String, text: Binding<String>) -> some View {
        SecureField(placeholder, text: text)
            .foregroundStyle(.white)
            .tint(Color(red: 0.88, green: 0.1, blue: 0.1))
    }
}

// MARK: - EditPreferenceSheet

private struct EditPreferenceSheet: View {
    let title: String
    @Binding var value: String
    let onSave: () async -> Void

    @State private var draft: String = ""
    @Environment(\.dismiss) private var dismiss

    private let accent = Color(red: 0.88, green: 0.1, blue: 0.1)
    private let bg = Color(red: 0.05, green: 0.05, blue: 0.05)
    private let rowBg = Color(red: 0.1, green: 0.1, blue: 0.1)

    var body: some View {
        NavigationStack {
            ZStack {
                bg.ignoresSafeArea()
                List {
                    Section {
                        TextField(title, text: $draft)
                            .foregroundStyle(.white)
                            .tint(accent)
                    }
                    .listRowBackground(rowBg)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(accent)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        value = draft
                        Task {
                            await onSave()
                            dismiss()
                        }
                    }
                    .foregroundStyle(accent)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { draft = value }
    }
}

// MARK: - ProfileView

struct ProfileView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var profileViewModel = ProfileViewModel()

    private let bg = Color(red: 0.05, green: 0.05, blue: 0.05)
    private let rowBg = Color(red: 0.1, green: 0.1, blue: 0.1)
    private let accent = Color(red: 0.88, green: 0.1, blue: 0.1)

    @State private var showUpdateDetails = false
    @State private var showDeleteAlert = false
    @State private var showDriverSheet = false
    @State private var showTeamSheet = false

    private var memberSinceText: String {
        guard let date = profileViewModel.createdAt else { return "Member since —" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return "Member since \(formatter.string(from: date))"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                bg.ignoresSafeArea()

                if profileViewModel.isLoading && profileViewModel.username.isEmpty {
                    ProgressView()
                        .tint(accent)
                } else {
                    List {
                        // MARK: Header
                        Section {
                            VStack(spacing: 10) {
                                Image(systemName: "rocket.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 40, height: 40)
                                    .foregroundStyle(accent)

                                Text(profileViewModel.username)
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(.white)

                                Text(profileViewModel.email.isEmpty ? "—" : profileViewModel.email)
                                    .font(.system(size: 14))
                                    .foregroundStyle(.gray)

                                Text(memberSinceText)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .listRowBackground(rowBg)
                        }

                        // MARK: F1 Preferences
                        Section("F1 Preferences") {
                            preferenceRow(
                                icon: "person.fill",
                                label: "Favourite Driver",
                                value: profileViewModel.favDriver.isEmpty ? "Not set" : profileViewModel.favDriver
                            ) {
                                showDriverSheet = true
                            }

                            preferenceRow(
                                icon: "flag.checkered",
                                label: "Favourite Team",
                                value: profileViewModel.favTeam.isEmpty ? "Not set" : profileViewModel.favTeam
                            ) {
                                showTeamSheet = true
                            }
                        }
                        .listRowBackground(rowBg)

                        // MARK: Account
                        Section("Account") {
                            Button {
                                showUpdateDetails = true
                            } label: {
                                accountRow(icon: "pencil", label: "Update Details", color: .white)
                            }

                            Button {
                                authViewModel.logout()
                            } label: {
                                accountRow(icon: "rectangle.portrait.and.arrow.right", label: "Log Out", color: .white)
                            }

                            Button(role: .destructive) {
                                showDeleteAlert = true
                            } label: {
                                accountRow(icon: "trash", label: "Delete Account", color: accent)
                            }
                        }
                        .listRowBackground(rowBg)
                    }
                    .listStyle(.insetGrouped)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .task {
                await profileViewModel.loadProfile()
            }
            .sheet(isPresented: $showUpdateDetails) {
                UpdateDetailsView(profileViewModel: profileViewModel)
            }
            .sheet(isPresented: $showDriverSheet) {
                EditPreferenceSheet(
                    title: "Favourite Driver",
                    value: $profileViewModel.favDriver
                ) {
                    await profileViewModel.updateProfile(
                        name: nil,
                        email: nil,
                        password: nil,
                        favDriver: profileViewModel.favDriver,
                        favTeam: nil
                    )
                }
            }
            .sheet(isPresented: $showTeamSheet) {
                EditPreferenceSheet(
                    title: "Favourite Team",
                    value: $profileViewModel.favTeam
                ) {
                    await profileViewModel.updateProfile(
                        name: nil,
                        email: nil,
                        password: nil,
                        favDriver: nil,
                        favTeam: profileViewModel.favTeam
                    )
                }
            }
            .alert("Delete Account", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) {
                    Task {
                        let success = await profileViewModel.deleteAccount()
                        if success {
                            authViewModel.logout()
                        }
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete your account and all data. This cannot be undone.")
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Row Builders

    @ViewBuilder
    private func preferenceRow(
        icon: String,
        label: String,
        value: String,
        onTap: @escaping () -> Void
    ) -> some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: icon)
                    .foregroundStyle(accent)
                    .frame(width: 24)
                Text(label)
                    .foregroundStyle(.white)
                Spacer()
                Text(value)
                    .foregroundStyle(.gray)
                    .font(.subheadline)
                Image(systemName: "chevron.right")
                    .foregroundStyle(.gray)
                    .font(.caption)
            }
        }
    }

    @ViewBuilder
    private func accountRow(icon: String, label: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 24)
            Text(label)
                .foregroundStyle(color)
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.gray)
                .font(.caption)
        }
    }
}

// MARK: - Preview

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
}
