import SwiftUI

/// The red YouTube mark, drawn so we don't ship their logo file.
struct YouTubeGlyph: View {
    var size: CGFloat = 14
    var body: some View {
        RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
            .fill(Color(hex: 0xFF1A1A))
            .frame(width: size * 0.92, height: size * 0.66)
            .overlay(
                Image(systemName: "play.fill")
                    .font(.system(size: size * 0.32, weight: .black))
                    .foregroundStyle(.white)
            )
            .frame(width: size, height: size)
    }
}

/// The Instagram camera mark in its gradient.
struct InstagramGlyph: View {
    var size: CGFloat = 14
    private var gradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: 0xFEDA75), Color(hex: 0xFA7E1E), Color(hex: 0xD62976), Color(hex: 0x962FBF)],
            startPoint: .bottomLeading,
            endPoint: .topTrailing
        )
    }
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .strokeBorder(gradient, lineWidth: size * 0.1)
            Circle()
                .strokeBorder(gradient, lineWidth: size * 0.1)
                .frame(width: size * 0.42, height: size * 0.42)
            Circle()
                .fill(Color(hex: 0xD62976))
                .frame(width: size * 0.11, height: size * 0.11)
                .offset(x: size * 0.22, y: -size * 0.22)
        }
        .frame(width: size * 0.86, height: size * 0.86)
        .frame(width: size, height: size)
    }
}

struct SourceGlyph: View {
    let source: String
    var size: CGFloat = 14
    var body: some View {
        if source == "instagram" { InstagramGlyph(size: size) } else { YouTubeGlyph(size: size) }
    }
}

/// Small dark pill with a glyph, e.g. "▶ #1" on cards or "YouTube" in Listen.
struct Chip: View {
    let source: String
    let text: String
    var body: some View {
        HStack(spacing: 5) {
            SourceGlyph(source: source)
            Text(text).font(.system(size: 11, weight: .semibold))
        }
        .padding(.leading, 7)
        .padding(.trailing, 9)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.55), in: Capsule())
    }
}

/// A YouTube thumbnail, cropped past the black bars YouTube adds.
struct Thumbnail: View {
    let hook: Hook
    /// Flips when a download finishes, so the picture appears.
    @State private var loaded = false

    var body: some View {
        let _ = loaded
        let image = hook.thumbnail.flatMap { ImageStore.shared.cached($0) }
        Rectangle()
            .fill(Theme.gradient(for: hook.songSlug))
            .overlay {
                if let image {
                    // YouTube thumbnails have black bars top and bottom; zoom past them.
                    Image(uiImage: image).resizable().scaledToFill().scaleEffect(1.34)
                }
            }
            .clipped()
            .task(id: hook.thumbnail) {
                guard let url = hook.thumbnail, ImageStore.shared.cached(url) == nil else { return }
                if await ImageStore.shared.load(url) != nil { loaded.toggle() }
            }
    }
}

/// A hook card on Browse. Large on the chart rail, small elsewhere.
struct HookCard: View {
    enum Size { case large, small }

    let hook: Hook
    let size: Size
    var showRank = false
    var isPlaying = false
    let action: () -> Void

    private var dimensions: CGSize {
        size == .large ? CGSize(width: 132, height: 226) : CGSize(width: 108, height: 190)
    }

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottomLeading) {
                Thumbnail(hook: hook)
                LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 3) {
                    Text(hook.songTitle)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(2)
                    Text([hook.movie, Format.shortName(hook.composer)].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                        .font(.system(size: 12))
                        .opacity(0.85)
                        .lineLimit(2)
                }
                .multilineTextAlignment(.leading)
                .padding(10)
            }
            .overlay(alignment: .topLeading) {
                Chip(source: hook.source, text: showRank ? "#\(hook.trendRank ?? 0)" : (hook.isYouTube ? "YouTube" : "Reel"))
                    .padding(8)
            }
            .overlay(alignment: .topTrailing) {
                if isPlaying { EqualizerBars().padding(10) }
            }
            .overlay {
                if isPlaying {
                    RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(Theme.accent, lineWidth: 2)
                }
            }
            .frame(width: dimensions.width, height: dimensions.height)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .foregroundStyle(Theme.text)
        }
        .buttonStyle(PressScale(scale: 0.97))
        .accessibilityLabel("Play \(hook.songTitle), \(hook.label)")
    }
}

/// Three bouncing bars that mark the card that's playing.
struct EqualizerBars: View {
    @State private var up = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let tall: [CGFloat] = [14, 6, 11]
    private let short: [CGFloat] = [5, 13, 7]

    var body: some View {
        HStack(alignment: .bottom, spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Theme.accent)
                    .frame(width: 3, height: up ? tall[i] : short[i])
            }
        }
        .frame(height: 14, alignment: .bottom)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.45).repeatForever(autoreverses: true)) { up = true }
        }
    }
}
