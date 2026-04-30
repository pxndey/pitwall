import SwiftUI
import Charts

// LapEntry model
struct LapEntry: Identifiable {
    let id = UUID()
    let driverId: String
    let lap: Int
    let position: Int
}

// ViewModel
@MainActor
final class LapChartViewModel: ObservableObject {
    @Published var lapData: [LapEntry] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let baseURL = "\(APIConfig.baseURL)"

    func loadLaps(season: String, round: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        guard let url = URL(string: "\(baseURL)/f1/laps/\(season)/\(round)") else { return }
        var request = URLRequest(url: url)
        let token = UserDefaults.standard.string(forKey: "access_token") ?? ""
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let jsonArray = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                lapData = jsonArray.compactMap { dict -> LapEntry? in
                    guard let driverId = dict["driverId"] as? String else { return nil }
                    let lap: Int
                    if let l = dict["lap"] as? Int { lap = l }
                    else if let l = dict["lap"] as? String, let li = Int(l) { lap = li }
                    else { return nil }
                    let pos: Int
                    if let p = dict["position"] as? Int { pos = p }
                    else if let p = dict["position"] as? String, let pi = Int(p) { pos = pi }
                    else { return nil }
                    return LapEntry(driverId: driverId, lap: lap, position: pos)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// View
struct LapChartView: View {
    let season: String
    let round: String

    @StateObject private var viewModel = LapChartViewModel()
    @State private var hiddenDrivers: Set<String> = []

    private let bg  = Color(red: 0.02, green: 0.02, blue: 0.024)
    private let red = Color(red: 0.88, green: 0.1, blue: 0.1)
    private let card = Color(red: 0.11, green: 0.11, blue: 0.11)

    private let palette: [Color] = [
        .red, .blue, .orange, .green, .purple,
        .cyan, .yellow, .pink, .mint, .indigo
    ]

    private var uniqueDrivers: [String] {
        var seen = Set<String>()
        var result: [String] = []
        // Order by final position (last lap position)
        let maxLap = viewModel.lapData.map(\.lap).max() ?? 0
        let finalPositions = viewModel.lapData.filter { $0.lap == maxLap }.sorted { $0.position < $1.position }
        for entry in finalPositions {
            if seen.insert(entry.driverId).inserted {
                result.append(entry.driverId)
            }
        }
        // Add any drivers not in the final lap
        for entry in viewModel.lapData {
            if seen.insert(entry.driverId).inserted {
                result.append(entry.driverId)
            }
        }
        return result
    }

    private var visibleData: [LapEntry] {
        viewModel.lapData.filter { !hiddenDrivers.contains($0.driverId) }
    }

    private func colorFor(_ driverId: String) -> Color {
        let drivers = uniqueDrivers
        if let idx = drivers.firstIndex(of: driverId), idx < palette.count {
            return palette[idx]
        }
        return Color(white: 0.55)
    }

    var body: some View {
        ZStack {
            bg.ignoresSafeArea()

            if viewModel.isLoading {
                VStack(spacing: 14) {
                    ProgressView().tint(red).scaleEffect(1.3)
                    Text("Loading lap data...").font(.system(size: 14)).foregroundStyle(Color(white: 0.6))
                }
            } else if let err = viewModel.errorMessage {
                VStack(spacing: 18) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 40)).foregroundStyle(red)
                    Text(err).font(.system(size: 14)).foregroundStyle(Color(white: 0.6)).multilineTextAlignment(.center).padding(.horizontal, 32)
                    Button { Task { await viewModel.loadLaps(season: season, round: round) } } label: {
                        Text("Retry").font(.system(size: 15, weight: .semibold)).foregroundStyle(.white).padding(.horizontal, 28).padding(.vertical, 10).background(red).clipShape(Capsule()).shadow(color: Color(red: 0.88, green: 0.1, blue: 0.1).opacity(0.4), radius: 8, x: 0, y: 2)
                    }
                }
            } else if viewModel.lapData.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "chart.xyaxis.line").font(.system(size: 40)).foregroundStyle(Color(white: 0.55))
                    Text("No lap data available").font(.system(size: 16)).foregroundStyle(Color(white: 0.5))
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Chart
                        Text("POSITION BY LAP").font(.system(size: 12, weight: .heavy)).foregroundStyle(red).tracking(1).padding(.horizontal, 16)

                        let maxLap = visibleData.map(\.lap).max() ?? 1
                        ScrollView(.horizontal, showsIndicators: true) {
                            Chart(visibleData) { entry in
                                LineMark(
                                    x: .value("Lap", entry.lap),
                                    y: .value("Position", entry.position)
                                )
                                .foregroundStyle(by: .value("Driver", entry.driverId))
                                .interpolationMethod(.catmullRom)
                            }
                            .chartYScale(domain: .automatic(includesZero: false, reversed: true))
                            .chartForegroundStyleScale(mapping: { (driverId: String) in colorFor(driverId) })
                            .chartLegend(.visible)
                            .chartLegend(position: .top)
                            .frame(width: max(CGFloat(maxLap) * 12, 400), height: 300)
                            .padding(.horizontal, 16)
                        }

                        // Driver filter chips
                        Text("FILTER DRIVERS").font(.system(size: 12, weight: .heavy)).foregroundStyle(red).tracking(1).padding(.horizontal, 16)

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                            ForEach(uniqueDrivers, id: \.self) { driver in
                                Button {
                                    if hiddenDrivers.contains(driver) {
                                        hiddenDrivers.remove(driver)
                                    } else {
                                        hiddenDrivers.insert(driver)
                                    }
                                } label: {
                                    Text(driver)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(hiddenDrivers.contains(driver) ? Color(white: 0.55) : .white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(hiddenDrivers.contains(driver) ? Color(white: 0.15) : colorFor(driver).opacity(0.3))
                                        .clipShape(Capsule())
                                        .overlay(Capsule().strokeBorder(colorFor(driver).opacity(hiddenDrivers.contains(driver) ? 0.2 : 0.6), lineWidth: 1))
                                }
                            }
                        }
                        .padding(.horizontal, 16)

                        Spacer(minLength: 20)
                    }
                    .padding(.vertical, 16)
                }
            }
        }
        .navigationTitle("Lap Chart")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .toolbarBackground(bg, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .task {
            await viewModel.loadLaps(season: season, round: round)
        }
    }
}
