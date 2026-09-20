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
