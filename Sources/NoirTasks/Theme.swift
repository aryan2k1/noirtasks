import SwiftUI
import AppKit

/// Frosted-glass background (NSVisualEffectView) for widgets.
struct Glass: NSViewRepresentable {
    var material: NSVisualEffectView.Material = .hudWindow

    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = material
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }

    func updateNSView(_ v: NSVisualEffectView, context: Context) {
        v.material = material
    }
}

enum Theme {
    static let bg = Color(hex: "#0E0F13")
    static let panel = Color(hex: "#16181F")
    static let card = Color(hex: "#1D2029")
    static let cardHover = Color(hex: "#242836")
    static let accent = Color(hex: "#7C6CF6")
    static let text = Color(hex: "#E8EAF2")
    static let textDim = Color(hex: "#8A8F9E")
    static let danger = Color(hex: "#EF5350")
}

enum Palette {
    static let hexes = ["#7C6CF6", "#4FC3F7", "#66BB6A", "#FFB74D", "#EF5350", "#F06292", "#26A69A", "#FFD54F"]
    static let defaultHex = hexes[0]
}

extension Color {
    init(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        var v: UInt64 = 0
        Scanner(string: h).scanHexInt64(&v)
        let r = Double((v >> 16) & 0xFF) / 255
        let g = Double((v >> 8) & 0xFF) / 255
        let b = Double(v & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

extension Date {
    var startOfDay: Date { Calendar.current.startOfDay(for: self) }

    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }

    func formatted(_ format: String) -> String {
        let f = DateFormatter()
        f.dateFormat = format
        return f.string(from: self)
    }
}
