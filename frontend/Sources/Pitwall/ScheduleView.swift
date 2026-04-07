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
// MARK: - RaceCardView
// ---------------------------------------------------------------------------

private struct RaceCardView: View {

    let race: F1Race
    let isNextRace: Bool
    let isPastRace: Bool

    private let bg         = Color(red: 0.05, green: 0.05, blue: 0.05)
    private let cardBg     = Color(red: 0.11, green: 0.11, blue: 0.11)
    private let cardBgNext = Color(red: 0.14, green: 0.10, blue: 0.10)
    private let red        = Color(red: 0.88, green: 0.1, blue: 0.1)

    var body: some View {
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
                    .foregroundStyle(Color(white: 0.55))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            // Right-side: date range + optional "NEXT RACE" badge
            VStack(alignment: .trailing, spacing: 4) {
                Text(weekendRange(from: race.date))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isPastRace ? Color(white: 0.4) : red)

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
}


// ---------------------------------------------------------------------------
// MARK: - ScheduleView
// ---------------------------------------------------------------------------

struct ScheduleView: View {

    @StateObject private var viewModel = ScheduleViewModel()

    private let bg  = Color(red: 0.05, green: 0.05, blue: 0.05)
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
            }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.system(size: 40))
                .foregroundStyle(Color(white: 0.4))
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
