import SwiftUI

struct HomeView: View {

    @StateObject private var chatViewModel = ChatViewModel()
    @State private var inputText: String = ""
    @State private var showConversations = false
    @State private var showSearch = false
    @State private var searchQuery = ""
    @State private var dashboard: DriverDashboard?

    // MARK: - Colors

    private let bgTop     = Color(red: 0.02, green: 0.02, blue: 0.024)
    private let bgBottom  = Color(red: 0.15, green: 0.0,  blue: 0.0)
    private let redAccent = Color(red: 0.88, green: 0.1,  blue: 0.1)
    private let bubbleDark = Color(red: 0.12, green: 0.12, blue: 0.12)
    private let barBg     = Color(red: 0.1,  green: 0.1,  blue: 0.1)

    // MARK: - Body

    var body: some View {
        ZStack {
            // Full-screen gradient background
            LinearGradient(
                colors: [bgTop, bgBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                navHeader
                messagesArea
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .safeAreaInset(edge: .bottom) {
            inputBar
        }
    }

    // MARK: - Nav Header

    private var navHeader: some View {
        ZStack {
            HStack {
                Button { showConversations = true } label: {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(redAccent)
                }
                .accessibilityLabel("Conversations")
                .padding(.leading, 20)
                Spacer()
                Button { showSearch.toggle() } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(redAccent)
                }
                .accessibilityLabel("Search messages")
                .padding(.trailing, 20)
            }

            Text("PITCREW")
                .font(.system(size: 20, weight: .black, design: .default))
                .tracking(4)
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, topSafeAreaPadding)
        .padding(.bottom, 12)
        .background(bgTop.opacity(0.95))
    }

    // MARK: - Messages Area

    private var messagesArea: some View {
        ZStack(alignment: .top) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 10) {
                        // Load More button pinned to top when older history exists
                        if chatViewModel.hasMoreHistory && !chatViewModel.messages.isEmpty {
                            Button {
                                Task { await chatViewModel.loadMoreHistory() }
                            } label: {
                                HStack(spacing: 6) {
                                    if chatViewModel.isLoadingHistory {
                                        ProgressView()
                                            .progressViewStyle(CircularProgressViewStyle(tint: redAccent))
                                            .scaleEffect(0.7)
                                    } else {
                                        Image(systemName: "arrow.up.circle")
                                            .font(.system(size: 13))
                                            .foregroundColor(redAccent)
                                    }
                                    Text(chatViewModel.isLoadingHistory ? "Loading..." : "Load earlier messages")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(redAccent)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color(red: 0.12, green: 0.05, blue: 0.05))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .disabled(chatViewModel.isLoadingHistory)
                            .id("loadMore")
                        }

                        // Dashboard card
                        if let db = dashboard {
                            dashboardCard(db)
                        }

                        if chatViewModel.messages.isEmpty && !chatViewModel.isLoading {
                            emptyState
                        } else {
                            ForEach(chatViewModel.messages) { message in
                                messageBubble(message)
                                    .id(message.id)
                            }
                            if chatViewModel.isLoading && chatViewModel.streamingText.isEmpty {
                                thinkingBubble
                                    .id("thinking")
                            }
                            // Streaming text bubble
                            if !chatViewModel.streamingText.isEmpty {
                                HStack {
                                    Text(markdownContent(chatViewModel.streamingText + " ▍"))
                                        .font(.body)
                                        .foregroundColor(.white)
                                        .padding(12)
                                        .background(bubbleDark)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .leading)
                                    Spacer(minLength: 60)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .id("streaming")
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                }
                .refreshable {
                    await chatViewModel.loadHistory()
                    await fetchDashboard()
                }
                .task {
                    await chatViewModel.loadHistory()
                    await chatViewModel.loadConversations()
                    await fetchDashboard()
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: chatViewModel.messages.count) {
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: chatViewModel.isLoading) {
                    if chatViewModel.isLoading {
                        withAnimation {
                            proxy.scrollTo("thinking", anchor: .bottom)
                        }
                    }
                }
            }

            // Search overlay
            if showSearch {
                searchOverlay
            }
        }
        .sheet(isPresented: $showConversations) {
            ConversationListView(chatViewModel: chatViewModel)
        }
    }

    // MARK: - Bubble Views

    @ViewBuilder
    private func messageBubble(_ message: ChatViewModel.Message) -> some View {
        let isUser = message.role == "user"

        HStack {
            if isUser { Spacer(minLength: 60) }

            if isUser {
                Text(markdownContent(message.content))
                    .font(.body)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(redAccent)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .trailing)
            } else {
                Text(markdownContent(message.content))
                    .font(.body)
                    .foregroundColor(.white)
                    .padding(12)
                    .background(bubbleDark)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .frame(maxWidth: UIScreen.main.bounds.width * 0.75, alignment: .leading)
                    .contextMenu {
                        Button {
                            shareText(message.content)
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
            }

            if !isUser { Spacer(minLength: 60) }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }

    private var thinkingBubble: some View {
        HStack {
            HStack(spacing: 6) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(0.8)
                Text("thinking...")
                    .font(.body)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(12)
            .background(bubbleDark)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Spacer(minLength: 60)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        Text("Ask me anything about the race.")
            .font(.body)
            .foregroundColor(.gray)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.top, 80)
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.white.opacity(0.1))

            HStack(alignment: .bottom, spacing: 10) {
                TextField("Message PitCrew...", text: $inputText, axis: .vertical)
                    .lineLimit(1...4)
                    .font(.body)
                    .foregroundColor(.white)
                    .tint(redAccent)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.18, green: 0.18, blue: 0.18))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                Button {
                    hapticSend()
                    let text = inputText
                    inputText = ""
                    Task {
                        await chatViewModel.sendStreaming(text: text)
                    }
                } label: {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(isSendDisabled ? .gray : redAccent)
                        .padding(10)
                }
                .accessibilityLabel("Send message")
                .disabled(isSendDisabled)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .padding(.bottom, bottomSafeAreaPadding)
        }
        .background(barBg)
    }

    // MARK: - Helpers

    private var isSendDisabled: Bool {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chatViewModel.isLoading
    }

    private func markdownContent(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
    }

    private func hapticSend() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let last = chatViewModel.messages.last {
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    private var topSafeAreaPadding: CGFloat {
        (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows
            .first?.safeAreaInsets.top ?? 0)
    }

    private var bottomSafeAreaPadding: CGFloat {
        (UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.windows
            .first?.safeAreaInsets.bottom ?? 0)
    }

    // MARK: - Dashboard

    private struct DriverDashboard {
        let driverId: String
        let championshipPosition: Int
        let championshipPoints: Double
        let lastRaceName: String
        let lastRacePosition: Int
        let lastRacePoints: Double
        let nextRaceName: String
        let nextCircuitName: String
        let nextRaceDate: String
    }

    private func fetchDashboard() async {
        guard let url = URL(string: "\(APIConfig.baseURL)/f1/driver-dashboard") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let token = UserDefaults.standard.string(forKey: "access_token") ?? ""
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if json["error"] != nil { return }

                dashboard = DriverDashboard(
                    driverId: json["driver_id"] as? String ?? "",
                    championshipPosition: json["championship_position"] as? Int ?? 0,
                    championshipPoints: json["championship_points"] as? Double ?? 0,
                    lastRaceName: json["last_race_name"] as? String ?? "",
                    lastRacePosition: json["last_race_position"] as? Int ?? 0,
                    lastRacePoints: json["last_race_points"] as? Double ?? 0,
                    nextRaceName: json["next_race_name"] as? String ?? "",
                    nextCircuitName: json["next_circuit_name"] as? String ?? "",
                    nextRaceDate: json["next_race_date"] as? String ?? ""
                )
            }
        } catch {}
    }

