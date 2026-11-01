import Foundation

// the json from schedule
struct ScheduleResponse: Decodable {
    let schedules: [ScheduleEvent]
}

// one episode
struct ScheduleEvent: Decodable {
    let id: String
    // the same for every episode of a show
    let originalId: String?
    let title: String
    let startDateUtc: String
    let endDateUtc: String
    let description: TipTapNode?
    let artists: [ScheduleArtist]

    private enum CodingKeys: String, CodingKey {
        case id, originalId, title, startDateUtc, endDateUtc, description, artists
    }

    // a bad description or artist list is skipped instead of failing the whole schedule
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

// a host
struct ScheduleArtist: Decodable {
    let id: String
    let name: String
}

extension ScheduleResponse {
    // turned into the app's own shows, in start order
    func toScheduledShows() -> [ScheduledShow] {
        let shows: [ScheduledShow] = schedules.compactMap { event in
            // skip episodes with bad times
            guard let start = RadioCultDate.parse(event.startDateUtc),
                  let end = RadioCultDate.parse(event.endDateUtc),
                  end > start
            else {
                return nil
            }

            // no summary rather than an empty one
            var summary = event.description?.attributedText
            if summary?.characters.isEmpty == true {
                summary = nil
            }
            let series = ShowSeries(
                id: event.originalId ?? event.id,
                title: event.title.trimmingCharacters(in: .whitespacesAndNewlines),
                hosts: event.artists.map(\.name),
                summary: summary
            )
            return ScheduledShow(id: event.id, series: series, start: start, end: end)
        }
        return shows.sorted { first, second in
            first.start < second.start
        }
    }
}
