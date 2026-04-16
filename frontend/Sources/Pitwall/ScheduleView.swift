import SwiftUI


// ---------------------------------------------------------------------------
// MARK: - Jolpica REST API response models
// ---------------------------------------------------------------------------

private struct JolpicaResponse: Decodable {
    let mrData: MRData

    enum CodingKeys: String, CodingKey {
        case mrData = "MRData"
    }
}

private struct MRData: Decodable {
    let raceTable: RaceTable

    enum CodingKeys: String, CodingKey {
        case raceTable = "RaceTable"
    }
}

private struct RaceTable: Decodable {
    let races: [F1Race]

    enum CodingKeys: String, CodingKey {
        case races = "Races"
    }
}

struct F1Race: Decodable, Sendable {
    let season: String
    let round: String
    let raceName: String
    let circuit: F1Circuit
    let date: String
    let time: String?

    enum CodingKeys: String, CodingKey {
        case season
        case round
        case raceName
        case circuit = "Circuit"
        case date
        case time
    }
}

struct F1Circuit: Decodable, Sendable {
    let circuitName: String
    let location: F1Location

    enum CodingKeys: String, CodingKey {
        case circuitName
        case location = "Location"
    }
}

struct F1Location: Decodable, Sendable {
    let country: String
    let locality: String
}


// ---------------------------------------------------------------------------
// MARK: - ScheduleViewModel
// ---------------------------------------------------------------------------

@MainActor
final class ScheduleViewModel: ObservableObject {

    @Published var races: [F1Race] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let url = URL(string: "https://api.jolpi.ca/ergast/f1/current.json")!
            let (data, response) = try await URLSession.shared.data(from: url)

            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                errorMessage = "Server error: HTTP \(httpResponse.statusCode)"
                return
            }

            let decoded = try JSONDecoder().decode(JolpicaResponse.self, from: data)
            races = decoded.mrData.raceTable.races
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}


// ---------------------------------------------------------------------------
// MARK: - Country → flag emoji helper
// ---------------------------------------------------------------------------

private let countryFlagMap: [String: String] = [
    "Australia": "🇦🇺",
    "China": "🇨🇳",
    "Japan": "🇯🇵",
    "Bahrain": "🇧🇭",
    "Saudi Arabia": "🇸🇦",
    "United States": "🇺🇸",
    "USA": "🇺🇸",
    "Miami": "🇺🇸",
    "Italy": "🇮🇹",
    "Monaco": "🇲🇨",
    "Canada": "🇨🇦",
    "Spain": "🇪🇸",
    "Austria": "🇦🇹",
    "United Kingdom": "🇬🇧",
    "UK": "🇬🇧",
    "Hungary": "🇭🇺",
    "Belgium": "🇧🇪",
    "Netherlands": "🇳🇱",
    "Azerbaijan": "🇦🇿",
    "Singapore": "🇸🇬",
    "Mexico": "🇲🇽",
    "Brazil": "🇧🇷",
    "Qatar": "🇶🇦",
    "UAE": "🇦🇪",
    "Abu Dhabi": "🇦🇪",
]

private func flag(for country: String) -> String {
    if let f = countryFlagMap[country] { return f }
    for (key, value) in countryFlagMap where country.localizedCaseInsensitiveContains(key) {
        return value
    }
    return "🏁"
}


// ---------------------------------------------------------------------------
// MARK: - Date formatting helpers
// ---------------------------------------------------------------------------

/// Parses a Jolpica/Ergast date string "YYYY-MM-DD" to a Swift `Date`.
private let isoDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(secondsFromGMT: 0)
    return f
}()

/// Formats a date to a display string like "Mar 14".
private let displayDateFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "MMM d"
    f.locale = Locale(identifier: "en_US_POSIX")
    return f
}()

