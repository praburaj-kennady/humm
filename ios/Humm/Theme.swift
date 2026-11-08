import SwiftUI

/// Colours from the "Pallavi" variables in the Figma file.
enum Theme {
    static let bg = Color(hex: 0x0B0B0C)
    static let surface = Color(hex: 0x161618)
    static let raised = Color(hex: 0x222225)
    static let text = Color(hex: 0xF5F3EE)
    static let muted = Color(hex: 0xA19D95)
    static let accent = Color(hex: 0xFFB020)
    static let onAccent = Color(hex: 0x1A1204)

    /// Warm card gradients from the Figma cards. Used behind thumbnails and avatars.
    private static let gradients: [(UInt32, UInt32)] = [
        (0xFF8A3D, 0x5A0B32), (0xFFC24B, 0x9E2A12), (0x2FBF71, 0x0D3B2E),
        (0xE04B2C, 0x2A0B08), (0x8C6CFF, 0x1E1446), (0x3D7BFF, 0x14143A),
        (0xC9A227, 0x2B2410), (0xFF4F8B, 0x3E0D46), (0x5FC8E8, 0x123A5C),
    ]

    static func gradient(for seed: String) -> LinearGradient {
        let pair = gradients[stableHash(seed) % gradients.count]
        return LinearGradient(
            colors: [Color(hex: pair.0), Color(hex: pair.1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Swift's own hashValue changes every launch; this one doesn't.
    static func stableHash(_ s: String) -> Int {
        var h: UInt32 = 5381
        for byte in s.utf8 { h = (h &* 33) &+ UInt32(byte) }
        return Int(h & 0x7FFF_FFFF)
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

/// Buttons shrink a little while pressed (Figma motion notes: scale 0.95, 140ms ease-out).
struct PressScale: ButtonStyle {
    var scale: CGFloat = 0.95
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1)
            .animation(.easeOut(duration: 0.14), value: configuration.isPressed)
    }
}

enum Format {
    static func clock(_ ms: Double) -> String {
        let s = max(0, Int(ms / 1000))
        return "\(s / 60):" + String(format: "%02d", s % 60)
    }

    static func range(_ hook: Hook) -> String {
        "\(clock(Double(hook.startMs))) – \(clock(Double(hook.endMs)))"
    }

    /// "Anirudh Ravichander" becomes "Anirudh" on small cards.
    static func shortName(_ name: String?) -> String {
        guard let name else { return "" }
        let known = [
            "Anirudh Ravichander": "Anirudh",
            "Yuvan Shankar Raja": "Yuvan",
            "G. V. Prakash Kumar": "G. V. Prakash",
            "Santhosh Narayanan": "Santhosh N.",
        ]
        return known[name] ?? name
    }

    static func initials(_ name: String) -> String {
        let words = name.replacingOccurrences(of: ".", with: " ").split(separator: " ")
        return words.prefix(2).compactMap { $0.first.map { String($0).uppercased() } }.joined()
    }

    /// A made-up but stable waveform for a hook. We don't analyse the audio.
    static func waveform(seed: String, bars: Int) -> [CGFloat] {
        var x = UInt32(truncatingIfNeeded: Theme.stableHash(seed) | 1)
        let phase = Double(Theme.stableHash(seed) % 7)
        return (0..<bars).map { i in
            x = x &* 1_103_515_245 &+ 12345
            let noise = Double((x >> 16) % 1000) / 1000
            let swell = 0.55 + 0.45 * sin(Double(i) / Double(bars) * .pi * 3 + phase)
            return CGFloat(0.22 + 0.78 * min(1, noise * 0.6 + swell * 0.5))
        }
    }
}
