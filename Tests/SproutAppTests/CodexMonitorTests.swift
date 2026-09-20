import Foundation
import Testing
@testable import SproutApp

@Test func codexReaderHandlesCompletionAndStaleFiles() async throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    let file = root.appendingPathComponent("session.jsonl")
    let started = "{\"type\":\"event_msg\",\"payload\":{\"type\":\"task_started\",\"turn_id\":\"a\"}}\n"
    let finished = "{\"type\":\"event_msg\",\"payload\":{\"type\":\"task_complete\",\"turn_id\":\"a\"}}\n"
    let reader = CodexSessionReader(root: root)
    #expect(await !reader.working())
    try Data(started.utf8).write(to: file)
    #expect(await reader.working())
    try Data((started + finished).utf8).write(to: file)
    #expect(await !reader.working())
    try Data(started.utf8).write(to: file)
    #expect(await reader.working())
    #expect(await !reader.working(now: Date().addingTimeInterval(901)))
}
