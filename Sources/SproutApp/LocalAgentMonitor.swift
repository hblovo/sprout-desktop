import Foundation
import SproutCore

/// Only clients verified to use the Codex rollout lifecycle format belong here.
enum LocalAgent: CaseIterable, Sendable {
    case codex, joycodeBeta

    var bundleIdentifier: String {
        switch self {
        case .codex: return "com.openai.codex"
        case .joycodeBeta: return "com.joycode.cli"
        }
    }

    func sessionsDirectory(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL {
        switch self {
        case .codex: return home.appendingPathComponent(".codex/sessions")
        case .joycodeBeta: return home.appendingPathComponent(".joycode/sessions")
        }
    }
}

/// Compatibility adapter for local rollout files, not a public desktop API.
actor LocalAgentSessionReader {
    private struct Cached {
        var modified: Date
        var size: Int
        var activity: CodexActivity
    }
    private var cache: [URL: Cached] = [:]
    private let agent: LocalAgent
    private let root: URL
    init(agent: LocalAgent, root: URL? = nil) {
        self.agent = agent
        self.root = root ?? agent.sessionsDirectory()
    }

    func working(enabled: Bool, runningBundleIdentifiers: Set<String>, now: Date = Date()) -> Bool {
        guard enabled, runningBundleIdentifiers.contains(agent.bundleIdentifier) else {
            cache.removeAll()
            return false
        }
        return working(now: now)
    }

    func working(now: Date = Date()) -> Bool {
        let keys: [URLResourceKey] = [.contentModificationDateKey, .fileSizeKey, .isRegularFileKey, .isSymbolicLinkKey]
        guard let files = FileManager.default.enumerator(at: root, includingPropertiesForKeys: keys,
                                                       options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
            cache.removeAll(); return false
        }
        var candidates: [(URL, Date, Int)] = []
        for case let url as URL in files where url.pathExtension == "jsonl" {
            guard let values = try? url.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true, values.isSymbolicLink != true,
                  let modified = values.contentModificationDate,
                  now.timeIntervalSince(modified) >= 0,
                  now.timeIntervalSince(modified) < 900 else { continue }
            candidates.append((url, modified, values.fileSize ?? 0))
        }
        let recent = candidates.sorted { $0.1 > $1.1 }.prefix(32)
        let retained = Set(recent.map { $0.0 })
        cache = cache.filter { retained.contains($0.key) }
        for (url, modified, size) in recent {
            if let old = cache[url], old.modified == modified && old.size == size { continue }
            guard let handle = try? FileHandle(forReadingFrom: url) else { cache[url] = nil; continue }
            defer { try? handle.close() }
            // Bound reads for large sessions. Keep previous lifecycle state when the start
            // marker has left the tail; a completion still clears the matching turn.
            let offset = max(0, size - 2 * 1024 * 1024)
            do {
                try handle.seek(toOffset: UInt64(offset))
                var data = try handle.read(upToCount: 2 * 1024 * 1024) ?? Data()
                if offset > 0, let newline = data.firstIndex(of: 10) { data.removeSubrange(...newline) }
                var state = size >= (cache[url]?.size ?? 0) ? (cache[url]?.activity ?? CodexActivity()) : CodexActivity()
                state.consume(data)
                cache[url] = Cached(modified: modified, size: size, activity: state)
            } catch { cache[url] = nil }
        }
        return cache.values.contains { $0.activity.isWorking }
    }
}
