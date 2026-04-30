import Foundation

/// Centralized base URLs for the PitCrew backend.
///
/// Override at build time with the `API_HOST` Info.plist key
/// (set via xcconfig or scheme env), otherwise falls back to the
/// production Traefik hostname.
enum APIConfig {
    private static let host: String = {
        if let override = Bundle.main.object(forInfoDictionaryKey: "API_HOST") as? String,
           !override.isEmpty {
            return override
        }
        return "pitcrew-backend.pxndey.com"
    }()

    /// HTTPS base for REST endpoints. Append `/auth/...`, `/chat/...`, `/f1/...`.
    static var baseURL: String { "https://\(host)/api" }

    /// Secure WebSocket base. Append `/chat/ws`, etc.
    static var webSocketBaseURL: String { "wss://\(host)/api" }
}
