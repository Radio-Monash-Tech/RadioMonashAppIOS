import CryptoKit
import UIKit

// saves the song's cover where the home screen widget can read it
@MainActor
final class WidgetArtworkStore {
    // big enough for the small widget at 3x
    private let pixelSize: CGFloat = 512

    // the cover's name for the widget, or nil if it couldn't be saved
    func save(_ url: URL) async -> String? {
        guard let directory = WidgetArtwork.directory else {
            return nil
        }
        let name = Self.fileName(for: url)
        let largeName = WidgetArtwork.largeFileName(for: name)
        let fileURL = directory.appendingPathComponent(largeName)
        // already saved
        if FileManager.default.fileExists(atPath: fileURL.path) {
            return name
        }

        guard let image = await ArtworkCache.shared.load(url),
              let data = resized(image, to: pixelSize).jpegData(compressionQuality: 0.8)
        else {
            return nil
        }

        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            return nil
        }
        removeFiles(in: directory, except: [largeName])
        return name
    }

    // a square copy at the given pixel size
    private func resized(_ image: UIImage, to pixelSize: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let size = CGSize(width: pixelSize, height: pixelSize)
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    // only the current cover is shown, so older ones are deleted
    private func removeFiles(in directory: URL, except keep: Set<String>) {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        for name in names where !keep.contains(name) {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
        }
    }

    // a short name made from the url, the same every time for the same cover
    private static func fileName(for url: URL) -> String {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let hex = digest.prefix(12).map { byte in
            String(format: "%02x", byte)
        }
        return hex.joined() + ".jpg"
    }
}
