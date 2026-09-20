import SwiftUI

struct SproutBody: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * rect.width, y: y * rect.height) }
        path.move(to: p(0.5, 0.03))
        path.addCurve(to: p(0.9, 0.4), control1: p(0.75, 0), control2: p(0.86, 0.17))
        path.addCurve(to: p(0.91, 0.82), control1: p(0.96, 0.57), control2: p(1, 0.74))
        path.addCurve(to: p(0.55, 0.97), control1: p(0.85, 0.96), control2: p(0.67, 0.98))
        path.addCurve(to: p(0.13, 0.88), control1: p(0.38, 0.98), control2: p(0.21, 1))
        path.addCurve(to: p(0.1, 0.47), control1: p(0.02, 0.8), control2: p(0.06, 0.62))
        path.addCurve(to: p(0.5, 0.03), control1: p(0.16, 0.16), control2: p(0.25, 0.04))
        path.closeSubpath()
        return path
    }
}

struct Leaf: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.minX, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        return p
    }
}

/// A resolution-independent character: no downloaded assets or animation runtime.
struct Mascot: View {
    var size: CGFloat = 180
    var resting = false
    var happy = false
    var animate = true
    @Environment(\.accessibilityReduceMotion) private var systemReduceMotion
    @State private var breathe = false

    var body: some View {
        ZStack {
            Ellipse().fill(Palette.green.opacity(0.11))
                .frame(width: size * 0.65, height: size * 0.08).offset(y: size * 0.43)
            character
                .offset(y: breathe && animate && !systemReduceMotion ? -size * 0.018 : 0)
                .rotationEffect(.degrees(resting ? -5 : 0))
        }
        .frame(width: size, height: size * 1.1)
        .onAppear {
            guard animate && !systemReduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true)) { breathe = true }
        }
        .accessibilityLabel(resting ? "正在休息的小芽" : "陪伴你的小芽")
        .accessibilityAddTraits(.isImage)
    }

    private var character: some View {
        ZStack {
            Capsule().fill(Color(hex: 0xB4CDA1)).frame(width: size * 0.13, height: size * 0.18)
                .rotationEffect(.degrees(18)).offset(x: -size * 0.17, y: size * 0.35)
            Capsule().fill(Color(hex: 0xB4CDA1)).frame(width: size * 0.13, height: size * 0.18)
                .rotationEffect(.degrees(-18)).offset(x: size * 0.17, y: size * 0.35)
            Capsule().fill(Color(hex: 0xBED4AA)).frame(width: size * 0.14, height: size * 0.25)
                .rotationEffect(.degrees(happy ? -65 : 32)).offset(x: -size * 0.35, y: size * 0.09)
            Capsule().fill(Color(hex: 0xBED4AA)).frame(width: size * 0.14, height: size * 0.25)
                .rotationEffect(.degrees(happy ? 65 : -32)).offset(x: size * 0.35, y: size * 0.09)
            SproutBody()
                .fill(LinearGradient(colors: [Color(hex: 0xE5EDCE), Color(hex: 0xCDDEB6)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(SproutBody().stroke(Color(hex: 0xB4CB9B).opacity(0.6), lineWidth: size * 0.006))
                .frame(width: size * 0.81, height: size * 0.77)
                .shadow(color: Palette.green.opacity(0.08), radius: size * 0.035, y: size * 0.02)
            Ellipse().fill(.white.opacity(0.23)).frame(width: size * 0.27, height: size * 0.13)
                .rotationEffect(.degrees(-24)).offset(x: -size * 0.15, y: -size * 0.21)
            Capsule().fill(Palette.green).frame(width: size * 0.026, height: size * 0.17)
                .rotationEffect(.degrees(12)).offset(y: -size * 0.4)
            Leaf().fill(Color(hex: 0x789C63)).frame(width: size * 0.23, height: size * 0.14)
                .rotationEffect(.degrees(-5)).offset(x: size * 0.1, y: -size * 0.47)
            Leaf().fill(Color(hex: 0x9DB87A)).frame(width: size * 0.19, height: size * 0.12)
                .rotationEffect(.degrees(-90)).offset(x: -size * 0.09, y: -size * 0.43)
            HStack(spacing: size * 0.18) {
                eye
                eye
            }.offset(y: -size * 0.015)
            HStack(spacing: size * 0.30) {
                Ellipse().fill(Color(hex: 0xD8AD86).opacity(0.48))
                Ellipse().fill(Color(hex: 0xD8AD86).opacity(0.48))
            }.frame(width: size * 0.44, height: size * 0.055).offset(y: size * 0.06)
            Path { p in
                p.move(to: CGPoint(x: size * 0.455, y: size * 0.555))
                p.addQuadCurve(to: CGPoint(x: size * 0.545, y: size * 0.555), control: CGPoint(x: size * 0.50, y: size * 0.605))
            }.stroke(Palette.ink, style: StrokeStyle(lineWidth: size * 0.014, lineCap: .round))
                .frame(width: size, height: size)
        }
    }

    @ViewBuilder private var eye: some View {
        if resting {
            Capsule().fill(Palette.ink).frame(width: size * 0.052, height: size * 0.014)
        } else {
            Capsule().fill(Palette.ink).frame(width: size * 0.034, height: size * 0.053)
        }
    }
}

struct MascotScene: View {
    var resting = false
    var happy = false
    var animate = true
    var body: some View {
        ZStack {
            Circle().fill(.white.opacity(0.32)).frame(width: 225, height: 225)
            Circle().stroke(.white.opacity(0.42), lineWidth: 1).frame(width: 263, height: 263)
            Image(systemName: "sparkle").font(.system(size: 21, weight: .light))
                .foregroundStyle(Palette.green.opacity(0.4)).offset(x: 108, y: -69)
            Image(systemName: "plus").font(.system(size: 13, weight: .light))
                .foregroundStyle(Palette.green.opacity(0.35)).offset(x: -104, y: 35)
            Circle().fill(Palette.orange.opacity(0.45)).frame(width: 7, height: 7).offset(x: -90, y: -83)
            Mascot(size: 177, resting: resting, happy: happy, animate: animate).offset(y: 15)
            Text(resting ? "呼——让肩膀放松下来" : "身体也需要 commit 一点关心")
                .font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.green)
                .padding(.horizontal, 13).padding(.vertical, 9)
                .background(.white.opacity(0.85), in: Capsule()).offset(y: 114)
        }.frame(width: 290, height: 265)
    }
}
