import Foundation

struct StoredIDs: RawRepresentable {
    var ids: Set<String>

    init() { ids = [] }

    init?(rawValue: String) {
        ids = Set(rawValue.split(separator: "\n").map(String.init))
    }

    var rawValue: String { ids.sorted().joined(separator: "\n") }

    func contains(_ id: String) -> Bool { ids.contains(id) }

    mutating func toggle(_ id: String) {
        if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
    }

    static let followedShowsKey = "followedShows"
}
