import Foundation

struct MascotPresentation: Equatable {
    var resting = false
    var happy = false
    var working = false
    var caption: String
}

extension HealthStore {
    var mascotPresentation: MascotPresentation {
        if systemSuspended || idleAway {
            return MascotPresentation(resting: true, caption: "小芽 · \(statusText)")
        }
        if let candidate = pendingBreak {
            return MascotPresentation(caption: candidate.focusRestarted == true ? "专注中 · \(engine.displayTime)" : "一点照顾，让小芽知道")
        }
        if remindersMuted {
            return MascotPresentation(resting: true, caption: "小芽 · \(statusText)")
        }
        switch engine.phase {
        case .resting:
            return MascotPresentation(resting: true, caption: "呼吸一下 · \(engine.displayTime)")
        case .due:
            return MascotPresentation(happy: true, caption: "陪你一起，伸个懒腰")
        case .focus:
            if waterNudge { return MascotPresentation(caption: "忙碌间隙，也记得喝口水") }
            if codexAnimationEnabled && codexIsWorking {
                return MascotPresentation(working: true, caption: "Codex 工作中 · \(engine.displayTime) 后活动")
            }
            return MascotPresentation(caption: "小芽 · \(engine.displayTime) 后动一动")
        }
    }
}
