import Foundation
import Testing
@testable import SproutCore

private func event(_ type: String, _ id: String) -> Data {
    Data("{\"type\":\"event_msg\",\"payload\":{\"type\":\"\(type)\",\"turn_id\":\"\(id)\"}}\n".utf8)
}
@Test func codexMultipleTasksFinishIndependently() {
    var state = CodexActivity()
    state.consume(event("task_started", "a") + event("task_started", "b"))
    state.consume(event("task_complete", "a"))
    #expect(state.isWorking)
    state.consume(event("turn_aborted", "b"))
    #expect(!state.isWorking)
}
@Test func codexIgnoresPartialAndUnrelatedEvents() {
    var state = CodexActivity()
    state.consume(Data("not json\n".utf8) + event("agent_message", "a"))
    state.consume(event("task_started", "a").dropLast())
    #expect(!state.isWorking)
    state.consume(event("task_started", "a"))
    state.consume(event("task_complete", "other"))
    #expect(state.isWorking)
    state.consume(event("task_complete", "a"))
    #expect(!state.isWorking)
}
