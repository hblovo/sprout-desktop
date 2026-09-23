import AppKit
import SwiftUI

/// Renders the app's own view tree to an image, without taking a desktop screenshot.
@MainActor enum PreviewRenderer {
    static func render(to directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = HealthStore(demo: true)
        store.updatePreferences { $0.reduceMotion = true }
        let renderer = ImageRenderer(content: RootView(store: store).frame(width: 1100, height: 800))
        renderer.scale = 2
        guard let image = renderer.cgImage else { throw RenderError.failed }
        let bitmap = NSBitmapImageRep(cgImage: image)
        guard let bytes = bitmap.representation(using: .png, properties: [:]) else { throw RenderError.failed }
        try bytes.write(to: directory.appendingPathComponent("芽伴-界面预览.png"))
        store.updatePreferences { $0.quietHoursEnabled = false }
        store.enginePreviewDue()
        let state = store.mascotPresentation
        let comparison = ImageRenderer(content: HStack(spacing: 24) {
            MascotScene(resting: state.resting, happy: state.happy, working: state.working, caption: state.caption, animate: false)
            DesktopPetView(store: store, menu: { NSMenu() }, moved: {}, interactionEnabled: false)
        }.padding(24).background(Color(hex: 0xF7F8F2)))
        comparison.scale = 2
        if let image = comparison.cgImage,
           let bytes = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
            try bytes.write(to: directory.appendingPathComponent("芽伴-状态同步预览.png"))
        }
        let growth = ImageRenderer(content: MascotScene(happy: true, growing: true, caption: "饮水达标 · Lv.2 · 成长值 +10", animate: false).padding(32).background(Color(hex: 0xF7F8F2)))
        growth.scale = 2
        if let image = growth.cgImage,
           let bytes = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
            try bytes.write(to: directory.appendingPathComponent("芽伴-成长预览.png"))
        }
        let pet = ImageRenderer(content: Mascot(size: 220, working: true, animate: false).padding(30).background(Color(hex: 0xF7F8F2)))
        pet.scale = 2
        if let image = pet.cgImage,
           let bytes = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) {
            try bytes.write(to: directory.appendingPathComponent("芽伴-Codex工作预览.png"))
        }
    }
    enum RenderError: Error { case failed }
}
