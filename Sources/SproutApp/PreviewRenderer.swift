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
    }
    enum RenderError: Error { case failed }
}
