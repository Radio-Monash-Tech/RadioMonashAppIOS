import Foundation

// a set of ids that @AppStorage can save as one string
struct StoredIDs: RawRepresentable {
    var ids: Set<String>

    // starts empty
    init() {
        ids = []
    }

    // read back from the saved string, one id per line
    init?(rawValue: String) {
        let lines = rawValue.split(separator: "\n")
        ids = Set(lines.map { line in
            String(line)
        })
    }

    // the string that gets saved, sorted so the same set always saves the same way
    var rawValue: String {
        ids.sorted().joined(separator: "\n")
    }

    func contains(_ id: String) -> Bool {
        ids.contains(id)
    }

    // follow or unfollow
    mutating func toggle(_ id: String) {
        if ids.contains(id) {
            ids.remove(id)
        } else {
            ids.insert(id)
        }
    }

    // the UserDefaults key for followed shows
    static let followedShowsKey = "followedShows"
}