/// Returns a short range string like "Mar 14–16" given the race's weekend
/// start (Friday practice) and race day (Sunday).
/// `raceDateString` is "YYYY-MM-DD" (the race day).
private func weekendRange(from raceDateString: String) -> String {
    guard let raceDate = isoDateFormatter.date(from: raceDateString) else {
        return raceDateString
    }
    // Race weekends are Friday–Sunday; practice 1 is typically -2 days
    let fridayDate = Calendar.current.date(byAdding: .day, value: -2, to: raceDate) ?? raceDate
    let friday = displayDateFormatter.string(from: fridayDate)
    let fridayComponents = Calendar.current.dateComponents([.month], from: fridayDate)
    let sundayComponents = Calendar.current.dateComponents([.month], from: raceDate)
    if fridayComponents.month == sundayComponents.month {
        let dayOnly = DateFormatter()
        dayOnly.dateFormat = "d"
        dayOnly.locale = Locale(identifier: "en_US_POSIX")
        return "\(friday)–\(dayOnly.string(from: raceDate))"
    }
    let sunday = displayDateFormatter.string(from: raceDate)
    return "\(friday)–\(sunday)"
}

/// Returns `true` when the race day is strictly in the past.
private func isPast(_ raceDateString: String) -> Bool {
    guard let raceDate = isoDateFormatter.date(from: raceDateString) else { return false }
    return raceDate < Calendar.current.startOfDay(for: Date())
}

/// Returns `true` when this race is the earliest upcoming one in the list.
private func isNext(in races: [F1Race], race: F1Race) -> Bool {
    let today = Calendar.current.startOfDay(for: Date())
    guard let raceDate = isoDateFormatter.date(from: race.date), raceDate >= today else {
        return false
    }
    let upcoming = races.compactMap { r -> (F1Race, Date)? in
        guard let d = isoDateFormatter.date(from: r.date), d >= today else { return nil }
        return (r, d)
    }.sorted { $0.1 < $1.1 }
    return upcoming.first?.0.round == race.round
}


// ---------------------------------------------------------------------------
// MARK: - RaceDetailView
// ---------------------------------------------------------------------------

private struct RaceDetailView: View {
    let race: F1Race
    @State private var showChatSheet = false
    @State private var showLapChart = false
    @State private var notificationScheduled = false
    @State private var raceResults: [[String: Any]] = []
    @State private var isLoadingResults = false

