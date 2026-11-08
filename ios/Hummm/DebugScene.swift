#if DEBUG
import Foundation

/// Debug builds only: lets CI open a given screen for a screenshot.
/// `xcrun simctl launch <device> me.praburajkennady.hummm -scene listen`
enum DebugScene {
    static var name: String? { UserDefaults.standard.string(forKey: "scene") }

    @MainActor
    static func apply(player: Player, library: Library) {
        guard let name, let chart = library.chart, chart.hooks.count > 2 else { return }
        if name == "listen" || name == "source" {
            player.play(chart.hooks, at: 2, open: true)
        }
    }
}
#endif
