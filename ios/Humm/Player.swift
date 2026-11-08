import SwiftUI
import Observation

/// One player for the whole app, so a hook keeps playing while you move
/// between Browse and Listen ("nothing restarts").
///
/// It knows a queue of hooks and which one is current, and it loops the
/// current hook between its start and end until you swipe on.
///
/// To make swipes start fast it keeps three YouTube players warm, like three
/// record decks: one plays, and the other two already have the next two hooks
/// cued at the right second. Swiping just presses play on the next deck.
@MainActor
@Observable
final class Player {
    enum Status { case idle, loading, playing, paused, error }

    private(set) var queue: [Hook] = []
    private(set) var index = 0
    private(set) var status: Status = .idle
    private(set) var positionMs: Double = 0
    /// Which of the three players is the one you hear and see.
    private(set) var liveSlot = 0
    var listenOpen = false

    @ObservationIgnored let slots: [YouTubeController]
    /// The hook each player has loaded or cued (by hook id).
    @ObservationIgnored private var slotHook: [String?]

    init() {
        slots = (0..<3).map { _ in YouTubeController() }
        slotHook = [nil, nil, nil]
        for (i, slot) in slots.enumerated() {
            slot.onEvent = { [weak self] event in self?.handle(event, from: i) }
        }
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
            slots[liveSlot].pause()
            status = .paused
        case .paused:
            slots[liveSlot].play()
            status = .loading
        }
    }

    func seek(toFraction f: Double) {
        guard let h = current, h.isYouTube else { return }
        let ms = Double(h.startMs) + f * Double(h.endMs - h.startMs)
        let clamped = min(max(ms, Double(h.startMs)), Double(h.endMs) - 250)
        slots[liveSlot].seek(toSeconds: clamped / 1000)
        positionMs = clamped
    }

    private func start(_ h: Hook, autoplay: Bool) {
        positionMs = Double(h.startMs)
        guard h.isYouTube else {
            // Instagram reels can't be controlled from the app; they open in Instagram.
            slots[liveSlot].pause()
            status = .paused
            return
        }

        // Use the player that already has this hook cued, if there is one.
        let ready = slotHook.firstIndex(of: h.id)
        let slot = ready ?? pickSlot(keeping: upcomingIDs)
        if slot != liveSlot { slots[liveSlot].pause() }
        liveSlot = slot
        status = autoplay ? .loading : .idle

        if ready != nil && autoplay {
            slots[slot].play(fromSeconds: Double(h.startMs) / 1000)
        } else {
            slotHook[slot] = h.id
            slots[slot].load(h, autoplay: autoplay)
        }
    }

    /// The next two YouTube hooks in the queue.
    private var upcomingIDs: Set<String> {
        Set([index + 1, index + 2]
            .filter { queue.indices.contains($0) && queue[$0].isYouTube }
            .map { queue[$0].id })
    }

    /// Cue the next two hooks in the spare players, so a swipe starts right away.
    private func prepareUpcoming() {
        let keep = upcomingIDs
        for i in [index + 1, index + 2] where queue.indices.contains(i) {
            let h = queue[i]
            guard h.isYouTube, !slotHook.contains(h.id) else { continue }
            let slot = pickSlot(keeping: keep)
            guard slot != liveSlot else { return }
            slotHook[slot] = h.id
            slots[slot].load(h, autoplay: false)
        }
    }

    /// A spare player: never the live one, and preferably one that isn't
    /// holding a hook we're about to need.
    private func pickSlot(keeping keep: Set<String>) -> Int {
        let spare = slots.indices.filter { $0 != liveSlot }
        return spare.first { slotHook[$0] == nil }
            ?? spare.first { !keep.contains(slotHook[$0] ?? "") }
            ?? spare.first
            ?? liveSlot
    }

    private func handle(_ event: YouTubeEvent, from slot: Int) {
        guard slot == liveSlot else {
            // A spare player that can't play its hook: forget it, and the
            // error shows properly if you swipe to that hook.
            if case .error = event { slotHook[slot] = nil }
            return
        }
        switch event {
        case .ready:
            break
        case .state(1):
            status = .playing
            prepareUpcoming()
        case .state(5):
            // Cued and waiting (the first hook on launch). Get the next ones ready too.
            prepareUpcoming()
        case .state(2):
            if status != .loading { status = .paused }
        case .state(0):
            // The video ended before the hook did. Loop anyway.
            if let h = current {
                slots[slot].play(fromSeconds: Double(h.startMs) / 1000)
            }
        case .state:
            break
        case let .time(seconds):
            guard let h = current else { return }
            let ms = seconds * 1000
            if ms >= Double(h.endMs) - 120 || ms < Double(h.startMs) - 1500 {
                // The end of the hook: go back to its start.
                slots[slot].seek(toSeconds: Double(h.startMs) / 1000)
                positionMs = Double(h.startMs)
            } else {
                positionMs = ms
            }
        case .error:
            status = .error
        }
    }
}