    private let bg  = Color(red: 0.02, green: 0.02, blue: 0.024)
    private let red = Color(red: 0.88, green: 0.1, blue: 0.1)

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Text(flag(for: race.circuit.location.country))
                                .font(.system(size: 32))
                            VStack(alignment: .leading, spacing: 4) {
                                Text(race.raceName)
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundStyle(.white)
                                Text("Round \(race.round)")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Color(white: 0.65))
                            }
                            Spacer()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.11, green: 0.11, blue: 0.11))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                    // Circuit Info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("CIRCUIT INFORMATION")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(red)
                            .tracking(1)

                        VStack(alignment: .leading, spacing: 8) {
                            InfoRow(label: "Circuit", value: race.circuit.circuitName)
                            InfoRow(label: "Location", value: "\(race.circuit.location.locality), \(race.circuit.location.country)")
                        }
                    }
                    .padding(.horizontal, 16)

                    // Date & Time
                    VStack(alignment: .leading, spacing: 12) {
                        Text("RACE WEEKEND")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(red)
                            .tracking(1)

                        VStack(alignment: .leading, spacing: 8) {
                            if let raceDate = isoDateFormatter.date(from: race.date) {
                                let fridayDate = Calendar.current.date(byAdding: .day, value: -2, to: raceDate) ?? raceDate
                                InfoRow(label: "Practice 1", value: formatDateWithDay(fridayDate))
                                InfoRow(label: "Practice 2", value: formatDateWithDay(Calendar.current.date(byAdding: .day, value: 1, to: fridayDate) ?? fridayDate))
                                InfoRow(label: "Practice 3 & Qualifying", value: formatDateWithDay(Calendar.current.date(byAdding: .day, value: 2, to: fridayDate) ?? fridayDate))
                                InfoRow(label: "Race Day", value: formatDateWithDay(raceDate))
                                if let time = race.time {
                                    InfoRow(label: "Race Time", value: time)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 16)

                    // Race Results (past races only)
                    if !raceResults.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("RACE RESULTS")
                                .font(.system(size: 12, weight: .heavy))
                                .foregroundStyle(red)
                                .tracking(1)

                            ForEach(0..<raceResults.count, id: \.self) { index in
                                let result = raceResults[index]
                                let position = result["position"] as? String ?? "\(result["position"] as? Int ?? 0)"
                                let givenName = result["givenName"] as? String ?? ""
                                let familyName = result["familyName"] as? String ?? ""
                                let constructor = result["constructorName"] as? String ?? ""
                                let time = result["time"] as? String ?? ""
                                let points = result["points"] as? String ?? "\(result["points"] as? Double ?? 0)"
                                let status = result["status"] as? String ?? ""

                                HStack {
                                    Text("P\(position)")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundStyle(index < 3 ? red : .white)
                                        .frame(width: 36, alignment: .leading)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(givenName) \(familyName)")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(.white)
                                            .lineLimit(1)
                                        Text(constructor)
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color(white: 0.65))
                                    }

                                    Spacer()

                                    VStack(alignment: .trailing, spacing: 2) {
                                        Text(time.isEmpty ? status : time)
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color(white: 0.65))
                                            .lineLimit(1)
                                        Text("\(points) pts")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundStyle(.white)
                                    }
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 12)
                                .background(Color(red: 0.11, green: 0.11, blue: 0.11))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                                )
                            }
                        }
                        .padding(.horizontal, 16)

                        // Lap Chart button
                        Button {
                            showLapChart = true
                        } label: {
                            HStack {
                                Image(systemName: "chart.xyaxis.line")
                                Text("View Lap Chart")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(red: 0.11, green: 0.11, blue: 0.11))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(red.opacity(0.5), lineWidth: 1)
                            )
                        }
                        .padding(.horizontal, 16)
                    }

                    if isLoadingResults {
                        ProgressView()
                            .tint(red)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }

                    // Action Buttons
                    VStack(spacing: 10) {
                        Button {
                            showChatSheet = true
                        } label: {
                            HStack {
                                Image(systemName: "bubble.left.fill")
                                Text("Ask about this race")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(red)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(color: Color(red: 0.88, green: 0.1, blue: 0.1).opacity(0.4), radius: 8, x: 0, y: 2)
                        }

                        Button {
                            Task {
                                await NotificationManager.shared.scheduleNotifications(for: race)
                                notificationScheduled = true
                            }
                        } label: {
                            HStack {
                                Image(systemName: notificationScheduled ? "bell.fill" : "bell")
                                Text(notificationScheduled ? "Notifications scheduled" : "Notify me for all sessions")
                            }
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(notificationScheduled ? Color(white: 0.5) : red)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(red: 0.11, green: 0.11, blue: 0.11))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .strokeBorder(notificationScheduled ? Color(white: 0.2) : red.opacity(0.5), lineWidth: 1)
                            )
                        }
                        .disabled(notificationScheduled)
                    }
                    .padding(.horizontal, 16)

                    Spacer(minLength: 20)
                }
                .padding(.vertical, 16)
            }
        }
        .navigationTitle("Race Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(isPresented: $showChatSheet) {
            RaceContextChatView(race: race)
        }
        .sheet(isPresented: $showLapChart) {
            NavigationStack {
                LapChartView(season: race.season, round: race.round)
            }
        }
        .task {
            if isPast(race.date) {
                await fetchRaceResults()
            }
        }
    }

    private func fetchRaceResults() async {
        isLoadingResults = true
        defer { isLoadingResults = false }

        guard let url = URL(string: "http://localhost:8000/api/f1/race-results/\(race.season)/\(race.round)") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        let token = UserDefaults.standard.string(forKey: "access_token") ?? ""
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let results = json["results"] as? [[String: Any]] {
                raceResults = results
            }
        } catch {}
    }

    private func formatDateWithDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy (EEEE)"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }
}

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color(white: 0.65))
            Spacer()
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.trailing)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(red: 0.11, green: 0.11, blue: 0.11))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
        )
    }
}

