import Foundation
import SproutCore

// Silent, fail-open side effect: never block or inject context into Trae.
// Read stdin incrementally; large tool responses are ignored rather than stored.
let directory: URL
if CommandLine.arguments.count == 3 && CommandLine.arguments[1] == "--state-dir" {
    directory = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
} else if CommandLine.arguments.count == 1 {
    directory = TraeHookStorage.defaultDirectory
} else {
    exit(0)
}
do {
    var input = Data()
    while let chunk = try FileHandle.standardInput.read(upToCount: 65536), !chunk.isEmpty {
        input.append(chunk)
        if input.count > TraeHookStorage.maximumInputBytes { exit(0) }
    }
    try TraeHookStorage.consume(input, directory: directory)
} catch { /* Hooks must not affect the agent on malformed input or I/O failure. */ }
