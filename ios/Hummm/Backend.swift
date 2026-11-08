import Foundation

// The app's only connection to the backend (the "librarian's counter window").
// Three questions it can ask: get_home, get_feed and toggle_save.
// See docs/API.md in the repo.
//
// Settings come from Supabase.plist (not committed, see ios/README.md).
// Without it the app runs on demo data from DemoHome.json and keeps
// saves on the phone.

struct SupabaseConfig: Sendable {
    let url: URL
    let key: String

    static func load() -> SupabaseConfig? {
        guard
            let file = Bundle.main.url(forResource: "Supabase", withExtension: "plist"),
            let data = try? Data(contentsOf: file),
            let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
            let urlString = plist["SUPABASE_URL"] as? String,
            let key = plist["SUPABASE_PUBLISHABLE_KEY"] as? String,
            !key.isEmpty, !key.contains("<"), !urlString.contains("<"),
            let url = URL(string: urlString)
        else { return nil }
        return SupabaseConfig(url: url, key: key)
    }
}

enum BackendError: LocalizedError {
    case http(Int, String)

    var errorDescription: String? {
        switch self {
        case let .http(code, body): return "The server said \(code). \(body.prefix(140))"
        }
    }
}

/// The numbered wristband: an anonymous user id, kept on this phone.
private struct Session: Codable {
    var accessToken: String
    var refreshToken: String
    var expiresAt: Double
}

private struct AuthResponse: Decodable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Double?
    let expiresAt: Double?
}

actor Backend {
    static let shared = Backend()

    nonisolated let config: SupabaseConfig? = SupabaseConfig.load()
    nonisolated var isDemo: Bool { config == nil }

    private let sessionKey = "hummm.session"
    private let demoSavesKey = "hummm.demo-saves"

    private let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }()

    // MARK: The three calls

    func home() async throws -> Home {
        guard let config else { return try demoHome() }
        let token = try? await validSession(config)?.accessToken
        let data = try await rpc("get_home", ["p_rail_limit": 20], config: config, token: token)
        return try decoder.decode(Home.self, from: data)
    }

    /// A rail slug, "saved", or nil for everything (chart first).
    func feed(rail: String?) async throws -> [Hook] {
        guard let config else {
            let home = try demoHome()
            if rail == "saved" { return home.saved ?? [] }
            return home.rails.first { $0.slug == rail }?.hooks ?? home.rails.flatMap(\.hooks)
        }
        var params: [String: Any] = ["p_limit": 30]
        if let rail { params["p_rail"] = rail }
        let token = try? await validSession(config)?.accessToken
        let data = try await rpc("get_feed", params, config: config, token: token)
        return try decoder.decode([Hook].self, from: data)
    }

    /// Returns true when the hook is now saved.
    func toggleSave(hookId: String) async throws -> Bool {
        guard let config else {
            var ids = UserDefaults.standard.stringArray(forKey: demoSavesKey) ?? []
            let nowSaved = !ids.contains(hookId)
            if nowSaved { ids.insert(hookId, at: 0) } else { ids.removeAll { $0 == hookId } }
            UserDefaults.standard.set(ids, forKey: demoSavesKey)
            return nowSaved
        }
        // Saving needs a wristband. The first save gets one, no sign-up screen.
        var session = try await validSession(config)
        if session == nil { session = try await signInAnonymously(config) }
        let data = try await rpc("toggle_save", ["p_hook_id": hookId], config: config, token: session?.accessToken)
        return try decoder.decode(Bool.self, from: data)
    }

    // MARK: Plumbing

    private func rpc(_ name: String, _ params: [String: Any], config: SupabaseConfig, token: String?) async throws -> Data {
        var request = URLRequest(url: config.url.appendingPathComponent("rest/v1/rpc/\(name)"))
        request.httpMethod = "POST"
        request.setValue(config.key, forHTTPHeaderField: "apikey")
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: params)
        return try await send(request)
    }

    private func send(_ request: URLRequest) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        let code = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(code) else {
            throw BackendError.http(code, String(decoding: data, as: UTF8.self))
        }
        return data
    }

    private func signInAnonymously(_ config: SupabaseConfig) async throws -> Session {
        var request = URLRequest(url: config.url.appendingPathComponent("auth/v1/signup"))
        request.httpMethod = "POST"
        request.setValue(config.key, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{}".utf8)
        let data = try await send(request)
        return try store(decoder.decode(AuthResponse.self, from: data))
    }

    /// The saved wristband, refreshed if it's about to expire. Nil if we never got one.
    private func validSession(_ config: SupabaseConfig) async throws -> Session? {
        guard
            let data = UserDefaults.standard.data(forKey: sessionKey),
            let session = try? JSONDecoder().decode(Session.self, from: data)
        else { return nil }
        if session.expiresAt - 60 > Date().timeIntervalSince1970 { return session }

        var components = URLComponents(url: config.url.appendingPathComponent("auth/v1/token"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "grant_type", value: "refresh_token")]
        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue(config.key, forHTTPHeaderField: "apikey")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["refresh_token": session.refreshToken])
        do {
            let data = try await send(request)
            return try store(decoder.decode(AuthResponse.self, from: data))
        } catch {
            UserDefaults.standard.removeObject(forKey: sessionKey)
            return nil
        }
    }

    private func store(_ auth: AuthResponse) throws -> Session {
        let expiresAt = auth.expiresAt ?? (Date().timeIntervalSince1970 + (auth.expiresIn ?? 3600))
        let session = Session(accessToken: auth.accessToken, refreshToken: auth.refreshToken, expiresAt: expiresAt)
        UserDefaults.standard.set(try JSONEncoder().encode(session), forKey: sessionKey)
        return session
    }

    private func demoHome() throws -> Home {
        guard let file = Bundle.main.url(forResource: "DemoHome", withExtension: "json") else {
            throw BackendError.http(0, "DemoHome.json is missing from the app.")
        }
        let home = try decoder.decode(Home.self, from: Data(contentsOf: file))
        let all = home.rails.flatMap(\.hooks)
        let ids = UserDefaults.standard.stringArray(forKey: demoSavesKey) ?? []
        let saved = ids.compactMap { id in all.first { $0.id == id } }
        return Home(chart: home.chart, rails: home.rails, saved: saved)
    }
}
