import SwiftUI

/// Search across every hook: song, movie, composer, singer or mood.
struct SearchView: View {
    @Environment(Library.self) private var library
    @Environment(Player.self) private var player
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var results: [Hook] {
        let needle = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !needle.isEmpty else { return library.allHooks }
        return library.allHooks.filter { hook in
            let fields = [hook.songTitle, hook.songTitleTa, hook.movie, hook.composer, hook.label, hook.lyricLine].compactMap { $0 }
                + (hook.singers ?? []) + (hook.moods ?? [])
            return fields.contains { $0.lowercased().contains(needle) }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(Array(results.enumerated()), id: \.element.id) { i, hook in
                    Button {
                        let list = results
                        dismiss()
                        player.play(list, at: i, open: true)
                    } label: {
                        HStack(spacing: 12) {
                            Thumbnail(hook: hook)
                                .frame(width: 48, height: 48)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(hook.songTitle).font(.system(size: 16, weight: .semibold))
                                Text("\(hook.label) · \(Format.range(hook))")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.muted)
                                    .lineLimit(1)
                            }
                        }
                    }
                    .listRowBackground(Theme.bg)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.bg)
            .overlay {
                if results.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .navigationTitle("Search")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Songs, movies, composers")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Theme.accent)
                }
            }
        }
        .presentationBackground(Theme.bg)
    }
}