    @ViewBuilder
    private func dashboardCard(_ db: DriverDashboard) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                // Position badge
                ZStack {
                    Circle()
                        .fill(redAccent)
                        .frame(width: 40, height: 40)
                    Text("P\(db.championshipPosition)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(db.driverId)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text("\(String(format: "%.0f", db.championshipPoints)) pts")
                        .font(.system(size: 13))
                        .foregroundColor(Color(white: 0.65))
                }

                Spacer()
            }

            HStack {
                Text("Last: P\(db.lastRacePosition) at \(db.lastRaceName)")
                    .font(.system(size: 12))
                    .foregroundColor(Color(white: 0.65))
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Next: \(db.nextRaceName)")
                        .font(.system(size: 12))
                        .foregroundColor(Color(white: 0.65))
                    if let nextDate = parseDateFlexible(db.nextRaceDate) {
                        Text(nextDate, style: .timer)
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(redAccent)
                    }
                }
            }
        }
        .padding(14)
        .background(Color(red: 0.11, green: 0.11, blue: 0.11))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }

    private func parseDateFlexible(_ dateStr: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: dateStr) { return d }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        return f.date(from: dateStr)
    }

    // MARK: - Search Overlay

    private var searchOverlay: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color(white: 0.65))
                TextField("Search messages...", text: $searchQuery)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .tint(redAccent)
                    .onChange(of: searchQuery) {
                        Task {
                            try? await Task.sleep(nanoseconds: 300_000_000)
                            if !searchQuery.isEmpty {
                                await chatViewModel.searchHistory(query: searchQuery)
                            } else {
                                chatViewModel.searchResults = []
                            }
                        }
                    }
                Button {
                    showSearch = false
                    searchQuery = ""
                    chatViewModel.searchResults = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Color(white: 0.65))
                }
                .accessibilityLabel("Close")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(red: 0.12, green: 0.12, blue: 0.12))

            if !chatViewModel.searchResults.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(chatViewModel.searchResults) { result in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(result.role.uppercased())
                                    .font(.system(size: 10, weight: .heavy))
                                    .foregroundColor(redAccent)
                                Text(result.content)
                                    .font(.system(size: 13))
                                    .foregroundColor(.white)
                                    .lineLimit(3)
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(red: 0.11, green: 0.11, blue: 0.11))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                            )
                            .onTapGesture {
                                showSearch = false
                                searchQuery = ""
                                chatViewModel.searchResults = []
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: 300)
                .background(Color(red: 0.08, green: 0.08, blue: 0.08))
            }
        }
    }

    // MARK: - Share Helper

    private func shareText(_ text: String) {
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
    }
}

// MARK: - Preview

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
}
