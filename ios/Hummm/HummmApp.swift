import SwiftUI
import AVFoundation

@main
struct HummmApp: App {
    @State private var library = Library()
    @State private var player = Player()

    init() {
        // Play sound even when the phone's silent switch is on, like any music app.
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(library)
                .environment(player)
                .preferredColorScheme(.dark)
                .tint(Theme.accent)
        }
    }
}

/// Browse is the home screen. The mini player sits on top of it, and Listen
/// slides up over both when you tap a hook or the mini player.
struct RootView: View {
    @Environment(Library.self) private var library
    @Environment(Player.self) private var player
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var collapseDrag: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            let insets = geo.safeAreaInsets
            let fullSize = CGSize(width: geo.size.width + insets.leading + insets.trailing,
                                  height: geo.size.height + insets.top + insets.bottom)
            let open = player.listenOpen

            ZStack(alignment: .bottom) {
                Theme.bg.ignoresSafeArea()

                // Browse shrinks and dims behind Listen, like the iOS Music app.
                BrowseView()
                    .scaleEffect(open && !reduceMotion ? 0.94 : 1, anchor: .center)
                    .brightness(open ? -0.3 : 0)
                    .clipShape(RoundedRectangle(cornerRadius: open ? 28 : 0, style: .continuous))
                    .allowsHitTesting(!open)

                MiniPlayerView()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                    .opacity(open ? 0 : 1)
            }
            .overlay {
                // Listen is always here (so the player keeps playing); it just waits below the screen.
                ListenView(size: fullSize, insets: insets, collapseDrag: $collapseDrag)
                    .offset(y: open ? collapseDrag : fullSize.height + 40)
                    .opacity(reduceMotion && !open ? 0 : 1)
                    .allowsHitTesting(open)
                    .accessibilityHidden(!open)
                    .ignoresSafeArea()
            }
            .overlay(alignment: .top) {
                if let toast = library.toast {
                    Text(toast)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.bg)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(Theme.text, in: Capsule())
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            // Opening: 380ms on the iOS sheet curve. Closing is quicker, 260ms.
            .animation(
                reduceMotion
                    ? .easeInOut(duration: 0.2)
                    : .timingCurve(0.32, 0.72, 0, 1, duration: open ? 0.38 : 0.26),
                value: open
            )
        }
        .task {
            await library.load()
            // First visit: this week's #1 waits in the mini player, ready to play.
            if player.current == nil, let first = library.chart ?? library.home?.rails.first {
                player.cue(first.hooks, at: 0)
            }
        }
    }
}

#Preview {
    RootView()
        .environment(Library())
        .environment(Player())
        .preferredColorScheme(.dark)
}
