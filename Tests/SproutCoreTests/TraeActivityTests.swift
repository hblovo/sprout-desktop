import Foundation
import Testing
@testable import SproutCore

private func traeEvent(_ event: String, session: String = "a", notification: String? = nil) throws -> Data {
    var json: [String: String] = ["session_id": session, "hook_event_name": event,
                                "prompt": "SECRET PROMPT", "cwd": "/private/project"]
    json["notification_type"] = notification
    return try JSONSerialization.data(withJSONObject: json)
}

@Test func traeSessionsAndWaitingAreIndependent() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let now = Date()
    #expect(TraeHookStorage.activity(directory: directory, now: now) == .unavailable)
    try TraeHookStorage.consume(traeEvent("UserPromptSubmit"), directory: directory, now: now)
    try TraeHookStorage.consume(traeEvent("PreToolUse", session: "b"), directory: directory, now: now)
    try TraeHookStorage.consume(traeEvent("Notification", notification: "idle_prompt"), directory: directory, now: now)
    #expect(TraeHookStorage.activity(directory: directory, now: now) == .working)
    try TraeHookStorage.consume(traeEvent("Notification", session: "b", notification: "permission_prompt"), directory: directory, now: now)
    #expect(TraeHookStorage.activity(directory: directory, now: now) == .waiting)
    try TraeHookStorage.consume(traeEvent("PostToolUse", session: "b"), directory: directory, now: now)
    #expect(TraeHookStorage.activity(directory: directory, now: now) == .working)
    try TraeHookStorage.consume(traeEvent("Stop", session: "b"), directory: directory, now: now)
    #expect(TraeHookStorage.activity(directory: directory, now: now) == .working)
    try TraeHookStorage.consume(traeEvent("Notification", session: "b", notification: "idle_prompt"), directory: directory, now: now)
    #expect(TraeHookStorage.activity(directory: directory, now: now) == .idle)
}

@Test func traeExpiresAndRejectsFutureAndMalformedEvents() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let now = Date()
    for data in [Data("bad".utf8), try traeEvent("unknown"), try traeEvent("Notification", notification: "unknown"),
                 try traeEvent("UserPromptSubmit", session: ""), Data(repeating: 32, count: 1048577)] {
        try TraeHookStorage.consume(data, directory: directory, now: now)
    }
    #expect(!FileManager.default.fileExists(atPath: directory.path))
    try TraeHookStorage.consume(traeEvent("UserPromptSubmit"), directory: directory, now: now)
    #expect(TraeHookStorage.activity(directory: directory, now: now.addingTimeInterval(899)) == .working)
    #expect(TraeHookStorage.activity(directory: directory, now: now.addingTimeInterval(900)) == .unavailable)
    #expect(TraeHookStorage.activity(directory: directory, now: now.addingTimeInterval(-1)) == .unavailable)
}

@Test func traePersistsOnlySanitizedMetadata() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try TraeHookStorage.consume(traeEvent("UserPromptSubmit", session: "../../sensitive-session"), directory: directory)
    let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
    #expect(files.count == 1)
    #expect(files[0].deletingPathExtension().lastPathComponent.count == 64)
    let object = try #require(JSONSerialization.jsonObject(with: Data(contentsOf: files[0])) as? [String: Any])
    #expect(Set(object.keys) == Set(["activity", "updatedAt"]))
    let attributes = try FileManager.default.attributesOfItem(atPath: files[0].path)
    #expect((attributes[.posixPermissions] as? NSNumber)?.intValue == 0o600)
}

@Test func traeAllWaitingNotificationsAndSessionStart() throws {
    for notification in ["permission_prompt", "document_review", "ask_user_question", "browser_interaction"] {
        let event = try JSONDecoder().decode(TraeHookEvent.self, from: traeEvent("Notification", notification: notification))
        #expect(event.activity == .waiting)
    }
    let start = try JSONDecoder().decode(TraeHookEvent.self, from: traeEvent("SessionStart"))
    #expect(start.activity == .idle)
}

@Test func traeConfigurationQuotesExecutableAndAvoidsStop() throws {
    let data = try TraeHookConfiguration.data(helperPath: "/Applications/a'b 芽伴.app/Contents/Helpers/SproutHook")
    let config = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    #expect(config["version"] as? Int == 1)
    let hooks = try #require(config["hooks"] as? [String: [[String: Any]]])
    #expect(Set(hooks.keys) == Set(["SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse", "Notification"]))
    let command = try #require((hooks["UserPromptSubmit"]?.first?["hooks"] as? [[String: Any]])?.first?["command"] as? String)
    #expect(command == "'/Applications/a'\\''b 芽伴.app/Contents/Helpers/SproutHook'")
}
