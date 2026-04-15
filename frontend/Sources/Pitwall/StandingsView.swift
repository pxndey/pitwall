import SwiftUI


// ---------------------------------------------------------------------------
// MARK: - Flexible String/Int decoding
// ---------------------------------------------------------------------------

/// Decodes a JSON value that may arrive as either a String or an Int.
/// Exposes convenience properties for display.
struct StringOrInt: Decodable, Sendable {
    let rawValue: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            rawValue = "\(intVal)"
        } else if let strVal = try? container.decode(String.self) {
            rawValue = strVal
        } else if let dblVal = try? container.decode(Double.self) {
            rawValue = "\(dblVal)"
        } else {
            rawValue = ""
        }
    }

    var intValue: Int? { Int(rawValue) }
    var doubleValue: Double? { Double(rawValue) }
    var displayString: String { rawValue }
}


// ---------------------------------------------------------------------------
// MARK: - Models
// ---------------------------------------------------------------------------

struct DriverStanding: Decodable, Identifiable {
    var id: String { "\(position.rawValue)-\(familyName)" }
    let position: StringOrInt
    let givenName: String
    let familyName: String
    let constructorName: String
    let points: StringOrInt
    let wins: StringOrInt
}

struct ConstructorStanding: Decodable, Identifiable {
    var id: String { "\(position.rawValue)-\(constructorName)" }
    let position: StringOrInt
    let constructorName: String
    let points: StringOrInt
    let wins: StringOrInt
}


// ---------------------------------------------------------------------------
// MARK: - StandingsViewModel
// ---------------------------------------------------------------------------

@MainActor
final class StandingsViewModel: ObservableObject {

    @Published var driverStandings: [DriverStanding] = []
    @Published var constructorStandings: [ConstructorStanding] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let baseURL = "http://localhost:8000/api"

    private var token: String? {
        UserDefaults.standard.string(forKey: "access_token")
    }

    func loadDriverStandings() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            guard let url = URL(string: "\(baseURL)/f1/standings/drivers") else {
                errorMessage = "Invalid URL"
                return
            }
            var request = URLRequest(url: url)
            if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }

            let (data, response) = try await URLSession.shared.data(for: request)

            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                errorMessage = "Server error: HTTP \(http.statusCode)"
                return
            }

            driverStandings = try JSONDecoder().decode([DriverStanding].self, from: data)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadConstructorStandings() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            guard let url = URL(string: "\(baseURL)/f1/standings/constructors") else {
                errorMessage = "Invalid URL"
                return
            }
            var request = URLRequest(url: url)
            if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }

            let (data, response) = try await URLSession.shared.data(for: request)

            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                errorMessage = "Server error: HTTP \(http.statusCode)"
                return
            }

            constructorStandings = try JSONDecoder().decode([ConstructorStanding].self, from: data)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}


// ---------------------------------------------------------------------------
// MARK: - StandingsView
// ---------------------------------------------------------------------------

struct StandingsView: View {

    @StateObject private var viewModel = StandingsViewModel()
    @State private var selectedTab = 0

    private let bg  = Color(red: 0.05, green: 0.05, blue: 0.05)
    private let red = Color(red: 0.88, green: 0.1, blue: 0.1)

    var body: some View {
        NavigationStack {
            ZStack {
                bg.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Segmented picker
                    Picker("Standings", selection: $selectedTab) {
                        Text("Drivers").tag(0)
                        Text("Constructors").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                    Group {
                        if viewModel.isLoading {
                            loadingView
                        } else if let errMsg = viewModel.errorMessage {
                            errorView(message: errMsg)
                        } else if selectedTab == 0 {
                            if viewModel.driverStandings.isEmpty {
                                emptyView
                            } else {
                                driverList
                            }
                        } else {
                            if viewModel.constructorStandings.isEmpty {
                                emptyView
                            } else {
                                constructorList
                            }
                        }
                    }
                }
            }
            .navigationTitle("Standings")
            .navigationBarTitleDisplayMode(.large)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .task {
            await viewModel.loadDriverStandings()
            await viewModel.loadConstructorStandings()
        }
        .refreshable {
            if selectedTab == 0 {
                await viewModel.loadDriverStandings()
            } else {
                await viewModel.loadConstructorStandings()
            }
        }
    }

    // MARK: - Sub-views

    private var loadingView: some View {
        VStack(spacing: 14) {
            ProgressView()
                .tint(red)
                .scaleEffect(1.3)
            Text("Loading standings...")
                .font(.system(size: 14))
                .foregroundStyle(Color(white: 0.6))
        }
        .frame(maxHeight: .infinity)
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
                Task {
                    if selectedTab == 0 {
                        await viewModel.loadDriverStandings()
                    } else {
                        await viewModel.loadConstructorStandings()
                    }
                }
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
        .frame(maxHeight: .infinity)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "trophy")
                .font(.system(size: 40))
                .foregroundStyle(Color(white: 0.4))
            Text("No standings available")
                .font(.system(size: 16))
                .foregroundStyle(Color(white: 0.5))
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Driver List

    private var driverList: some View {
        List(viewModel.driverStandings) { driver in
            NavigationLink {
                DriverDetailView(
                    driverId: driver.familyName.lowercased(),
                    driverName: "\(driver.givenName) \(driver.familyName)"
                )
            } label: {
                driverRow(driver)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(bg)
    }

    private func driverRow(_ driver: DriverStanding) -> some View {
        HStack(alignment: .center, spacing: 12) {
            positionBadge(driver.position.intValue ?? 0)

            VStack(alignment: .leading, spacing: 3) {
                Text("\(driver.givenName) \(driver.familyName)")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Text(driver.constructorName)
                    .font(.system(size: 13))
                    .foregroundStyle(Color(white: 0.55))
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(driver.points.displayString) pts")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Text("\(driver.wins.displayString) wins")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(white: 0.55))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(red: 0.11, green: 0.11, blue: 0.11))
        )
        .listRowBackground(bg)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
    }

    // MARK: - Constructor List

    private var constructorList: some View {
        List {
            ForEach(viewModel.constructorStandings) { constructor in
                constructorRow(constructor)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(bg)
    }

    private func constructorRow(_ constructor: ConstructorStanding) -> some View {
        HStack(alignment: .center, spacing: 12) {
            positionBadge(constructor.position.intValue ?? 0)

            Text(constructor.constructorName)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Text("\(constructor.points.displayString) pts")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Text("\(constructor.wins.displayString) wins")
                    .font(.system(size: 12))
                    .foregroundStyle(Color(white: 0.55))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(red: 0.11, green: 0.11, blue: 0.11))
        )
        .listRowBackground(bg)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 5, leading: 16, bottom: 5, trailing: 16))
    }

    // MARK: - Position Badge

    private func positionBadge(_ position: Int) -> some View {
        let color: Color = {
            switch position {
            case 1: return Color(red: 1.0, green: 0.84, blue: 0.0)   // gold
            case 2: return Color(white: 0.75)                         // silver
            case 3: return Color(red: 0.80, green: 0.50, blue: 0.20) // bronze
            default: return red
            }
        }()

        return ZStack {
            Circle()
                .fill(color)
                .frame(width: 32, height: 32)
            Text("\(position)")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
    }
}


// ---------------------------------------------------------------------------
// MARK: - Preview
// ---------------------------------------------------------------------------

#Preview {
    StandingsView()
}
