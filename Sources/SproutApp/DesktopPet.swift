import AppKit
import SwiftUI

final class PetPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor final class DesktopPetController {
    let panel: PetPanel
    private let store: HealthStore

    init(store: HealthStore, menu: @escaping () -> NSMenu) {
        self.store = store
        panel = PetPanel(contentRect: NSRect(x: 0, y: 0, width: 260, height: 280),
                         styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isFloatingPanel = true
        panel.isReleasedWhenClosed = false
        panel.title = "小芽桌宠"
        panel.animationBehavior = .none
        let view = DesktopPetView(store: store, menu: menu, moved: { [weak self] in self?.savePosition() })
        panel.contentView = NSHostingView(rootView: view)
        restorePosition()
        updateVisibility()
    }

    func updateVisibility() {
        if store.preferences.petVisible { panel.orderFrontRegardless() } else { panel.orderOut(nil) }
    }

    func keepOnScreen() {
        guard let screen = NSScreen.screens.first(where: { $0.visibleFrame.intersects(panel.frame) }) ?? NSScreen.main else { return }
        let frame = screen.visibleFrame
        let origin = CGPoint(x: min(max(panel.frame.minX, frame.minX), frame.maxX - panel.frame.width),
                             y: min(max(panel.frame.minY, frame.minY), frame.maxY - panel.frame.height))
        panel.setFrameOrigin(origin)
    }

    private func restorePosition() {
        guard let screen = NSScreen.main else { return }
        let defaults = UserDefaults.standard
        if !store.isDemo, defaults.object(forKey: "petX") != nil {
            panel.setFrameOrigin(CGPoint(x: defaults.double(forKey: "petX"), y: defaults.double(forKey: "petY")))
        } else {
            panel.setFrameOrigin(CGPoint(x: screen.visibleFrame.maxX - 272, y: screen.visibleFrame.minY + 28))
        }
        keepOnScreen()
    }

    private func savePosition() {
        keepOnScreen()
        guard !store.isDemo else { return }
        UserDefaults.standard.set(panel.frame.minX, forKey: "petX")
        UserDefaults.standard.set(panel.frame.minY, forKey: "petY")
    }
}

@MainActor struct DesktopPetView: View {
    @ObservedObject var store: HealthStore
    let menu: () -> NSMenu
    let moved: () -> Void
    var interactionEnabled = true
    @State private var hovered = false
    var presentation: MascotPresentation { store.mascotPresentation }

