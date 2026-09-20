import Foundation
import CryptoKit

public enum TraeActivity: String, Codable, Sendable {
    case unavailable, idle, working, waiting
}

/// Only lifecycle fields are decoded. Prompts, tool arguments and workspace paths
/// are never persisted. This adapter targets Trae CN's version 1 hook contract.
public struct TraeHookEvent: Decodable {
    public let session_id: String
    public let hook_event_name: String
    public let notification_type: String?

    public var activity: TraeActivity? {
        switch hook_event_name {
        case "SessionStart": return .idle
        case "UserPromptSubmit", "PreToolUse", "PostToolUse": return .working
        case "Notification":
            switch notification_type {
            case "idle_prompt": return .idle
            case "permission_prompt", "document_review", "ask_user_question", "browser_interaction": return .waiting
            default: return nil
            }
        // Stop runs before completion and another hook may block it.
        default: return nil
        }
    }
}

public struct TraeActivityRecord: Codable {
    public let activity: TraeActivity
    public let updatedAt: Date
}

public enum TraeHookStorage {
    public static var defaultDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Sprout/Trae")
    }
    public static let maximumInputBytes = 1024 * 1024

    public static func consume(_ data: Data, directory: URL = defaultDirectory, now: Date = Date()) throws {
        guard data.count <= maximumInputBytes,
              let event = try? JSONDecoder().decode(TraeHookEvent.self, from: data),
              !event.session_id.isEmpty, event.session_id.utf8.count <= 1024,
              let activity = event.activity else { return }
        let fm = FileManager.default
        try fm.createDirectory(at: directory, withIntermediateDirectories: true,
                               attributes: [.posixPermissions: 0o700])
        let digest = SHA256.hash(data: Data(event.session_id.utf8)).map { String(format: "%02x", $0) }.joined()
        let target = directory.appendingPathComponent(digest + ".json")
        let record = TraeActivityRecord(activity: activity, updatedAt: now)
        try JSONEncoder().encode(record).write(to: target, options: [.atomic])
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: target.path)
        // Remove only our hashed metadata files, never user/Trae files.
        for file in (try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? [] {
            guard isRecord(file), let values = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
                  let modified = values.contentModificationDate, now.timeIntervalSince(modified) > 86400 else { continue }
            try? fm.removeItem(at: file)
        }
    }

    public static func activity(directory: URL = defaultDirectory, now: Date = Date()) -> TraeActivity {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: Array(keys)) else { return .unavailable }
        var result: TraeActivity = .unavailable
        for file in files where isRecord(file) {
            guard let attributes = try? file.resourceValues(forKeys: keys), attributes.isRegularFile == true,
                  attributes.isSymbolicLink != true, (attributes.fileSize ?? Int.max) <= 1024,
                  let data = try? Data(contentsOf: file),
                  let record = try? JSONDecoder().decode(TraeActivityRecord.self, from: data) else { continue }
            let age = now.timeIntervalSince(record.updatedAt)
            guard age >= 0, age < 900 else { continue }
            if record.activity == .working { return .working }
            if record.activity == .waiting { result = .waiting }
            else if record.activity == .idle && result == .unavailable { result = .idle }
        }
        return result
    }

    private static func isRecord(_ file: URL) -> Bool {
        let stem = file.deletingPathExtension().lastPathComponent
        return file.pathExtension == "json" && stem.count == 64 && stem.allSatisfy { "0123456789abcdef".contains($0) }
    }
}

public enum TraeHookConfiguration {
    public static func data(helperPath: String) throws -> Data {
        let command = "'" + helperPath.replacingOccurrences(of: "'", with: "'\\''") + "'"
        let handler: [String: Any] = ["hooks": [["type": "command", "command": command, "timeout": 3]]]
        let events = ["SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse", "Notification"]
        let hooks = Dictionary(uniqueKeysWithValues: events.map { ($0, [handler]) })
        return try JSONSerialization.data(withJSONObject: ["version": 1, "hooks": hooks], options: [.prettyPrinted, .sortedKeys])
    }
}
