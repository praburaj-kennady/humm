import UIKit

/// Keeps song artwork in memory once it has been downloaded, so a hook's
/// picture shows instantly the next time (no blank flash while it reloads).
@MainActor
final class ImageStore {
    static let shared = ImageStore()

    private let cache = NSCache<NSURL, UIImage>()
    private var inFlight: [URL: Task<Data?, Never>] = [:]

    func cached(_ url: URL) -> UIImage? {
        cache.object(forKey: url as NSURL)
    }

    func load(_ url: URL) async -> UIImage? {
        if let image = cached(url) { return image }
        let task: Task<Data?, Never>
        if let running = inFlight[url] {
            task = running
        } else {
            task = Task { try? await URLSession.shared.data(from: url).0 }
            inFlight[url] = task
        }
        let data = await task.value
        inFlight[url] = nil
        if let image = cached(url) { return image }
        guard let data, let image = UIImage(data: data) else { return nil }
        cache.setObject(image, forKey: url as NSURL)
        return image
    }

    /// Download artwork ahead of time (all of Browse is only a few dozen pictures).
    func prefetch(_ urls: [URL]) {
        for url in urls where cached(url) == nil && inFlight[url] == nil {
            Task { _ = await load(url) }
        }
    }
}