    var body: some View {
        VStack(spacing: 1) {
            Group {
                if store.pendingBreak != nil && !store.remindersMuted {
                    VStack(spacing: 10) {
                        Text(store.pendingBreak?.focusRestarted == true ? "计时已继续，刚才有活动吗？" : "欢迎回来，刚才有起身吗？").font(.system(size: 12, weight: .medium))
                        HStack(spacing: 9) {
                            Button("有，记一次") { store.confirmBreak() }.buttonStyle(PrimaryButtonStyle(compact: true))
                            Button("没有") { store.dismissBreak() }.buttonStyle(.plain).font(.system(size: 11))
                        }
                    }.padding(14).background(.white, in: RoundedRectangle(cornerRadius: 17))
                        .overlay(RoundedRectangle(cornerRadius: 17).stroke(Palette.line, lineWidth: 1))
                } else if store.engine.phase == .due && !store.remindersMuted {
                    VStack(spacing: 10) {
                        Text("坐了一会儿，起来走走吧。")
                            .font(.system(size: 12, weight: .medium))
                        HStack(spacing: 7) {
                            Button("休息 \(store.preferences.breakMinutes) 分钟") { store.startBreak() }.buttonStyle(PrimaryButtonStyle(compact: true))
                            Button("稍后 5 分钟") { store.snooze() }.buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(Palette.secondary)
                        }
                    }.padding(14).background(.white, in: RoundedRectangle(cornerRadius: 17))
                        .overlay(RoundedRectangle(cornerRadius: 17).stroke(Palette.line, lineWidth: 1))
                } else if store.waterNudge && !store.remindersMuted {
                    VStack(spacing: 10) {
                        Text("忙碌间隙，也记得喝口水。")
                            .font(.system(size: 12, weight: .medium))
                        HStack(spacing: 10) {
                            Button("喝了 \(store.preferences.cupML) mL") { store.addWater() }.buttonStyle(PrimaryButtonStyle(compact: true))
                            Button("知道啦") { store.waterNudge = false }.buttonStyle(.plain).font(.system(size: 10))
                        }
                    }.padding(14).background(.white, in: RoundedRectangle(cornerRadius: 17))
                } else if hovered {
                    HStack(spacing: 13) {
                        Button { store.addWater() } label: { Label("喝一杯", systemImage: "drop") }
                            .help("记录 \(store.preferences.cupML) mL")
                        Rectangle().fill(Palette.line).frame(width: 1, height: 13)
                        Button { store.togglePause() } label: {
                            Image(systemName: store.engine.isPaused ? "play" : "pause")
                        }.accessibilityLabel(store.engine.isPaused ? "继续计时" : "暂停计时")
                        Button { store.updatePreferences { $0.petVisible = false } } label: { Image(systemName: "xmark") }
                            .help("隐藏桌宠；可以从菜单栏再次开启").accessibilityLabel("隐藏桌宠")
                    }.font(.system(size: 11, weight: .medium)).buttonStyle(.plain).padding(.horizontal, 15).padding(.vertical, 12)
                        .background(.white, in: Capsule())
                } else {
                    Color.clear.frame(height: 1)
                }
            }.frame(height: 90, alignment: .bottom)
                .shadow(color: .black.opacity(0.07), radius: 8, y: 3)
            Mascot(size: 117, resting: presentation.resting,
                   happy: presentation.happy, working: presentation.working, growing: store.celebratingGrowth, animate: !store.preferences.reduceMotion)
                .overlay {
                    if interactionEnabled { PetDragArea(clicked: { store.showWindow?() }, moved: moved, menu: menu) }
                }
                .padding(.top, 10)
            Text(petCaption).font(.system(size: 10, weight: .medium, design: .rounded)).monospacedDigit()
                .foregroundStyle(Palette.green).padding(.horizontal, 11).padding(.vertical, 5)
                .background(.white.opacity(0.92), in: Capsule())
                .onTapGesture { store.showWindow?() }
            Spacer(minLength: 0)
        }
        .frame(width: 260, height: 280)
        .foregroundStyle(Palette.ink)
        .onHover { hovered = $0 }
        .preferredColorScheme(.light)
        
    }

    private var petCaption: String { presentation.caption }

}

struct PetDragArea: NSViewRepresentable {
    let clicked: () -> Void
    let moved: () -> Void
    let menu: () -> NSMenu
    func makeNSView(context: Context) -> PetDragView {
        let view = PetDragView()
        view.clicked = clicked
        view.moved = moved
        view.menuProvider = menu
        view.setAccessibilityElement(true)
        view.setAccessibilityRole(.button)
        view.setAccessibilityLabel("小芽桌宠，点击打开面板，拖动移动")
        return view
    }
    func updateNSView(_ nsView: PetDragView, context: Context) {}
}

final class PetDragView: NSView {
    var clicked: (() -> Void)?
    var moved: (() -> Void)?
    var menuProvider: (() -> NSMenu)?
    private var original = CGPoint.zero
    private var anchor = CGPoint.zero
    private var dragged = false

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) {
        original = window?.frame.origin ?? .zero
        anchor = NSEvent.mouseLocation
        dragged = false
    }
    override func mouseDragged(with event: NSEvent) {
        let pointer = NSEvent.mouseLocation
        let delta = CGPoint(x: pointer.x - anchor.x, y: pointer.y - anchor.y)
        if hypot(delta.x, delta.y) > 4 { dragged = true }
        if dragged { window?.setFrameOrigin(CGPoint(x: original.x + delta.x, y: original.y + delta.y)) }
    }
    override func mouseUp(with event: NSEvent) {
        if dragged { moved?() } else { clicked?() }
    }
    override func rightMouseDown(with event: NSEvent) {
        guard let menu = menuProvider?() else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
    override func accessibilityPerformPress() -> Bool { clicked?(); return true }
}
