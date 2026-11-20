import SwiftUI

enum RingStyle: String {
    case none, done, penalty, postponed

    var color: Color {
        switch self {
        case .none: .clear
        case .done: .green
        case .penalty: .red
        case .postponed: .orange
        }
    }
}

/// Görev ikonu. Ceza varsa kırmızı halka + "x2" rozeti.
/// Halka ve rozet `size` karesinin içinde kalır; böylece bildirim görselinde kırpılmaz.
struct TaskIconView: View {
    let icon: String
    let color: Color
    var ring: RingStyle = .none
    var multiplier: Int = 1
    var size: CGFloat = 44

    var body: some View {
        let hasRing = ring != .none
        ZStack {
            if hasRing {
                Circle().strokeBorder(ring.color, lineWidth: size * 0.07)
            }
            Circle()
                .fill(color.gradient)
                .padding(hasRing ? size * 0.12 : 0)
            Image(systemName: icon)
                .font(.system(size: size * (hasRing ? 0.34 : 0.42), weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: size, height: size)
        .overlay(alignment: .topTrailing) {
            if multiplier > 1 {
                Text("x\(multiplier)")
                    .font(.system(size: size * 0.24, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, size * 0.07)
                    .padding(.vertical, size * 0.015)
                    .background(Capsule().fill(.red))
                    .overlay(Capsule().strokeBorder(.white, lineWidth: max(1, size * 0.02)))
                    .fixedSize()
                    .offset(x: size * 0.04, y: -size * 0.02)
            }
        }
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

enum Palette {
    static let colors = ["#FF6B35", "#E63946", "#F4A261", "#2A9D8F", "#06D6A0",
                         "#3A86FF", "#118AB2", "#8338EC", "#FF006E", "#6C757D"]
}

enum IconCatalog {
    static let icons = [
        "mouth.fill", "figure.strengthtraining.traditional", "dumbbell.fill", "figure.run",
        "figure.walk", "figure.mind.and.body", "drop.fill", "pills.fill",
        "book.fill", "brain.head.profile", "bed.double.fill", "shower.fill",
        "cup.and.saucer.fill", "fork.knife", "leaf.fill", "heart.fill",
        "sun.max.fill", "moon.fill", "bicycle", "cart.fill",
        "phone.fill", "envelope.fill", "house.fill", "trash.fill",
        "washer.fill", "pawprint.fill", "music.note", "pencil",
        "laptopcomputer", "creditcard.fill", "calendar", "flame.fill",
    ]
}

extension TaskSnapshot {
    var tint: Color { Color(hex: colorHex) }
}
