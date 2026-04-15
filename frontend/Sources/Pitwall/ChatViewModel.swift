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
    @Published var isLoadingHistory = false
    @Published var hasMoreHistory = true
    @Published var errorMessage: String? = nil
    @Published var conversations: [ConversationItem] = []
    @Published var activeConversationId: UUID?
    @Published var searchResults: [Message] = []

    private let baseURL = "http://localhost:8000/api"
    private let pageSize = 30
    private var historyOffset = 0

    // MARK: - Send

    func send(text: String, circuitContext: String? = nil) async {
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

        var body: [String: Any] = [
            "message": trimmed,
            "history": historySlice
        ]

        if let convId = activeConversationId {
            body["conversation_id"] = convId.uuidString
        }

        if let circuit = circuitContext {
            body["circuit_context"] = circuit
        }

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
                // Refresh conversations so new auto-created ones appear
                if activeConversationId == nil {
                    await loadConversations()
                }
            } else {
                errorMessage = "Unexpected response from server."
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        // 6. Clear loading
        isLoading = false
    }

    // MARK: - Load History (initial)

    func loadHistory() async {
        historyOffset = 0
        hasMoreHistory = true
        var urlString = "\(baseURL)/chat/history?offset=0&limit=\(pageSize)"
        if let convId = activeConversationId {
            urlString += "&conversation_id=\(convId.uuidString)"
        }
        guard let url = URL(string: urlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let token = UserDefaults.standard.string(forKey: "access_token") ?? ""
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                let loaded = jsonArray.compactMap { dict -> Message? in
                    guard let role = dict["role"] as? String,
                          let content = dict["content"] as? String else { return nil }
                    return Message(role: role, content: content)
                }
                messages = loaded
                historyOffset = loaded.count
                hasMoreHistory = loaded.count == pageSize
            }
        } catch {
            // Silently ignore history load failures
        }
    }

    // MARK: - Load More History (pagination)

    func loadMoreHistory() async {
        guard hasMoreHistory, !isLoadingHistory else { return }
        isLoadingHistory = true
        defer { isLoadingHistory = false }

        var moreUrlString = "\(baseURL)/chat/history?offset=\(historyOffset)&limit=\(pageSize)"
        if let convId = activeConversationId {
            moreUrlString += "&conversation_id=\(convId.uuidString)"
        }
        guard let url = URL(string: moreUrlString) else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let token = UserDefaults.standard.string(forKey: "access_token") ?? ""
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                let older = jsonArray.compactMap { dict -> Message? in
                    guard let role = dict["role"] as? String,
                          let content = dict["content"] as? String else { return nil }
                    return Message(role: role, content: content)
                }
                messages.insert(contentsOf: older, at: 0)
                historyOffset += older.count
                hasMoreHistory = older.count == pageSize
            }
        } catch {}
    }

    // MARK: - Conversations

    func loadConversations() async {
        guard let url = URL(string: "\(baseURL)/chat/conversations") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let token = UserDefaults.standard.string(forKey: "access_token") ?? ""
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                let isoFrac = ISO8601DateFormatter()
                isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
                let isoPlain = ISO8601DateFormatter()
                isoPlain.formatOptions = [.withInternetDateTime]

                conversations = jsonArray.compactMap { dict -> ConversationItem? in
                    guard let idStr = dict["id"] as? String,
                          let uuid = UUID(uuidString: idStr),
                          let title = dict["title"] as? String,
                          let createdStr = dict["created_at"] as? String,
                          let updatedStr = dict["updated_at"] as? String,
                          let count = dict["message_count"] as? Int else { return nil }

                    let created = isoFrac.date(from: createdStr) ?? isoPlain.date(from: createdStr) ?? Date()
                    let updated = isoFrac.date(from: updatedStr) ?? isoPlain.date(from: updatedStr) ?? Date()

                    return ConversationItem(id: uuid, title: title, createdAt: created, updatedAt: updated, messageCount: count)
                }
            }
        } catch {}
    }

    func createConversation(title: String = "New Chat") async {
        guard let url = URL(string: "\(baseURL)/chat/conversations") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let token = UserDefaults.standard.string(forKey: "access_token") ?? ""
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let body: [String: String] = ["title": title]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, _) = try await URLSession.shared.data(for: request)

            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let idStr = json["id"] as? String,
               let uuid = UUID(uuidString: idStr) {
                await loadConversations()
                activeConversationId = uuid
                messages = []
            }
        } catch {}
    }

    func deleteConversation(id: UUID) async {
        guard let url = URL(string: "\(baseURL)/chat/conversations/\(id.uuidString)") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        let token = UserDefaults.standard.string(forKey: "access_token") ?? ""
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (_, _) = try await URLSession.shared.data(for: request)
            await loadConversations()
            if activeConversationId == id {
                activeConversationId = nil
                messages = []
            }
        } catch {}
    }

    func switchConversation(id: UUID) async {
        activeConversationId = id
        messages = []
        await loadHistory()
    }

    // MARK: - Search

    func searchHistory(query: String) async {
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "\(baseURL)/chat/search?q=\(encoded)&limit=20") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let token = UserDefaults.standard.string(forKey: "access_token") ?? ""
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                searchResults = jsonArray.compactMap { dict -> Message? in
                    guard let role = dict["role"] as? String,
                          let content = dict["content"] as? String else { return nil }
                    return Message(role: role, content: content)
                }
            }
        } catch {}
    }
}
