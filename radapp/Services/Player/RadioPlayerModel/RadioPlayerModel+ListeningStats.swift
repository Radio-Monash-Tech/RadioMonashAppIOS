import Foundation

// Feeding Listening Statistics.
extension RadioPlayerModel {
    /// The show being listened to, linked to its schedule entry when the
    /// schedule has it so Listening Statistics can open the show's page.
    private var listeningShow: ListeningTracker.Show? {
        guard let liveShow else { return nil }
        return .init(name: liveShow.name, seriesID: scheduledLiveShow?.series.id)
    }

    /// The schedule's entry for the show RadioCult says is on air, if the names match.
    var scheduledLiveShow: ScheduledShow? {
        guard let liveShow, let onAir = schedule?.onAir() else { return nil }
        let matches = onAir.series.title.localizedCaseInsensitiveCompare(liveShow.name) == .orderedSame
        return matches ? onAir : nil
    }

    func trackListening() {
        listening?.update(state: state, show: listeningShow)
    }

    func resetListeningStatistics() {
        listening?.reset()
        trackListening()
    }
}
