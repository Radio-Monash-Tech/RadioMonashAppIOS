import Foundation

// Decodable shapes for GET /api/station/:stationId/schedule, plus their
// mapping into the app's domain models.

struct ScheduleResponse: Decodable {
    let schedules: [ScheduleEvent]
}

struct ScheduleEvent: Decodable {
    let id: String
    let originalId: String?
    let title: String
    let startDateUtc: String
    let endDateUtc: String
    let description: TipTapNode?
    let artists: [ScheduleArtist]

    private enum CodingKeys: String, CodingKey {
        case id, originalId, title, startDateUtc, endDateUtc, description, artists
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        originalId = try container.decodeIfPresent(String.self, forKey: .originalId)
        title = try container.decode(String.self, forKey: .title)
        startDateUtc = try container.decode(String.self, forKey: .startDateUtc)
        endDateUtc = try container.decode(String.self, forKey: .endDateUtc)
        description = try? container.decodeIfPresent(TipTapNode.self, forKey: .description)
        artists = (try? container.decodeIfPresent([ScheduleArtist].self, forKey: .artists)) ?? []
    }
}

struct ScheduleArtist: Decodable {
    let id: String
    let name: String
}

extension ScheduleResponse {
    func toScheduledShows() -> [ScheduledShow] {
        schedules.compactMap { event in
            guard let start = RadioCultDate.parse(event.startDateUtc),
                  let end = RadioCultDate.parse(event.endDateUtc),
                  end > start
            else { return nil }

            let summary = event.description?.attributedText
            let series = ShowSeries(
                id: event.originalId ?? event.id,
                title: event.title.trimmingCharacters(in: .whitespacesAndNewlines),
                hosts: event.artists.map(\.name),
                summary: summary.flatMap { $0.characters.isEmpty ? nil : $0 }
            )
            return ScheduledShow(id: event.id, series: series, start: start, end: end)
        }
        .sorted { $0.start < $1.start }
    }
}
