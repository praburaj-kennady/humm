import SwiftUI

/// What's playing, docked at the bottom of Browse. Tap it to open Listen.
struct MiniPlayerView: View {
    @Environment(Player.self) private var player

    var body: some View {
        if let hook = player.current {
            HStack(spacing: 12) {
                Button { player.listenOpen = true } label: {
                    HStack(spacing: 12) {
                        Thumbnail(hook: hook)
                            .frame(width: 40, height: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(hook.songTitle)
                                .font(.system(size: 15, weight: .semibold))
                            Text("Hook \(Format.range(hook))" + (hook.movie.map { " · \($0)" } ?? ""))
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.muted)
                        }
                        .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressScale(scale: 0.98))
                .accessibilityLabel("Open \(hook.songTitle)")

                Button { player.toggle() } label: {
                    Image(systemName: player.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.onAccent)
                        .frame(width: 36, height: 36)
                        .background(Theme.accent, in: Circle())
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(PressScale(scale: 0.92))
                .accessibilityLabel(player.isPlaying ? "Pause" : "Play")
            }
            .foregroundStyle(Theme.text)
            .padding(.leading, 10)
            .padding(.trailing, 12)
            .frame(height: 60)
            .background(Theme.raised.opacity(0.92), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(alignment: .bottomLeading) {
                GeometryReader { g in
                    Rectangle()
                        .fill(Theme.accent)
                        .frame(width: g.size.width * player.progress, height: 2)
                        .frame(maxHeight: .infinity, alignment: .bottom)
                        .animation(.linear(duration: 0.2), value: player.progress)
                }
            }
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).strokeBorder(.white.opacity(0.06)))
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .shadow(color: .black.opacity(0.4), radius: 15, y: 10)
        }
    }
}
