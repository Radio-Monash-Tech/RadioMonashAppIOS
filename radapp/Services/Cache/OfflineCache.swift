import Foundation

// keeps the last download as a json file, so it can be shown offline; ios may clear it when space is low
enum OfflineCache {
    // the saved value and when it was saved
    struct Entry<Value: Codable>: Codable {
        let savedAt: Date
        let value: Value
    }

    static func save<Value: Codable>(_ value: Value, as name: String) {
        let entry = Entry(savedAt: .now, value: value)
        guard let data = try? JSONEncoder().encode(entry) else {
            return
        }
        try? data.write(to: url(for: name), options: .atomic)
    }

    // nil if nothing has been saved yet
    static func load<Value: Codable>(_ type: Value.Type, named name: String) -> Entry<Value>? {
        guard let data = try? Data(contentsOf: url(for: name)) else {
            return nil
        }
        return try? JSONDecoder().decode(Entry<Value>.self, from: data)
    }

    // the file in the app's caches folder
    private static func url(for name: String) -> URL {
        URL.cachesDirectory.appending(path: "\(name).json")
    }
}
