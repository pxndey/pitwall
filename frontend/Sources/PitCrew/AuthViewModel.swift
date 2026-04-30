import Foundation

struct Token: Decodable {
    let access_token: String
    let token_type: String
}

@MainActor
class AuthViewModel: ObservableObject {
    /// Set to `true` to skip login and go straight to the app.
    static let debugSkipAuth = true

    @Published var isLoggedIn = true // debugSkipAuth
    @Published var errorMessage: String? = nil
    @Published var isLoading = false

    private let baseURL = "\(APIConfig.baseURL)/auth"

    func login(username: String, password: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let url = URL(string: "\(baseURL)/login") else {
            errorMessage = "Invalid URL"
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: String] = ["username": username, "password": password]
        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (data, _) = try await URLSession.shared.data(for: request)
            let token = try JSONDecoder().decode(Token.self, from: data)
            UserDefaults.standard.set(token.access_token, forKey: "access_token")
            isLoggedIn = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signup(
        username: String,
        name: String,
        email: String,
        password: String,
        favDriver: String? = nil,
        favTeam: String? = nil
    ) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let url = URL(string: "\(baseURL)/signup") else {
            errorMessage = "Invalid URL"
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: String] = [
            "username": username,
            "name": name,
            "email": email,
            "password": password
        ]
        if let favDriver, !favDriver.isEmpty {
            body["fav_driver"] = favDriver
        }
        if let favTeam, !favTeam.isEmpty {
            body["fav_team"] = favTeam
        }

        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (data, _) = try await URLSession.shared.data(for: request)
            let token = try JSONDecoder().decode(Token.self, from: data)
            UserDefaults.standard.set(token.access_token, forKey: "access_token")
            isLoggedIn = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func logout() {
        UserDefaults.standard.removeObject(forKey: "access_token")
        isLoggedIn = false
    }
}
