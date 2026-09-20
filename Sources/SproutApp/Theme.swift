import SwiftUI

enum Palette {
    static let background = Color(hex: 0xF8F9F5)
    static let sidebar = Color(hex: 0xEFF2EB)
    static let ink = Color(hex: 0x293D34)
    static let secondary = Color(hex: 0x788379)
    static let green = Color(hex: 0x50775E)
    static let greenLight = Color(hex: 0xE5EEDF)
    static let line = Color(hex: 0xE5E9E0)
    static let orange = Color(hex: 0xC78957)
    static let peach = Color(hex: 0xFAEFDF)
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 255) / 255,
                  green: Double((hex >> 8) & 255) / 255, blue: Double(hex & 255) / 255, opacity: 1)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var compact = false
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: compact ? 12 : 13, weight: .semibold))
            .padding(.horizontal, compact ? 15 : 20)
            .padding(.vertical, compact ? 10 : 13)
            .foregroundStyle(.white)
            .background(Palette.green.opacity(configuration.isPressed ? 0.8 : 1), in: RoundedRectangle(cornerRadius: 12))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct SoftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 16).padding(.vertical, 12)
            .foregroundStyle(Palette.green)
            .background(.white.opacity(configuration.isPressed ? 0.5 : 0.85), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Palette.line, lineWidth: 1))
    }
}

struct Card<Content: View>: View {
    var padding: CGFloat = 24
    @ViewBuilder var content: Content
    var body: some View {
        content.padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(Palette.line.opacity(0.8), lineWidth: 1))
    }
}

struct SectionHeading: View {
    let symbol: String
    let title: String
    var color: Color = Palette.green
    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: symbol).foregroundStyle(color)
            Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(Palette.ink)
        }
    }
}
