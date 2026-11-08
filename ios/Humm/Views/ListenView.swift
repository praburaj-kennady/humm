import SwiftUI

/// Listen: the full-screen feed, one hook at a time, looping.
/// Swipe up for the next hook. Drag down (or tap the chevron) to go back to Browse.
///
/// Artwork first: the song's picture fills the screen (blurred) and sits as a
/// big cover in the middle. YouTube's player only appears inside that cover
/// once the hook is actually playing. YouTube requires its player to stay
/// visible while it plays, so it's never hidden behind the artwork.
struct ListenView: View {
    /// The screen size including the notch and home-indicator areas.
    let size: CGSize
    let insets: EdgeInsets
    /// How far Listen has been dragged down (shared with RootView, which moves it).
    @Binding var collapseDrag: CGFloat

    @Environment(Player.self) private var player
    @Environment(Library.self) private var library
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.openURL) private var openURL

    @State private var feedDrag: CGFloat = 0
    @State private var dragMode: DragMode?
    @State private var showSource = false
    @State private var flash: String?
    /// While a swipe is still sliding into place, the page it started from.
    /// The next hook starts playing as soon as you let go; the slide catches up.
    @State private var swipingFrom: Int?

    private enum DragMode { case feed, collapse }

    /// Spring from the Figma motion notes: 0.45s, bounce 0.15.
    private let swipeSpring = Animation.spring(duration: 0.45, bounce: 0.15)
    /// A quick flick (over 0.11 px/ms) moves on even after a short drag.
    private let flickSpeed: CGFloat = 110

    var body: some View {
        ZStack(alignment: .top) {
            pager
            videoLayer
            centerLayer
            topBar
        }
        .frame(width: size.width, height: size.height)
        .background(Color.black)
        .sheet(isPresented: $showSource) {
            if let hook = player.current { SourceSheet(hook: hook) }
        }
        .sensoryFeedback(.impact(weight: .light), trigger: player.index)
        #if DEBUG
        .task {
            if DebugScene.name == "source" {
                try? await Task.sleep(for: .seconds(4))
                showSource = true
            }
        }
        #endif
    }

    // MARK: Pages

    private struct PageItem: Identifiable {
        let hook: Hook
        let position: Int // -1 above, 0 on screen, 1 below
        var id: String { hook.id }
    }

    /// The page the layout is centred on. During a swipe it's still the old one.
    private var baseIndex: Int { swipingFrom ?? player.index }

    /// The pages around the screen, keyed by hook so a picture never reloads
    /// when a page moves from "next" to "current".
    private var pages: [PageItem] {
        (-1...1).compactMap { d in
            let i = baseIndex + d
            return player.queue.indices.contains(i) ? PageItem(hook: player.queue[i], position: d) : nil
        }
    }

    /// Where the playing hook's page is right now (it moves during a swipe).
    private var liveOffset: CGFloat {
        CGFloat(player.index - baseIndex) * size.height + feedDrag
    }

    /// The cover in the middle. YouTube needs its player at least 200 x 200.
    private var cover: CGFloat {
        max(220, min(size.width - 96, size.height * 0.36, 300)).rounded()
    }
    private var coverTop: CGFloat { insets.top + 72 }

    private var pager: some View {
        ZStack {
            ForEach(pages) { item in
                page(item.hook, live: item.hook.id == player.current?.id && player.index == baseIndex + item.position)
                    .offset(y: CGFloat(item.position) * size.height + feedDrag)
            }
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture { togglePlay() }
        .gesture(drag)
    }

    private func page(_ hook: Hook, live: Bool) -> some View {
        ZStack(alignment: .bottom) {
            // The artwork, blurred, fills the screen behind everything.
            Thumbnail(hook: hook)
                .blur(radius: 44, opaque: true)
                .overlay(Theme.bg.opacity(0.42))

            Thumbnail(hook: hook)
                .frame(width: cover, height: cover)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .shadow(color: .black.opacity(0.45), radius: 28, y: 14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .padding(.top, coverTop)

            LinearGradient(colors: [.black.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom)
                .frame(height: 150)
                .frame(maxHeight: .infinity, alignment: .top)
            LinearGradient(
                stops: [
                    .init(color: Theme.bg.opacity(0), location: 0),
                    .init(color: Theme.bg.opacity(0.55), location: 0.45),
                    .init(color: Theme.bg.opacity(0.92), location: 1),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 380)

            VStack(spacing: 22) {
                HStack(alignment: .bottom, spacing: 12) {
                    info(hook)
                    Spacer(minLength: 0)
                    if live { actions(hook) }
                }
                if live { Scrubber(hook: hook) }
            }
            .padding(.leading, 20)
            .padding(.trailing, 14)
            .padding(.bottom, insets.bottom + 22)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
        .foregroundStyle(Theme.text)
    }

    /// The three warm YouTube players, stacked inside the cover. Only the one
    /// that's playing shows; the others are waiting with the next hooks cued.
    private var videoLayer: some View {
        let visible = (player.status == .playing || player.status == .paused) && player.current?.isYouTube == true
        return ZStack {
            ForEach(player.slots.indices, id: \.self) { i in
                YouTubeSurface(controller: player.slots[i])
                    .opacity(visible && i == player.liveSlot ? 1 : 0)
            }
        }
        .frame(width: cover, height: cover)
        .background(Color.black)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .opacity(visible ? 1 : 0)
        .animation(.easeOut(duration: 0.25), value: visible)
        .allowsHitTesting(false)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, coverTop)
        .offset(y: liveOffset)
    }

    /// Play/pause badge, spinner or error, on top of the cover.
    private var centerLayer: some View {
        Group {
            if let hook = player.current { centerState(hook) }
        }
        .frame(width: cover, height: cover)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, coverTop)
        .offset(y: liveOffset)
    }

    private func info(_ hook: Hook) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Chip(source: hook.source, text: hook.isYouTube ? "YouTube" : "Instagram Reel")
                if let rank = hook.trendRank {
                    Text("#\(rank) this week")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.onAccent)
                        .padding(.leading, 8)
                        .padding(.trailing, 9)
                        .padding(.vertical, 4)
                        .background(Theme.accent, in: Capsule())
                }
            }
            Text(hook.songTitle)
                .font(.system(size: 36, weight: .bold))
                .tracking(-0.54)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
            Text(hook.meta)
                .font(.system(size: 14))
                .lineLimit(2)
            Label("The hook · \(Format.range(hook))", systemImage: "play.fill")
                .labelStyle(TightLabel())
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .padding(.leading, 8)
                .padding(.trailing, 10)
                .padding(.vertical, 5)
                .background(Theme.accent.opacity(0.18), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func actions(_ hook: Hook) -> some View {
        let saved = library.isSaved(hook)
        return VStack(spacing: 16) {
            ActionButton(label: saved ? "Saved" : "Save", symbol: saved ? "bookmark.fill" : "bookmark", active: saved) {
                Task { await library.toggleSave(hook) }
            }
            .sensoryFeedback(.success, trigger: saved)

            if let link = hook.sourceLink {
                ShareLink(item: link, message: Text("The best part of \(hook.songTitle), found on Humm")) {
                    ActionLabel(label: "Share", symbol: "square.and.arrow.up")
                }
                .buttonStyle(PressScale())
            }

            ActionButton(label: "Source", symbol: "arrow.up.forward.square") { showSource = true }

            ActionButton(label: "Make", symbol: "plus.app") {
                if let url = hook.makeReelLink {
                    openURL(url)
                } else {
                    showSource = true
                }
            }
        }
    }

    @ViewBuilder
    private func centerState(_ hook: Hook) -> some View {
        Group {
            if player.status == .error {
                VStack(spacing: 8) {
                    Text("This video won't play inside apps.")
                    if let url = hook.sourceLink {
                        Link("Open on YouTube", destination: url).foregroundStyle(Theme.accent)
                    }
                }
                .font(.system(size: 14, weight: .medium))
                .multilineTextAlignment(.center)
                .padding(14)
                .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            } else if !hook.isYouTube {
                if let url = hook.sourceLink {
                    Link("Play on Instagram", destination: url)
                        .font(.system(size: 15, weight: .semibold))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.black.opacity(0.6), in: Capsule())
                }
            } else if let flash {
                PlayStateBadge(symbol: flash)
                    .transition(.asymmetric(insertion: .scale(scale: 0.95).combined(with: .opacity), removal: .opacity))
            } else if player.status == .paused || player.status == .idle {
                PlayStateBadge(symbol: "play.fill")
                    .transition(.scale(scale: 0.95).combined(with: .opacity))
            } else if player.status == .loading {
                ProgressView().tint(.white).controlSize(.large)
            }
        }
        .frame(width: cover, height: cover)
        .allowsHitTesting(player.status == .error || !hook.isYouTube)
    }

    private var topBar: some View {
        let chart = library.chart?.hooks ?? []
        let onTrending = !chart.isEmpty && player.queue.map(\.id) == chart.map(\.id)
        return HStack {
            Button { player.listenOpen = false } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 44, height: 44)
                    .background(.black.opacity(0.28), in: Circle())
            }
            .buttonStyle(PressScale())
            .accessibilityLabel("Back to Browse")

            Spacer()
            HStack(spacing: 24) {
                FeedTab(title: "For you", active: !onTrending) {
                    if onTrending { player.play(library.allHooks, at: 0) }
                }
                FeedTab(title: "Trending", active: onTrending) {
                    if !onTrending { player.play(chart, at: 0) }
                }
            }
            Spacer()

            Text(player.queue.isEmpty ? "" : "\(player.index + 1)/\(player.queue.count)")
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundStyle(Theme.text.opacity(0.7))
                .frame(width: 44, alignment: .trailing)
        }
        .foregroundStyle(Theme.text)
        .padding(.horizontal, 16)
        .padding(.top, insets.top + 2)
    }

    // MARK: Gestures

    private var drag: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard swipingFrom == nil else { return }
                let dy = value.translation.height
                if dragMode == nil { dragMode = dy < 0 ? .feed : .collapse }
                switch dragMode {
                case .feed:
                    // Past the last hook it resists, like a rubber band.
                    feedDrag = player.next == nil ? min(0, dy) / 4 : min(0, dy)
                case .collapse:
                    collapseDrag = max(0, dy)
                case nil:
                    break
                }
            }
            .onEnded { value in
                let dy = value.translation.height
                let speed = value.velocity.height
                switch dragMode {
                case .feed:
                    if player.next != nil && (dy < -size.height * 0.25 || speed < -flickSpeed) {
                        advance()
                    } else {
                        withAnimation(swipeSpring) { feedDrag = 0 }
                    }
                case .collapse:
                    if dy > size.height * 0.3 || speed > flickSpeed {
                        // RootView animates the close (quicker than opening).
                        player.listenOpen = false
                        collapseDrag = 0
                    } else {
                        withAnimation(.spring(duration: 0.35, bounce: 0)) { collapseDrag = 0 }
                    }
                case nil:
                    break
                }
                dragMode = nil
            }
    }

    private func advance() {
        let target = player.index + 1
        if reduceMotion {
            // Reduced motion: no slide, just swap.
            feedDrag = 0
            player.goTo(target)
            return
        }
        // Start the next hook now, while its page slides into place.
        swipingFrom = player.index
        player.goTo(target)
        withAnimation(swipeSpring) {
            feedDrag = -size.height
        } completion: {
            var t = Transaction()
            t.disablesAnimations = true
            withTransaction(t) {
                swipingFrom = nil
                feedDrag = 0
            }
        }
    }

    private func togglePlay() {
        let symbol = player.isPlaying ? "pause.fill" : "play.fill"
        player.toggle()
        withAnimation(.easeOut(duration: 0.16)) { flash = symbol }
        Task {
            try? await Task.sleep(for: .milliseconds(600))
            withAnimation(.easeOut(duration: 0.2)) { if flash == symbol { flash = nil } }
        }
    }
}

