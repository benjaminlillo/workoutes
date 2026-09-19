import ActivityKit
import Foundation

nonisolated struct SessionActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var sessionID: String
        var blockID: String
        var blockName: String
        var blockKind: SessionBlockKindValue
        var blockStartedAt: Date
        var sessionStartedAt: Date
        var restEndsAt: Date?
        var currentIndex: Int
        var totalBlocks: Int
        var isLastBlock: Bool
        var accentColorHex: String
        var ended: Bool = false
    }
}

nonisolated enum SessionBlockKindValue: String, Codable, Hashable {
    case exercise
    case rest
}
