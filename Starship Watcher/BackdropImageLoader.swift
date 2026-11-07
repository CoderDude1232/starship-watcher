import ImageIO
import SwiftUI
import UIKit

/// Loads remote images once, downsampled off the main thread, and shares them between views.
/// Launch Library images are often 4096px+ (~40MB decoded); `AsyncImage` has no cache, so every
/// tab's backdrop downloaded and decoded its own full-size copy.
actor BackdropImageLoader {
    static let shared = BackdropImageLoader()

    // NSCache is thread-safe, so reads can skip the actor hop.
    private nonisolated(unsafe) let cache = NSCache<NSURL, UIImage>()
    private var inFlight: [URL: Task<UIImage?, Never>] = [:]

    nonisolated func cachedImage(for url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func image(for url: URL, maxPixelSize: CGFloat = 1400) async -> UIImage? {
        if let cached = cache.object(forKey: url as NSURL) { return cached }
        if let task = inFlight[url] { return await task.value }

        let task = Task.detached(priority: .utility) { () -> UIImage? in
            guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
            return Self.downsample(data, maxPixelSize: maxPixelSize)
        }
        inFlight[url] = task
        let image = await task.value
        inFlight[url] = nil
        if let image {
            cache.setObject(image, forKey: url as NSURL)
        }
        return image
    }

    private nonisolated static func downsample(_ data: Data, maxPixelSize: CGFloat) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
