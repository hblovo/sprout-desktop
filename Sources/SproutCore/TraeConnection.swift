import Foundation

public enum TraeConnectionError: Error, LocalizedError {
    case invalidConfiguration, changedConfiguration, symbolicLink
    public var errorDescription: String? {
        switch self {
        case .invalidConfiguration: return "Trae 配置格式无法识别，未修改原文件。请使用手动导出配置。"
        case .changedConfiguration: return "Trae 配置正在被其他程序修改，请稍后重试。"
        case .symbolicLink: return "Trae 配置使用了符号链接，请使用手动导出配置。"
        }
    }
}

public enum TraeConnection {
    private static let marker = " # sprout-desktop-hook-v1"

    /// Pure merge: keep unrelated settings, groups and commands. Only replace our
    /// explicitly marked commands, including commands pointing to an old app path.
    public static func merged(existing: Data?, helperPath: String) throws -> Data {
        var root: [String: Any]
        if let existing {
            guard existing.count <= 1024 * 1024,
                  let parsed = try? JSONSerialization.jsonObject(with: existing) as? [String: Any] else {
                throw TraeConnectionError.invalidConfiguration
            }
            root = parsed
        } else { root = ["version": 1] }
        if let version = root["version"], String(describing: version) != "1" {
            throw TraeConnectionError.invalidConfiguration
        }
        var hooks: [String: Any] = [:]
        if let value = root["hooks"] {
            guard let dictionary = value as? [String: Any] else { throw TraeConnectionError.invalidConfiguration }
            hooks = dictionary
        }
        let generated = try JSONSerialization.jsonObject(with: TraeHookConfiguration.data(helperPath: helperPath)) as! [String: Any]
        let additions = generated["hooks"] as! [String: [[String: Any]]]
        for (event, entry) in additions {
            let currentCommand = ((entry[0]["hooks"] as! [[String: Any]])[0]["command"] as! String)
            var groups: [[String: Any]] = []
            if let value = hooks[event] {
                guard let parsed = value as? [[String: Any]] else { throw TraeConnectionError.invalidConfiguration }
                for var group in parsed {
                    guard let handlers = group["hooks"] as? [[String: Any]] else { throw TraeConnectionError.invalidConfiguration }
                    let retained = handlers.filter { handler in
                        guard let command = handler["command"] as? String else { return true }
                        return !command.hasSuffix(marker) && command != currentCommand
                    }
                    if retained.count == handlers.count { groups.append(group) }
                    else if !retained.isEmpty { group["hooks"] = retained; groups.append(group) }
                }
            }
            var handler = (entry[0]["hooks"] as! [[String: Any]])[0]
            handler["command"] = (handler["command"] as! String) + marker
            groups.append(["hooks": [handler]])
            hooks[event] = groups
        }
        root["hooks"] = hooks
        return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
    }

    /// Returns a backup URL only when an existing file is changed. Never touches
    /// Trae's enablement/permission settings. Identical reconnects are a no-op.
    @discardableResult public static func connect(file: URL, helperPath: String) throws -> URL? {
        let fm = FileManager.default
        let values = try? file.resourceValues(forKeys: [.isSymbolicLinkKey])
        if values?.isSymbolicLink == true { throw TraeConnectionError.symbolicLink }
        let exists = fm.fileExists(atPath: file.path)
        let original = exists ? try Data(contentsOf: file) : nil
        let output = try merged(existing: original, helperPath: helperPath)
        if original == output { return nil }
        try fm.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        var backup: URL?
        if let original {
            let target = file.deletingLastPathComponent().appendingPathComponent("hooks.sprout-backup-\(UUID().uuidString).json")
            try original.write(to: target, options: .withoutOverwriting)
            try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: target.path)
            backup = target
        }
        // Detect edits that happened during merge/backup before atomic replacement.
        let latest = fm.fileExists(atPath: file.path) ? try Data(contentsOf: file) : nil
        guard latest == original else { throw TraeConnectionError.changedConfiguration }
        if (try? file.resourceValues(forKeys: [.isSymbolicLinkKey]))?.isSymbolicLink == true {
            throw TraeConnectionError.symbolicLink
        }
        try output.write(to: file, options: .atomic)
        try fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        return backup
    }
}
