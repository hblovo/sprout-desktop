import Foundation
import Testing
@testable import SproutCore

private func object(_ data: Data) throws -> NSDictionary {
    try #require(JSONSerialization.jsonObject(with: data) as? NSDictionary)
}

@Test func traeConnectPreservesOtherHooksAndIsIdempotent() throws {
    let input = Data(#"{"version":1,"custom":{"enabled":false},"hooks":{"Stop":[{"hooks":[{"command":"echo stop"}]}],"UserPromptSubmit":[{"matcher":"custom","hooks":[{"type":"command","command":"echo keep","timeout":17}]}]}}"#.utf8)
    let first = try TraeConnection.merged(existing: input, helperPath: "/Applications/芽伴.app/Contents/Helpers/SproutHook")
    #expect(try TraeConnection.merged(existing: first, helperPath: "/Applications/芽伴.app/Contents/Helpers/SproutHook") == first)
    let before = try object(input), after = try object(first)
    #expect((after["custom"] as? NSDictionary) == (before["custom"] as? NSDictionary))
    let hooks = try #require(after["hooks"] as? NSDictionary)
    #expect((hooks["Stop"] as? NSArray) == ((before["hooks"] as? NSDictionary)?["Stop"] as? NSArray))
    let groups = try #require(hooks["UserPromptSubmit"] as? [NSDictionary])
    #expect(groups.count == 2)
    #expect(groups[0] == ((before["hooks"] as! NSDictionary)["UserPromptSubmit"] as! [NSDictionary])[0])
    let moved = try TraeConnection.merged(existing: first, helperPath: "/Applications/New.app/Contents/Helpers/SproutHook")
    #expect(!String(decoding: moved, as: UTF8.self).contains("芽伴.app"))
    #expect(String(decoding: moved, as: UTF8.self).contains("echo keep"))
}

@Test func traeConnectBacksUpExactOriginalAndDoesNotRepeatBackup() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let file = directory.appendingPathComponent("hooks.json")
    let original = Data("{ \"hooks\": {} }\n".utf8)
    try original.write(to: file)
    let backup = try #require(try TraeConnection.connect(file: file, helperPath: "/Applications/Sprout.app/Contents/Helpers/SproutHook"))
    #expect(try Data(contentsOf: backup) == original)
    #expect(try TraeConnection.connect(file: file, helperPath: "/Applications/Sprout.app/Contents/Helpers/SproutHook") == nil)
    #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).count == 2)
}

@Test func traeConnectRejectsInvalidConfigWithoutWriting() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let file = directory.appendingPathComponent("hooks.json")
    for json in ["not JSON", "[]", "{\"version\":2}", "{\"hooks\":[]}", "{\"hooks\":{\"PreToolUse\":{}}}"] {
        let input = Data(json.utf8)
        try input.write(to: file)
        #expect(throws: TraeConnectionError.self) { try TraeConnection.connect(file: file, helperPath: "/app/helper") }
        #expect(try Data(contentsOf: file) == input)
    }
    #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).count == 1)
}

@Test func traeConnectCreatesMissingConfigurationAndRejectsSymlink() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let file = directory.appendingPathComponent("cn/hooks.json")
    #expect(try TraeConnection.connect(file: file, helperPath: "/app/helper") == nil)
    let saved = try Data(contentsOf: file)
    let link = directory.appendingPathComponent("hooks.json")
    try FileManager.default.createSymbolicLink(at: link, withDestinationURL: file)
    #expect(throws: TraeConnectionError.self) { try TraeConnection.connect(file: link, helperPath: "/other/helper") }
    #expect(try Data(contentsOf: file) == saved)
}

@Test func traeConnectAdoptsPreviouslyExportedConfiguration() throws {
    let path = "/Applications/芽伴.app/Contents/Helpers/SproutHook"
    let manual = try TraeHookConfiguration.data(helperPath: path)
    let connected = try object(TraeConnection.merged(existing: manual, helperPath: path))
    let hooks = try #require(connected["hooks"] as? [String: [NSDictionary]])
    #expect(hooks.values.allSatisfy { $0.count == 1 })
}
