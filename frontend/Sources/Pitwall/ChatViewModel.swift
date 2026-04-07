import Foundation

@MainActor
class ChatViewModel: ObservableObject {

    struct Message: Identifiable, Sendable {
        let id = UUID()
        let role: String    // "user" or "assistant"
        let content: String
    }

    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    private let baseURL = "http://localhost:8000/api"

    // MARK: - Send

    func send(text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // 1. Append user message locally
        messages.append(Message(role: "user", content: trimmed))

        // 2. Set loading
        isLoading = true
        errorMessage = nil

        // 3. Build request
        guard let url = URL(string: "\(baseURL)/chat/watsonx") else {
            errorMessage = "Invalid URL"
            isLoading = false
            return
        }

        // Build history slice: last 10 messages (before the one just appended)
        let historySlice = messages.dropLast()   // exclude the message we just added
            .suffix(10)
            .map { ["role": $0.role, "content": $0.content] }

        let body: [String: Any] = [
            "message": trimmed,
            "history": historySlice
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let token = UserDefaults.standard.string(forKey: "access_token") ?? ""
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, _) = try await URLSession.shared.data(for: request)

            // 4. Decode { "reply": String }
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let reply = json["reply"] as? String {
                // 5. Append assistant message
                messages.append(Message(role: "assistant", content: reply))
            } else {
                errorMessage = "Unexpected response from server."
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        // 6. Clear loading
        isLoading = false
    }

    // MARK: - Load History

    func loadHistory() async {
        guard let url = URL(string: "\(baseURL)/chat/history") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let token = UserDefaults.standard.string(forKey: "access_token") ?? ""
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)

            // Decode array of { id, role, content, created_at }
            if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                messages = jsonArray.compactMap { dict in
                    guard let role = dict["role"] as? String,
                          let content = dict["content"] as? String else { return nil }
                    return Message(role: role, content: content)
                }
            }
        } catch {
            // Silently ignore history load failures
        }
    }
}
