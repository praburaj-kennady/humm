import SwiftUI
import Observation

/// One player for the whole app, so a hook keeps playing while you move
/// between Browse and Listen ("nothing restarts").
///
/// It knows a queue of hooks and which one is current, and it loops the
/// current hook between its start and end until you swipe on.
@MainActor
@Observable
final class Player {
    enum Status { case idle, loading, playing, paused, error }

    private(set) var queue: [Hook] = []
    private(set) var index = 0
    private(set) var status: Status = .idle
    private(set) var positionMs: Double = 0
    var listenOpen = false

    @ObservationIgnored let youtube: YouTubeController

    init() {
        youtube = YouTubeController()
        youtube.onEvent = { [weak self] event in self?.handle(event) }
    }

    var current: Hook? { queue.indices.contains(index) ? queue[index] : nil }
    var previous: Hook? { queue.indices.contains(index - 1) ? queue[index - 1] : nil }
    var next: Hook? { queue.indices.contains(index + 1) ? queue[index + 1] : nil }
    var isPlaying: Bool { status == .playing || status == .loading }

    /// How far through the hook we are, 0 to 1.
    var progress: Double {
        guard let h = current, status != .idle else { return 0 }
        return min(1, max(0, (positionMs - Double(h.startMs)) / Double(h.endMs - h.startMs)))
    }

    /// Make this the queue and start playing hook `at`.
    func play(_ hooks: [Hook], at i: Int, open: Bool = false) {
        queue = hooks
        index = i
        if open { listenOpen = true }
        if let h = current { start(h, autoplay: true) }
    }

    /// Show a hook in the mini player without playing it yet.
    func cue(_ hooks: [Hook], at i: Int) {
        queue = hooks
        index = i
        if let h = current { start(h, autoplay: false) }
    }

    func goTo(_ i: Int) {
        guard queue.indices.contains(i) else { return }
        index = i
        start(queue[i], autoplay: true)
    }

    func toggle() {
        guard let h = current else { return }
        switch status {
        case .idle, .error:
            start(h, autoplay: true)
        case .playing, .loading:
            youtube.pause()
            status = .paused
        case .paused:
            youtube.play()
            status = .loading
        }
    }

    func seek(toFraction f: Double) {
        guard let h = current, h.isYouTube else { return }
        let ms = Double(h.startMs) + f * Double(h.endMs - h.startMs)
        let clamped = min(max(ms, Double(h.startMs)), Double(h.endMs) - 250)
        youtube.seek(toSeconds: clamped / 1000)
        positionMs = clamped
    }

    private func start(_ h: Hook, autoplay: Bool) {
        positionMs = Double(h.startMs)
        guard h.isYouTube else {
            // Instagram reels can't be controlled from the app; they open in Instagram.
            youtube.pause()
            status = .paused
            return
        }
        status = autoplay ? .loading : .idle
        youtube.load(h, autoplay: autoplay)
    }

    private func handle(_ event: YouTubeEvent) {
        switch event {
        case .ready:
            break
        case .state(1):
            status = .playing
        case .state(2):
            if status != .loading { status = .paused }
        case .state(0):
            // The video ended before the hook did. Loop anyway.
            if let h = current {
                youtube.seek(toSeconds: Double(h.startMs) / 1000)
                youtube.play()
            }
        case .state:
            break
        case let .time(seconds):
            guard let h = current else { return }
            let ms = seconds * 1000
            if ms >= Double(h.endMs) - 120 || ms < Double(h.startMs) - 1500 {
                // The end of the hook: go back to its start.
                youtube.seek(toSeconds: Double(h.startMs) / 1000)
                positionMs = Double(h.startMs)
            } else {
                positionMs = ms
            }
        case .error:
            status = .error
        }
    }
}
