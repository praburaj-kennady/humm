import SwiftUI

/// Browse: the home screen. Rails of hooks; tap one to start listening.
struct BrowseView: View {
    @Environment(Library.self) private var library
    @Environment(Player.self) private var player
    @State private var showSearch = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                if let error = library.loadError {
                    errorState(error)
                } else if library.home == nil {
                    ProgressView()
                        .tint(Theme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 120)
                } else {
                    content
                }
            }
            .padding(.bottom, 130) // room for the mini player
        }
        .scrollIndicators(.hidden)
        .background(Theme.bg)
        .overlay(alignment: .bottom) {
            LinearGradient(
                stops: [.init(color: Theme.bg.opacity(0), location: 0), .init(color: Theme.bg.opacity(0.85), location: 0.5), .init(color: Theme.bg, location: 1)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 170)
            .ignoresSafeArea(edges: .bottom)
            .allowsHitTesting(false)
        }
        .refreshable { await library.load() }
        .sheet(isPresented: $showSearch) { SearchView() }
    }

    private var header: some View {
        HStack {
            Text("Browse")
                .font(.system(size: 34, weight: .bold))
                .tracking(-0.408)
            Spacer()
            if library.isDemo {
                Text("Demo data")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.accent.opacity(0.14), in: Capsule())
            }
            Button { showSearch = true } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 17, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .background(Theme.raised, in: Circle())
            }
            .buttonStyle(PressScale())
            .accessibilityLabel("Search")
        }
        .frame(height: 44)
        .padding(.horizontal, 20)
        .padding(.top, 4)
    }

    @ViewBuilder
    private var content: some View {
        if !library.moodRails.isEmpty {
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(library.moodRails) { rail in
                        Button(rail.title) { player.play(rail.hooks, at: 0, open: true) }
                            .font(.system(size: 14, weight: .medium))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Theme.raised, in: Capsule())
                            .buttonStyle(PressScale(scale: 0.97))
                    }
                }
            }
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .scrollIndicators(.hidden)
            .padding(.top, 12)
        }

        if let chart = library.chart {
            section(title: "Trending hooks", subtitle: nil, playAll: chart.hooks) {
                ForEach(Array(chart.hooks.enumerated()), id: \.element.id) { i, hook in
                    HookCard(hook: hook, size: .large, showRank: hook.trendRank != nil, isPlaying: isPlaying(hook)) {
                        player.play(chart.hooks, at: i, open: true)
                    }
                }
            }
            if library.home?.chart?.isSample == true {
                Text("Sample chart while we gather real numbers.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
            }
        }

        if !library.saved.isEmpty {
            section(title: "Your saved hooks", subtitle: nil, playAll: library.saved) {
                ForEach(Array(library.saved.enumerated()), id: \.element.id) { i, hook in
                    HookCard(hook: hook, size: .small, isPlaying: isPlaying(hook)) {
                        player.play(library.saved, at: i, open: true)
                    }
                }
            }
        }

        if !library.composers.isEmpty {
            section(title: "By composer", subtitle: nil, playAll: nil, spacing: 14) {
                ForEach(library.composers) { composer in
                    Button { player.play(composer.hooks, at: 0, open: true) } label: {
                        VStack(spacing: 7) {
                            Text(Format.initials(Format.shortName(composer.name)))
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                                .frame(width: 66, height: 66)
                                .background(Theme.gradient(for: composer.name), in: Circle())
                            Text(Format.shortName(composer.name))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(Theme.muted)
                        }
                    }
                    .buttonStyle(PressScale())
                }
            }
        }

        ForEach(library.otherRails) { rail in
            section(title: rail.title, subtitle: rail.subtitle, playAll: rail.hooks) {
                ForEach(Array(rail.hooks.enumerated()), id: \.element.id) { i, hook in
                    HookCard(hook: hook, size: .small, isPlaying: isPlaying(hook)) {
                        player.play(rail.hooks, at: i, open: true)
                    }
                }
            }
        }

        footer
    }

    private func section<Cards: View>(
        title: String,
        subtitle: String?,
        playAll: [Hook]?,
        spacing: CGFloat = 10,
        @ViewBuilder cards: () -> Cards
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 20, weight: .bold))
                        .tracking(-0.1)
                    if let subtitle {
                        Text(subtitle).font(.system(size: 13)).foregroundStyle(Theme.muted)
                    }
                }
                Spacer()
                if let playAll, !playAll.isEmpty {
                    Button("Play all") { player.play(playAll, at: 0, open: true) }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.accent)
                }
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal) {
                LazyHStack(spacing: spacing) { cards() }
                    .scrollTargetLayout()
            }
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
        }
        .padding(.top, 22)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Hooks play through the official YouTube player. Humm never hosts or cuts audio.")
            Text("A portfolio project by Praburaj Kennady, built in public.")
        }
        .font(.system(size: 12))
        .foregroundStyle(Theme.muted)
        .padding(.horizontal, 20)
        .padding(.top, 36)
    }

    private func errorState(_ message: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Couldn't load hooks.").font(.system(size: 17, weight: .semibold))
            Text(message).font(.system(size: 13)).foregroundStyle(Theme.muted)
            Button("Try again") { Task { await library.load() } }
                .foregroundStyle(Theme.accent)
        }
        .padding(20)
    }

    private func isPlaying(_ hook: Hook) -> Bool {
        player.current?.id == hook.id && player.isPlaying
    }
}
