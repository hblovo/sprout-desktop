import Foundation

/// Decodes only lifecycle metadata. Message bodies are neither retained nor exposed.
public struct CodexActivity: Sendable {
    public private(set) var activeTurns: Set<String> = []
    public init() {}
    public var isWorking: Bool { !activeTurns.isEmpty }

    public mutating func consume(_ data: Data) {
        struct Event: Decodable {
            struct Payload: Decodable { let type: String; let turn_id: String? }
            let type: String
            let payload: Payload
        }
        // The final partial line may still be being written by Codex.
        let lines = data.split(separator: 10, omittingEmptySubsequences: false)
        for line in lines.dropLast() {
            guard let event = try? JSONDecoder().decode(Event.self, from: Data(line)),
                  event.type == "event_msg", let id = event.payload.turn_id else { continue }
            switch event.payload.type {
            case "task_started": activeTurns.insert(id)
            case "task_complete", "turn_aborted": activeTurns.remove(id)
            default: break
            }
        }
    }
}
