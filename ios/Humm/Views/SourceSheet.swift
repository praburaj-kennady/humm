import SwiftUI

/// "Where this hook is from": the top Reel, the full song, and Make a reel.
struct SourceSheet: View {
    let hook: Hook
    /// The sheet is exactly as tall as what's in it, measured after layout.
    @State private var contentHeight: CGFloat = 330

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Where this hook is from")
                    .font(.system(size: 20, weight: .bold))
                    .tracking(-0.08)
                Text([hook.songTitle, hook.movie, Format.shortName(hook.composer)].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.muted)
            }

            SourceRow(
                link: hook.topReelLink,
                title: "Top Reel with this hook",
                subtitle: hook.topReelLink == nil ? "No Reel linked yet" : "Instagram · the Reel that made it go viral"
            ) { InstagramGlyph(size: 20) }

            SourceRow(
                link: hook.fullSongLink,
                title: "Full song",
                subtitle: "YouTube · official video song"
            ) { YouTubeGlyph(size: 20) }

            if let url = hook.makeReelLink {
                Link(destination: url) { makeLabel }
                    .buttonStyle(PressScale(scale: 0.98))
            } else {
                makeLabel.opacity(0.4)
                Text("The Instagram audio for this hook isn't linked yet.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity)
                    .padding(.top, -6)
            }
        }
        .foregroundStyle(Theme.text)
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 28)
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { contentHeight = $0 }
        .frame(maxHeight: .infinity, alignment: .top)
        .presentationDetents([.height(contentHeight)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .presentationBackground(Theme.surface)
    }

    private var makeLabel: some View {
        Label("Make a reel with this hook", systemImage: "plus.app")
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Theme.onAccent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 15)
            .background(Theme.accent, in: Capsule())
    }
}

private struct SourceRow<Glyph: View>: View {
    let link: URL?
    let title: String
    let subtitle: String
    @ViewBuilder let glyph: () -> Glyph

    var body: some View {
        if let link {
            Link(destination: link) { row }
                .buttonStyle(PressScale(scale: 0.98))
        } else {
            row.opacity(0.55)
        }
    }

    private var row: some View {
        HStack(spacing: 12) {
            glyph()
                .frame(width: 40, height: 40)
                .background(.black.opacity(0.5), in: Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 16, weight: .semibold))
                Text(subtitle).font(.system(size: 13)).foregroundStyle(Theme.muted)
            }
            Spacer(minLength: 0)
            if link != nil {
                Image(systemName: "arrow.up.forward.square")
                    .font(.system(size: 17))
                    .foregroundStyle(Theme.muted)
            }
        }
        .foregroundStyle(Theme.text)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.raised, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
