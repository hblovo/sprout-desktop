import AppKit
import Testing
@testable import SproutApp

@MainActor @Test func bothMascotsShareDueAndCodexState() {
    let store = HealthStore(demo: true, systemIntegration: false)
    store.updatePreferences { $0.quietHoursEnabled = false }
    store.codexAnimationEnabled = true
    store.codexIsWorking = true
    let dashboard = DashboardView(store: store)
    let pet = DesktopPetView(store: store, menu: { NSMenu() }, moved: {})
    #expect(dashboard.presentation == pet.presentation)
    #expect(dashboard.presentation.working)
    store.enginePreviewDue()
    #expect(dashboard.presentation == pet.presentation)
    #expect(dashboard.presentation.happy)
    #expect(!dashboard.presentation.working)
    #expect(dashboard.presentation.caption == "陪你一起，伸个懒腰")
    store.startBreak()
    #expect(dashboard.presentation == pet.presentation)
    #expect(dashboard.presentation.resting)
    #expect(!dashboard.presentation.happy)
    store.togglePause()
    #expect(dashboard.presentation == pet.presentation)
    #expect(!dashboard.presentation.working)
}

@MainActor @Test func traeAnimationRespectsSettingAndHealthPriority() {
    let store = HealthStore(demo: true, systemIntegration: false)
    store.updatePreferences { $0.quietHoursEnabled = false }
    store.codexAnimationEnabled = false
    store.traeAnimationEnabled = false
    store.traeActivity = .working
    #expect(!store.mascotPresentation.working)
    store.traeAnimationEnabled = true
    #expect(store.mascotPresentation.working)
    #expect(store.mascotPresentation.caption.contains("Trae 工作中"))
    store.traeActivity = .waiting
    #expect(!store.mascotPresentation.working)
    #expect(store.mascotPresentation.caption.contains("等待确认"))
    store.traeActivity = .working
    store.codexAnimationEnabled = true
    store.codexIsWorking = true
    #expect(store.mascotPresentation.caption.contains("Codex + Trae"))
    store.enginePreviewDue()
    #expect(store.mascotPresentation.happy)
    #expect(!store.mascotPresentation.working)
    store.startBreak()
    #expect(store.mascotPresentation.resting)
    #expect(!store.mascotPresentation.working)
}