// ---------------------------------------------------------------------------
// MARK: - RaceContextChatView
// ---------------------------------------------------------------------------

private struct RaceContextChatView: View {
    let race: F1Race
    @Environment(\.dismiss) var dismiss
    @StateObject private var chatViewModel = ChatViewModel()
    @State private var inputText: String = ""

    private let bgTop    = Color(red: 0.02, green: 0.02, blue: 0.024)
    private let bgBottom = Color(red: 0.15, green: 0.0, blue: 0.0)
    private let red      = Color(red: 0.88, green: 0.1, blue: 0.1)

    var body: some View {
        ZStack {
            LinearGradient(colors: [bgTop, bgBottom], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button("Close") { dismiss() }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(red)
                        .accessibilityLabel("Close")
                    Spacer()
                    Text("\(race.raceName) - \(race.circuit.circuitName)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Text("")
                        .font(.system(size: 14))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(red: 0.1, green: 0.1, blue: 0.1))

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 10) {
                            if chatViewModel.messages.isEmpty && !chatViewModel.isLoading {
                                VStack(spacing: 8) {
                                    Text("Race Context Loaded")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                    Text("Ask me anything about \(race.raceName)")
                                        .font(.system(size: 12))
                                        .foregroundColor(Color(white: 0.6))
                                }
                                .padding(.vertical, 32)
                            } else {
                                ForEach(chatViewModel.messages) { message in
                                    messageBubble(message)
                                        .id(message.id)
                                }
                                if chatViewModel.isLoading {
                                    HStack {
                                        ProgressView()
                                            .tint(red)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .id("thinking")
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .onChange(of: chatViewModel.messages.count) {
                        withAnimation {
                            proxy.scrollTo(chatViewModel.messages.last?.id, anchor: .bottom)
                        }
                    }
                }

                // Input Bar
                HStack(spacing: 8) {
                    TextField("Ask about the race...", text: $inputText)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 14))

                    Button {
                        Task {
                            await chatViewModel.send(text: inputText, circuitContext: race.circuit.circuitName)
                            inputText = ""
                        }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color(white: 0.3) : red)
                    }
                    .accessibilityLabel("Send message")
                    .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(red: 0.1, green: 0.1, blue: 0.1))
            }
        }
        .task {
            // Load initial greeting with circuit context
            await chatViewModel.send(text: "brief me on \(race.raceName) at \(race.circuit.circuitName)", circuitContext: race.circuit.circuitName)
        }
    }

    @ViewBuilder
    private func messageBubble(_ message: ChatViewModel.Message) -> some View {
        HStack {
            if message.role == "user" {
                Spacer()
                Text(raceContextMarkdown(message.content))
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(red.opacity(0.8))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                Text(raceContextMarkdown(message.content))
                    .font(.system(size: 14))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(Color(red: 0.12, green: 0.12, blue: 0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .contextMenu {
                        Button {
                            shareText(message.content)
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    }
                Spacer()
            }
        }
        .padding(.vertical, 4)
    }

    private func shareText(_ text: String) {
        let av = UIActivityViewController(activityItems: [text], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(av, animated: true)
        }
    }

    private func raceContextMarkdown(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace))) ?? AttributedString(text)
    }
}

// ---------------------------------------------------------------------------
// MARK: - RaceCardView
// ---------------------------------------------------------------------------

private struct RaceCardView: View {

    let race: F1Race
    let isNextRace: Bool
    let isPastRace: Bool

    private let bg         = Color(red: 0.02, green: 0.02, blue: 0.024)
    private let cardBg     = Color(red: 0.11, green: 0.11, blue: 0.11)
    private let cardBgNext = Color(red: 0.14, green: 0.10, blue: 0.10)
    private let red        = Color(red: 0.88, green: 0.1, blue: 0.1)

