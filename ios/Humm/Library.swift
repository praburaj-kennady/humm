import SwiftUI
import Observation

/// Browse data (the rails) and your Saved list, shared by every screen.
@MainActor
@Observable
final class Library {
    private(set) var home: Home?
    private(set) var loadError: String?
    private(set) var saved: [Hook] = []
    private(set) var toast: String?

    var isDemo: Bool { Backend.shared.isDemo }

    var chart: Rail? { home?.rails.first { $0.kind == "chart" } }
    var moodRails: [Rail] { home?.rails.filter { $0.kind == "mood" } ?? [] }
    var otherRails: [Rail] { home?.rails.filter { $0.kind != "chart" } ?? [] }

    /// Every hook once, chart first. This is the "For you" feed.
    var allHooks: [Hook] {
        var seen = Set<String>()
        return (home?.rails ?? []).flatMap(\.hooks).filter { seen.insert($0.id).inserted }
    }

    struct Composer: Identifiable {
        let name: String
        let hooks: [Hook]
        var id: String { name }
    }

    /// Composers with their hooks, most hooks first.
    var composers: [Composer] {
        var order: [String] = []
        var byName: [String: [Hook]] = [:]
        for hook in allHooks {
            guard let name = hook.composer else { continue }
            if byName[name] == nil { order.append(name) }
            byName[name, default: []].append(hook)
        }
        return order
            .map { Composer(name: $0, hooks: byName[$0] ?? []) }
            .sorted { $0.hooks.count > $1.hooks.count }
    }

    func load() async {
        loadError = nil
        do {
            let fresh = try await Backend.shared.home()
            home = fresh
            saved = fresh.saved ?? []
            ImageStore.shared.prefetch(allHooks.compactMap(\.thumbnail))
        } catch {
            loadError = error.localizedDescription
        }
    }

    func isSaved(_ hook: Hook) -> Bool { saved.contains { $0.id == hook.id } }

    func toggleSave(_ hook: Hook) async {
        let wasSaved = isSaved(hook)
        // Change the screen first, then tell the backend. Undo if that fails.
        apply(hook, saved: !wasSaved)
        do {
            let nowSaved = try await Backend.shared.toggleSave(hookId: hook.id)
            apply(hook, saved: nowSaved)
            show(nowSaved ? "Saved" : "Removed from Saved")
        } catch {
            apply(hook, saved: wasSaved)
            show("Couldn't save right now")
        }
    }

    func show(_ message: String) {
        withAnimation(.easeOut(duration: 0.2)) { toast = message }
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            if toast == message { withAnimation(.easeIn(duration: 0.2)) { toast = nil } }
        }
    }

    private func apply(_ hook: Hook, saved isNowSaved: Bool) {
        saved.removeAll { $0.id == hook.id }
        if isNowSaved { saved.insert(hook, at: 0) }
    }
}
