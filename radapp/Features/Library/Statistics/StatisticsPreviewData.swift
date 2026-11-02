import Foundation
import SwiftData

// random listening over the last 240 days, for the preview
// @MainActor runs this on the main thread
@MainActor
func statisticsPreviewContainer() -> ModelContainer {
    let container = try! ModelContainer(for: ListeningSegment.self, FavouriteTrack.self,
                                        configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    let context = container.mainContext
    let calendar = Calendar.melbourne
    let shows = ["Afternoon Drift", "Local Cuts", "Night Shift", "Second Coffee"]
    var generator = SystemRandomNumberGenerator()
    // about half of the days, at a random time between 8am and 10pm
    for daysAgo in 0..<240 where Bool.random(using: &generator) {
        // guard exits early if the check fails
        guard let day = calendar.date(byAdding: .day, value: -daysAgo, to: calendar.startOfDay(for: .now)),
              let start = calendar.date(byAdding: .minute, value: Int.random(in: 8 * 60...22 * 60), to: day),
              start < .now
        else {
            continue
        }
        let segment = ListeningSegment(sessionID: UUID(), start: start, showName: shows.randomElement(), seriesID: nil)
        // 10 to 90 minutes long
        segment.end = min(.now, start.addingTimeInterval(.random(in: 10 * 60...90 * 60)))
        context.insert(segment)
    }
    for (artist, count) in [("Nikau", 5), ("Mellowing", 3), ("Ophelia Grange", 2)] {
        for index in 0..<count {
            context.insert(FavouriteTrack(title: "Track \(index)", artist: artist, artworkURL: nil, showName: nil))
        }
    }
    return container
}
