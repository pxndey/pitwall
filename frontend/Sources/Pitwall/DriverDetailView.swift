import SwiftUI

@MainActor
final class DriverDetailViewModel: ObservableObject {
    @Published var driverInfo: [String: Any]?
    @Published var standing: [String: Any]?
    @Published var seasonResults: [[String: Any]] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let baseURL = "http://localhost:8000/api"

    func load(driverId: String, season: Int = 2025) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let url = URL(string: "\(baseURL)/f1/driver/\(driverId)/season/\(season)") else { return }
        var request = URLRequest(url: url)
        let token = UserDefaults.standard.string(forKey: "access_token") ?? ""
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                driverInfo = json["driver_info"] as? [String: Any]
                standing = json["standing"] as? [String: Any]
                seasonResults = json["season_results"] as? [[String: Any]] ?? []
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

struct DriverDetailView: View {
    let driverId: String
    let driverName: String

    @StateObject private var viewModel = DriverDetailViewModel()

    private let bg   = Color(red: 0.02, green: 0.02, blue: 0.024)
    private let red  = Color(red: 0.88, green: 0.1, blue: 0.1)
    private let card = Color(red: 0.11, green: 0.11, blue: 0.11)

    // Computed stats
    private var totalPoints: Double {
        viewModel.seasonResults.reduce(0.0) { sum, r in
            sum + (Double("\(r["points"] ?? "0")") ?? 0)
        }
    }
    private var bestFinish: Int {
        viewModel.seasonResults.compactMap { r -> Int? in
            if let p = r["position"] as? Int { return p }
            if let p = r["position"] as? String { return Int(p) }
            return nil
        }.min() ?? 0
    }
    private var dnfCount: Int {
        viewModel.seasonResults.filter { r in
            let status = "\(r["status"] ?? "")"
            return !status.isEmpty && status != "Finished" && !status.contains("+")
        }.count
    }
    private var avgFinish: Double {
        let positions = viewModel.seasonResults.compactMap { r -> Double? in
            if let p = r["position"] as? Int { return Double(p) }
            if let p = r["position"] as? String { return Double(p) }
            return nil
        }
        guard !positions.isEmpty else { return 0 }
        return positions.reduce(0, +) / Double(positions.count)
    }

    private func positionColor(_ pos: Int) -> Color {
        switch pos {
        case 1: return Color(red: 1.0, green: 0.84, blue: 0.0)
        case 2: return Color(white: 0.75)
        case 3: return Color(red: 0.8, green: 0.5, blue: 0.2)
        default: return .white
        }
    }

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            if viewModel.isLoading {
                VStack(spacing: 14) {
                    ProgressView().tint(red).scaleEffect(1.3)
                    Text("Loading driver data...").font(.system(size: 14)).foregroundStyle(Color(white: 0.6))
                }
            } else if let err = viewModel.errorMessage {
                VStack(spacing: 18) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 40)).foregroundStyle(red)
                    Text(err).font(.system(size: 14)).foregroundStyle(Color(white: 0.6)).multilineTextAlignment(.center).padding(.horizontal, 32)
                    Button { Task { await viewModel.load(driverId: driverId) } } label: {
                        Text("Retry").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white).padding(.horizontal, 28).padding(.vertical, 10).background(red).clipShape(Capsule()).shadow(color: Color(red: 0.88, green: 0.1, blue: 0.1).opacity(0.4), radius: 8, x: 0, y: 2)
                    }
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Header card
                        headerCard

                        // Stats summary
                        statsRow

                        // Season results
                        if !viewModel.seasonResults.isEmpty {
                            resultsSection
                        }

                        Spacer(minLength: 20)
                    }
                    .padding(.vertical, 16)
                }
            }
        }
        .navigationTitle(driverName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            await viewModel.load(driverId: driverId)
        }
    }

    // MARK: - Header Card
    private var headerCard: some View {
        HStack(spacing: 16) {
            // Position badge
            if let standing = viewModel.standing {
                let pos = Int("\(standing["position"] ?? "0")") ?? 0
                ZStack {
                    Circle()
                        .fill(pos == 1 ? Color(red: 1.0, green: 0.84, blue: 0.0) :
                              pos == 2 ? Color(white: 0.75) :
                              pos == 3 ? Color(red: 0.8, green: 0.5, blue: 0.2) : red)
                        .frame(width: 56, height: 56)
                    Text("P\(pos)")
                        .font(.system(size: 18, weight: .black, design: .rounded))
                        .foregroundStyle(pos <= 3 ? Color.black : Color.white)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(driverName)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)

                if let info = viewModel.driverInfo {
                    if let nationality = info["nationality"] as? String {
                        Text(nationality)
                            .font(.system(size: 14))
                            .foregroundStyle(Color(white: 0.65))
                    }
                }

                if let standing = viewModel.standing {
                    let pts = "\(standing["points"] ?? "0")"
                    let wins = "\(standing["wins"] ?? "0")"
                    HStack(spacing: 12) {
                        Text("\(pts) pts").font(.system(size: 14, weight: .semibold)).foregroundStyle(red)
                        Text("\(wins) wins").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color(white: 0.65))
                    }
                }

                if let standing = viewModel.standing {
                    if let team = standing["constructorName"] as? String {
                        Text(team).font(.system(size: 13)).foregroundStyle(Color(white: 0.58))
                    }
                }
            }
            Spacer()
        }
        .padding(16)
        .background(card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Stats Row
    private var statsRow: some View {
        HStack(spacing: 0) {
            statCell(label: "AVG", value: avgFinish > 0 ? String(format: "P%.1f", avgFinish) : "—")
            statCell(label: "BEST", value: bestFinish > 0 ? "P\(bestFinish)" : "—")
            statCell(label: "PTS", value: "\(Int(totalPoints))")
            statCell(label: "DNF", value: "\(dnfCount)")
        }
        .padding(.horizontal, 16)
    }

    private func statCell(label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 10, weight: .heavy))
                .foregroundStyle(Color(white: 0.58))
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(card)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
        )
        .padding(.horizontal, 2)
    }

    // MARK: - Results Section
    private var resultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RACE RESULTS")
                .font(.system(size: 12, weight: .heavy))
                .foregroundStyle(red)
                .tracking(1)
                .padding(.horizontal, 16)

            ForEach(Array(viewModel.seasonResults.enumerated()), id: \.offset) { _, result in
                let round = "\(result["race_round"] ?? result["round"] ?? "?")"
                let raceName = "\(result["race_name"] ?? result["raceName"] ?? "Unknown")"
                let pos: Int = {
                    if let p = result["position"] as? Int { return p }
                    if let p = result["position"] as? String, let pi = Int(p) { return pi }
                    return 0
                }()
                let pts = "\(result["points"] ?? "0")"
                let status = "\(result["status"] ?? "")"

                HStack(spacing: 12) {
                    // Round badge
                    ZStack {
                        Circle()
                            .fill(Color(white: 0.2))
                            .frame(width: 30, height: 30)
                        Text(round)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(raceName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        if !status.isEmpty && status != "Finished" && !status.contains("+") {
                            Text(status)
                                .font(.system(size: 11))
                                .foregroundStyle(red)
                        }
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("P\(pos)")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(positionColor(pos))
                        Text("\(pts) pts")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(white: 0.5))
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(card)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.08), lineWidth: 0.5)
                )
                .padding(.horizontal, 16)
            }
        }
    }
}
