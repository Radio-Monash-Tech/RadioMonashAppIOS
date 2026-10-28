import CryptoKit
import UIKit

/// Saves track covers where the Live Activity can read them. Live Activities
/// won't draw large images, so each cover is shrunk to widget size first.
@MainActor
final class WidgetArtworkStore {
    /// Big enough for the 64pt Lock Screen artwork at 3x.
    private let pixelSize: CGFloat = 192

    /// Returns the saved file's name, or `nil` if the cover couldn't be saved.
    func save(_ url: URL) async -> String? {
        guard let directory = WidgetArtwork.directory else { return nil }
        let name = Self.fileName(for: url)
        let fileURL = directory.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: fileURL.path) { return name }

        guard let image = await ArtworkCache.shared.load(url),
              let data = resized(image).jpegData(compressionQuality: 0.8)
        else { return nil }

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            return nil
        }
        removeFiles(in: directory, except: name)
        return name
    }

    private func resized(_ image: UIImage) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let size = CGSize(width: pixelSize, height: pixelSize)
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    /// Only the current cover is ever shown, so older ones are dropped.
    private func removeFiles(in directory: URL, except keep: String) {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        for name in names where name != keep {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
        }
    }

    private static func fileName(for url: URL) -> String {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        return digest.prefix(12).map { String(format: "%02x", $0) }.joined() + ".jpg"
    }
}
