import Foundation

// feeding listening statistics
extension RadioPlayerModel {
    // the show being listened to, with its schedule id when known
    private var listeningShow: ListeningTracker.Show? {
        guard let liveShow else {
            return nil
        }
        return .init(name: liveShow.name, seriesID: scheduledLiveShow?.series.id)
    }

    // the schedule's entry for the show on air, if the names match
    var scheduledLiveShow: ScheduledShow? {
        guard let liveShow, let onAir = schedule?.onAir() else {
            return nil
        }
        let matches = onAir.series.title.localizedCaseInsensitiveCompare(liveShow.name) == .orderedSame
        if matches {
            return onAir
        }
        return nil
    }

    func trackListening() {
        listening?.update(state: state, show: listeningShow)
    }

    func resetListeningStatistics() {
        listening?.reset()
        trackListening()
    }
}
