import Foundation

enum ListeningDuration {
    // "27m", "6h 00m", "32h 14m"
    static func format(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        if minutes < 60 {
            return "\(minutes)m"
        }
        return "\(minutes / 60)h \(String(format: "%02d", minutes % 60))m"
    }
}
