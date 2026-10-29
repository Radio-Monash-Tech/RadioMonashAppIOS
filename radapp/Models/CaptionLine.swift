import Foundation

/// Who a caption belongs to: the host of the show, or the song being sung.
enum CaptionSpeaker: Equatable {
    case host(show: String)
    case lyrics(track: String)
}

struct CaptionLine: Identifiable, Equatable {
    let id: UUID
    var speaker: CaptionSpeaker
    var text: String
}

/// Consecutive lines from the same speaker, shown under one label.
struct CaptionGroup: Identifiable {
    let id: UUID
    let speaker: CaptionSpeaker
    var lines: [CaptionLine]
}
