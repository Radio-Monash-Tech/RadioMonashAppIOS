import Foundation

/// Keeps the last copy of something downloaded (the schedule, a page of
/// articles) as a JSON file, so it can still be shown without internet.
/// Files live in Caches, which iOS may clear when the phone is low on space.
enum OfflineCache {
    struct Entry<Value: Codable>: Codable {
        let savedAt: Date
        let value: Value
    }

    static func save<Value: Codable>(_ value: Value, as name: String) {
        let entry = Entry(savedAt: .now, value: value)
        guard let data = try? JSONEncoder().encode(entry) else { return }
        try? data.write(to: url(for: name), options: .atomic)
    }

    static func load<Value: Codable>(_ type: Value.Type, named name: String) -> Entry<Value>? {
        guard let data = try? Data(contentsOf: url(for: name)) else { return nil }
        return try? JSONDecoder().decode(Entry<Value>.self, from: data)
    }

    private static func url(for name: String) -> URL {
        URL.cachesDirectory.appending(path: "\(name).json")
    }
}