// MARK: Small pieces

private struct FeedTab: View {
    let title: String
    let active: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(title).font(.system(size: 16, weight: active ? .semibold : .medium))
                Capsule()
                    .fill(active ? Theme.accent : .clear)
                    .frame(width: 18, height: 3)
            }
            .opacity(active ? 1 : 0.72)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? .isSelected : [])
    }
}

private struct ActionLabel: View {
    let label: String
    let symbol: String
    var active = false

    var body: some View {
        VStack(spacing: 5) {
            Image(systemName: symbol)
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(active ? Theme.accent : Theme.text)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 48, height: 48)
                .background(.black.opacity(0.3), in: Circle())
            Text(label).font(.system(size: 11, weight: .semibold))
        }
        .frame(width: 56)
    }
}

private struct ActionButton: View {
    let label: String
    let symbol: String
    var active = false
    let action: () -> Void

    var body: some View {
        Button(action: action) { ActionLabel(label: label, symbol: symbol, active: active) }
            .buttonStyle(PressScale())
    }
}

private struct PlayStateBadge: View {
    let symbol: String
    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 30, weight: .bold))
            .offset(x: symbol == "play.fill" ? 2 : 0)
            .frame(width: 76, height: 76)
            .background(.ultraThinMaterial, in: Circle())
            .environment(\.colorScheme, .dark)
    }
}

