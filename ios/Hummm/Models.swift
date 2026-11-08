import Foundation

/// One hook: a time range inside a YouTube video or Instagram reel.
/// Same shape as the `hook_cards` view in the backend (see docs/API.md).
struct Hook: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let slug: String
    let label: String
    let lyricLine: String?
    let source: String // "youtube" or "instagram"
    let sourceId: String
    let startMs: Int
    let endMs: Int
    let timingVerified: Bool?
    let songSlug: String
    let songTitle: String
    let songTitleTa: String?
    let movie: String?
    let releaseYear: Int?
    let composer: String?
    let singers: [String]?
    let moods: [String]?
    let trendRank: Int?
    let lastWeekRank: Int?
    let embedUrl: String?
    let thumbnailUrl: String?
    let sourceUrl: String?
    let fullSongUrl: String?
    let topReelUrl: String?
    let makeReelUrl: String?

    var isYouTube: Bool { source == "youtube" }
    var thumbnail: URL? { thumbnailUrl.flatMap(URL.init(string:)) }
    var sourceLink: URL? { sourceUrl.flatMap(URL.init(string:)) }
    var fullSongLink: URL? { (fullSongUrl ?? sourceUrl).flatMap(URL.init(string:)) }
    var topReelLink: URL? { topReelUrl.flatMap(URL.init(string:)) }
    var makeReelLink: URL? { makeReelUrl.flatMap(URL.init(string:)) }

    /// "Jailer · Anirudh Ravichander · 2023"
    var meta: String {
        [movie, composer, releaseYear.map(String.init)].compactMap { $0 }.joined(separator: " · ")
    }
}

/// A row on Browse.
struct Rail: Codable, Identifiable, Hashable, Sendable {
    let slug: String
    let title: String
    let subtitle: String?
    let kind: String // "chart", "curated" or "mood"
    let hooks: [Hook]

    var id: String { slug }
}

struct Chart: Codable, Hashable, Sendable {
    let weekStart: String
    let title: String
    let isSample: Bool
}

/// Everything Browse needs, from one `get_home` call.
struct Home: Codable, Sendable {
    let chart: Chart?
    let rails: [Rail]
    let saved: [Hook]?
}
