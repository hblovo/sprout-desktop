import Foundation
import Testing
@testable import SproutApp

private func joycodeEvent(_ type: String, turn: String = "turn-a") -> Data {
    // Synthetic fixture: only the lifecycle envelope mirrors JoyCode Beta 0.2.4.
    Data("{\"timestamp\":\"2026-09-29T12:00:00Z\",\"type\":\"event_msg\",\"payload\":{\"type\":\"\(type)\",\"turn_id\":\"\(turn)\"}}\n".utf8)
}

private func temporarySessions() throws -> URL {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    return root
}

@Test func joycodeAndCodexUseIndependentDirectoriesAndProcesses() async throws {
    let home = try temporarySessions()
    defer { try? FileManager.default.removeItem(at: home) }
    let joycodeRoot = LocalAgent.joycodeBeta.sessionsDirectory(home: home)
    let codexRoot = LocalAgent.codex.sessionsDirectory(home: home)
    #expect(joycodeRoot.path == home.appendingPathComponent(".joycode/sessions").path)
    #expect(codexRoot.path == home.appendingPathComponent(".codex/sessions").path)
    try FileManager.default.createDirectory(at: joycodeRoot, withIntermediateDirectories: true)
    let file = joycodeRoot.appendingPathComponent("session.jsonl")
    try joycodeEvent("task_started").write(to: file)
    let joycode = LocalAgentSessionReader(agent: .joycodeBeta, root: joycodeRoot)
    let codex = LocalAgentSessionReader(agent: .codex, root: codexRoot)
    let running: Set<String> = ["com.openai.codex", "com.joycode.cli"]
    #expect(await joycode.working(enabled: true, runningBundleIdentifiers: running))
    #expect(await !codex.working(enabled: true, runningBundleIdentifiers: running))
    #expect(await !joycode.working(enabled: false, runningBundleIdentifiers: running))
    #expect(await !joycode.working(enabled: true, runningBundleIdentifiers: []))
    // The stable editor and Codex must not enable Beta's detector.
    #expect(await !joycode.working(enabled: true, runningBundleIdentifiers: ["com.joycodereditor.code", "com.openai.codex"]))
    #expect(await joycode.working(enabled: true, runningBundleIdentifiers: running))
}

@Test func joycodeSessionsCompleteAndAbortIndependently() async throws {
    let root = try temporarySessions()
    defer { try? FileManager.default.removeItem(at: root) }
    let reader = LocalAgentSessionReader(agent: .joycodeBeta, root: root)
    let a = root.appendingPathComponent("a.jsonl")
    let b = root.appendingPathComponent("b.jsonl")
    #expect(await !reader.working())
    try joycodeEvent("task_started").write(to: a)
    try joycodeEvent("task_started", turn: "turn-b").write(to: b)
    #expect(await reader.working())
    try (joycodeEvent("task_started") + joycodeEvent("task_complete")).write(to: a)
    #expect(await reader.working())
    try (joycodeEvent("task_started", turn: "turn-b") + joycodeEvent("turn_aborted", turn: "turn-b")).write(to: b)
    #expect(await !reader.working())
    try joycodeEvent("task_started", turn: "turn-c").write(to: a)
    #expect(await reader.working())
    try FileManager.default.removeItem(at: a)
    #expect(await !reader.working())
}

@Test func joycodePartialWritesTruncationAndInvalidRecordsRecover() async throws {
    let root = try temporarySessions()
    defer { try? FileManager.default.removeItem(at: root) }
    let reader = LocalAgentSessionReader(agent: .joycodeBeta, root: root)
    let file = root.appendingPathComponent("session.jsonl")
    let unrelated = Data("bad json\n{\"type\":\"response_item\",\"payload\":{\"type\":\"task_started\",\"turn_id\":\"wrong\"}}\n".utf8)
    try unrelated.write(to: file)
    #expect(await !reader.working())
    let started = joycodeEvent("task_started")
    let completed = joycodeEvent("task_complete")
    try (started + completed.dropLast()).write(to: file)
    #expect(await reader.working())
    try (started + completed).write(to: file)
    #expect(await !reader.working())
    try started.write(to: file)
    #expect(await reader.working())
    try Data("broken\n".utf8).write(to: file)
    #expect(await !reader.working())
}

@Test func joycodeRejectsStaleFutureAndSymbolicLinkFiles() async throws {
    let root = try temporarySessions()
    defer { try? FileManager.default.removeItem(at: root) }
    let reader = LocalAgentSessionReader(agent: .joycodeBeta, root: root)
    let file = root.appendingPathComponent("session.jsonl")
    try joycodeEvent("task_started").write(to: file)
    let modified = try #require(try file.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
    #expect(await reader.working(now: modified.addingTimeInterval(899)))
    #expect(await !reader.working(now: modified.addingTimeInterval(900)))
    #expect(await !reader.working(now: modified.addingTimeInterval(-1)))
    let target = root.appendingPathComponent("session.txt")
    try FileManager.default.moveItem(at: file, to: target)
    try FileManager.default.createSymbolicLink(at: file, withDestinationURL: target)
    #expect(await !reader.working())
}

@Test func joycodeLongRunningSessionKeepsStateUntilCompletion() async throws {
    let root = try temporarySessions()
    defer { try? FileManager.default.removeItem(at: root) }
    let reader = LocalAgentSessionReader(agent: .joycodeBeta, root: root)
    let file = root.appendingPathComponent("session.jsonl")
    let started = joycodeEvent("task_started")
    try started.write(to: file)
    #expect(await reader.working())
    let filler = Data((String(repeating: " ", count: 2 * 1024 * 1024) + "\n").utf8)
    try (started + filler).write(to: file)
    #expect(await reader.working())
    try (started + filler + joycodeEvent("task_complete")).write(to: file)
    #expect(await !reader.working())
}