/// Icon and text with the 6pt gap from Figma.
private struct TightLabel: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 6) {
            configuration.icon.font(.system(size: 9, weight: .bold))
            configuration.title
        }
    }
}

/// The waveform under the hook. The lit part is how far through the hook you are. Tap to jump.
private struct Scrubber: View {
    let hook: Hook
    @Environment(Player.self) private var player

    private let barCount = 56

    var body: some View {
        let bars = Format.waveform(seed: hook.id, bars: barCount)
        let played = Int((player.progress * Double(barCount)).rounded())
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { g in
                HStack(alignment: .center, spacing: 2) {
                    ForEach(0..<barCount, id: \.self) { i in
                        Capsule()
                            .fill(i < played ? Theme.accent : Theme.text.opacity(0.42))
                            .frame(height: max(4, bars[i] * 30))
                    }
                }
                .frame(width: g.size.width, height: 30)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0).onEnded { v in
                        player.seek(toFraction: min(1, max(0, v.location.x / g.size.width)))
                    }
                )
            }
            .frame(height: 30)
            .accessibilityElement()
            .accessibilityLabel("Position in the hook")
            .accessibilityValue("\(Int(player.progress * 100)) percent")

            HStack {
                Text(Format.clock(player.status == .idle ? Double(hook.startMs) : player.positionMs))
                    .foregroundStyle(Theme.accent)
                    .fontWeight(.medium)
                    .monospacedDigit()
                Spacer()
                Text("Loops the hook · full song on \(hook.isYouTube ? "YouTube" : "Instagram")")
                    .foregroundStyle(Theme.text.opacity(0.8))
            }
            .font(.system(size: 11))
        }
    }
}
