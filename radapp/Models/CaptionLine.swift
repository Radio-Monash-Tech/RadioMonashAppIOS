import Foundation

// who a caption belongs to: the host, or the song being sung
enum CaptionSpeaker: Equatable {
    case host(show: String)
    case lyrics(track: String)
}

// one line of captions
struct CaptionLine: Identifiable, Equatable {
    let id: UUID
    var speaker: CaptionSpeaker
    var text: String
}

// lines in a row from the same speaker, shown under one label
struct CaptionGroup: Identifiable {
    let id: UUID
    let speaker: CaptionSpeaker
    var lines: [CaptionLine]
}
