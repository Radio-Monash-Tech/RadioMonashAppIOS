import Foundation

enum RadioCultError: LocalizedError {
    case http(Int)

    var errorDescription: String? {
        switch self {
        case .http(429): "RadioCult is busy right now. Try again in a moment."
        case .http(let status): "RadioCult returned an error (\(status))."
        }
    }
}

struct RadioCultClient {
    static let shared = RadioCultClient()

    private let baseURL = URL(string: "https://api.radiocult.fm/api/station/radio-monash")!
    private let apiKey = Secrets.radioCultAPIKey

    func liveStatus() async throws -> ScheduleLiveResponse {
        try await get("schedule/live")
    }

    func history(limit: Int) async throws -> HistoryResponse {
        try await get("streaming/history/latest-results", query: [URLQueryItem(name: "limit", value: String(limit))])
    }

    func schedule(from start: Date, to end: Date) async throws -> [ScheduledShow] {
        let response: ScheduleResponse = try await get("schedule", query: [
            URLQueryItem(name: "startDate", value: RadioCultDate.string(from: start)),
            URLQueryItem(name: "endDate", value: RadioCultDate.string(from: end)),
            URLQueryItem(name: "expand", value: "artist"),
        ])
        return response.toScheduledShows()
    }

    private func get<Response: Decodable>(_ path: String, query: [URLQueryItem] = []) async throws -> Response {
        var components = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)!
        if !query.isEmpty { components.queryItems = query }

        var request = URLRequest(url: components.url!)
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.timeoutInterval = 15

        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw RadioCultError.http(http.statusCode)
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }
}

enum RadioCultDate {
    private static let withFractionalSeconds: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let plain = ISO8601DateFormatter()

    static func parse(_ string: String) -> Date? {
        withFractionalSeconds.date(from: string) ?? plain.date(from: string)
    }

    static func string(from date: Date) -> String {
        plain.string(from: date)
    }
}
