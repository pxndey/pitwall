import Foundation
import UserNotifications

// ---------------------------------------------------------------------------
// MARK: - Session model
// ---------------------------------------------------------------------------

struct RaceSession {
    let raceName: String
    let circuitName: String
    let sessionLabel: String   // e.g. "Practice 1", "Qualifying", "Race"
    let date: Date
}

// ---------------------------------------------------------------------------
// MARK: - NotificationManager
// ---------------------------------------------------------------------------

@MainActor
final class NotificationManager: ObservableObject {

    static let shared = NotificationManager()
    private init() {}

    @Published var permissionGranted = false

    private let baseURL = "\(APIConfig.baseURL)"

    // MARK: - Permission

    func requestPermission() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            permissionGranted = granted
        } catch {
            permissionGranted = false
        }
    }

    // MARK: - Schedule race weekend notifications

    func scheduleNotifications(for race: F1Race) async {
        guard permissionGranted else { return }

        let sessions = buildSessions(from: race)
        let center = UNUserNotificationCenter.current()

        // Remove existing notifications for this race to avoid duplicates
        let prefix = "pitcrew-\(race.round)"
        let pending = await center.pendingNotificationRequests()
        let toRemove = pending.filter { $0.identifier.hasPrefix(prefix) }.map(\.identifier)
        center.removePendingNotificationRequests(withIdentifiers: toRemove)

        for session in sessions {
            // Only schedule future sessions
            guard session.date > Date() else { continue }

            // Notify 30 min before session
            let triggerDate = Calendar.current.date(byAdding: .minute, value: -30, to: session.date) ?? session.date
            guard triggerDate > Date() else { continue }

            // Fetch a briefing snippet
            let snippet = await fetchBriefingSnippet(
                raceName: session.raceName,
                circuitName: session.circuitName,
                session: session.sessionLabel
            )

            let content = UNMutableNotificationContent()
            content.title = "\(session.sessionLabel) — \(session.raceName)"
            content.body = snippet
            content.sound = .default

            let components = Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute],
                from: triggerDate
            )
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

            let id = "\(prefix)-\(session.sessionLabel.replacingOccurrences(of: " ", with: "_"))"
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

            try? await center.add(request)
        }
    }

    // MARK: - Schedule all races in a season

    func scheduleAllUpcoming(races: [F1Race]) async {
        guard permissionGranted else { return }
        let today = Date()
        for race in races {
            guard let raceDate = isoDateOnlyFormatter.date(from: race.date), raceDate >= today else {
                continue
            }
            await scheduleNotifications(for: race)
        }
    }

    // MARK: - Cancel all PitCrew notifications

    func cancelAll() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let ids = requests.filter { $0.identifier.hasPrefix("pitcrew-") }.map(\.identifier)
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    // MARK: - Build sessions from race

    private func buildSessions(from race: F1Race) -> [RaceSession] {
        guard let raceDate = isoDateOnlyFormatter.date(from: race.date) else { return [] }

        var sessions: [RaceSession] = []
        let cal = Calendar.current

        // FP1 — Friday 11:30 UTC (rough placeholder; real times from Jolpica could be used)
        let friday = cal.date(byAdding: .day, value: -2, to: raceDate) ?? raceDate
        sessions.append(RaceSession(
            raceName: race.raceName,
            circuitName: race.circuit.circuitName,
            sessionLabel: "Practice 1",
            date: time(11, 30, on: friday)
        ))

        // FP2 — Friday 15:00 UTC
        sessions.append(RaceSession(
            raceName: race.raceName,
            circuitName: race.circuit.circuitName,
            sessionLabel: "Practice 2",
            date: time(15, 0, on: friday)
        ))

        // FP3 & Qualifying — Saturday
        let saturday = cal.date(byAdding: .day, value: 1, to: friday) ?? friday
        sessions.append(RaceSession(
            raceName: race.raceName,
            circuitName: race.circuit.circuitName,
            sessionLabel: "Practice 3",
            date: time(11, 30, on: saturday)
        ))
        sessions.append(RaceSession(
            raceName: race.raceName,
            circuitName: race.circuit.circuitName,
            sessionLabel: "Qualifying",
            date: time(15, 0, on: saturday)
        ))

        // Race — Sunday; use the time field from Jolpica if available, else 14:00 UTC
        var raceHour = 14
        var raceMinute = 0
        if let timeStr = race.time {
            // time string is like "13:00:00Z"
            let parts = timeStr.split(separator: ":").map { Int($0) ?? 0 }
            if parts.count >= 2 { raceHour = parts[0]; raceMinute = parts[1] }
        }
        sessions.append(RaceSession(
            raceName: race.raceName,
            circuitName: race.circuit.circuitName,
            sessionLabel: "Race",
            date: time(raceHour, raceMinute, on: raceDate)
        ))

        return sessions
    }

    private func time(_ hour: Int, _ minute: Int, on base: Date) -> Date {
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: base)
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        comps.timeZone = TimeZone(identifier: "UTC")
        return Calendar.current.date(from: comps) ?? base
    }

    // MARK: - Fetch briefing snippet from backend

    private func fetchBriefingSnippet(raceName: String, circuitName: String, session: String) async -> String {
        let query = "brief me on the \(session) for \(raceName) at \(circuitName)"
        guard let url = URL(string: "\(baseURL)/chat/watsonx") else {
            return "Get ready for \(session) at \(raceName)!"
        }

        let body: [String: Any] = [
            "message": query,
            "history": [],
            "circuit_context": circuitName
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let token = UserDefaults.standard.string(forKey: "access_token") ?? ""
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, _) = try await URLSession.shared.data(for: request)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let reply = json["reply"] as? String {
                // Truncate to notification-friendly length
                let trimmed = reply.components(separatedBy: "\n").first ?? reply
                return String(trimmed.prefix(150))
            }
        } catch {}

        return "Get ready for \(session) at \(raceName)!"
    }
}

// Reuse the same ISO date formatter style from ScheduleView
private let isoDateOnlyFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(secondsFromGMT: 0)
    return f
}()