    var body: some View {
        NavigationLink {
            RaceDetailView(race: race)
        } label: {
            HStack(alignment: .center, spacing: 14) {

                // Round badge
                ZStack {
                    Circle()
                        .fill(isPastRace ? Color(white: 0.3) : red)
                        .frame(width: 36, height: 36)
                    Text(race.round)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }

                // Race info
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(flag(for: race.circuit.location.country))
                            .font(.system(size: 15))
                        Text(race.raceName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    Text(race.circuit.circuitName)
                        .font(.system(size: 13))
                        .foregroundStyle(Color(white: 0.65))
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                // Right-side: date range + optional "NEXT RACE" badge
                VStack(alignment: .trailing, spacing: 4) {
                    Text(weekendRange(from: race.date))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isPastRace ? Color(white: 0.55) : red)

                    if isNextRace {
                        Text("NEXT RACE")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(red)
                            .clipShape(Capsule())
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isNextRace ? cardBgNext : cardBg)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(
                                isNextRace ? red.opacity(0.5) : Color.clear,
                                lineWidth: 1
                            )
                    )
            )
            .opacity(isPastRace ? 0.6 : 1.0)
            .listRowBackground(bg)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
        }
        .buttonStyle(.plain)
    }
}


// ---------------------------------------------------------------------------
// MARK: - ScheduleView
// ---------------------------------------------------------------------------

struct ScheduleView: View {

    @StateObject private var viewModel = ScheduleViewModel()
    @State private var allNotificationsScheduled = false

    private let bg  = Color(red: 0.02, green: 0.02, blue: 0.024)
    private let red = Color(red: 0.88, green: 0.1, blue: 0.1)

    var body: some View {
        NavigationStack {
            ZStack {
                bg.ignoresSafeArea()

                Group {
                    if viewModel.isLoading {
                        loadingView
                    } else if let errMsg = viewModel.errorMessage {
                        errorView(message: errMsg)
                    } else if viewModel.races.isEmpty {
                        emptyView
                    } else {
                        raceList
                    }
                }
            }
            .navigationTitle("2025 Season")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        Task {
                            await NotificationManager.shared.scheduleAllUpcoming(races: viewModel.races)
                            allNotificationsScheduled = true
                        }
                    } label: {
                        Image(systemName: allNotificationsScheduled ? "bell.fill" : "bell")
                            .foregroundColor(allNotificationsScheduled ? Color(white: 0.55) : red)
                    }
                    .accessibilityLabel("Schedule notifications")
                    .disabled(allNotificationsScheduled || viewModel.races.isEmpty)
                }
            }
        }
        .task {
            await viewModel.load()
        }
    }

    // MARK: Sub-views

    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(red)
                .scaleEffect(1.3)
            Text("Loading schedule…")
                .font(.system(size: 14))
                .foregroundStyle(Color(white: 0.6))
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: 18) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(red)
            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(Color(white: 0.6))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            Button {
                Task { await viewModel.load() }
            } label: {
                Text("Retry")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 10)
                    .background(red)
                    .clipShape(Capsule())
                    .shadow(color: Color(red: 0.88, green: 0.1, blue: 0.1).opacity(0.4), radius: 8, x: 0, y: 2)
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(Color(white: 0.55))
            Text("No races found")
                .font(.system(size: 16))
                .foregroundStyle(Color(white: 0.5))
        }
    }

    private var raceList: some View {
        List {
            ForEach(viewModel.races, id: \.round) { race in
                RaceCardView(
                    race: race,
                    isNextRace: isNext(in: viewModel.races, race: race),
                    isPastRace: isPast(race.date)
                )
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(bg)
    }
}


// ---------------------------------------------------------------------------
// MARK: - Preview
// ---------------------------------------------------------------------------

#Preview {
    ScheduleView()
}
