import Foundation
import SwiftData

/// Counts the same current catalog tags used by the weekly exercise blocks.
/// Each completion contributes once to every distinct tag, or once to No Tags.
struct WeeklyTagDistribution {
    enum Category: Hashable {
        case tag(PersistentIdentifier)
        case untagged
    }

    struct Entry: Identifiable {
        let id: Category
        let name: String
        let colorHex: String?
        var count: Int
    }

    let entries: [Entry]
    let total: Int

    init(summary: WeeklySummary) {
        var entries: [Entry] = []
        var positions: [Category: Int] = [:]
        func count(_ id: Category, name: String, colorHex: String?) {
            if let position = positions[id] {
                entries[position].count += 1
            } else {
                positions[id] = entries.count
                entries.append(Entry(id: id, name: name, colorHex: colorHex, count: 1))
            }
        }

        for completion in summary.days.flatMap(\.completions) {
            let tags = completion.exercise?.tags ?? []
            if tags.isEmpty {
                count(.untagged, name: String(localized: "No Tags"), colorHex: nil)
            } else {
                var seen: Set<PersistentIdentifier> = []
                for tag in tags where seen.insert(tag.persistentModelID).inserted {
                    count(.tag(tag.persistentModelID), name: tag.name, colorHex: tag.colorHex)
                }
            }
        }
        self.entries = entries.enumerated().sorted {
            if $0.element.count != $1.element.count { return $0.element.count > $1.element.count }
            let comparison = $0.element.name.localizedStandardCompare($1.element.name)
            return comparison == .orderedSame ? $0.offset < $1.offset : comparison == .orderedAscending
        }.map(\.element)
        total = entries.reduce(0) { $0 + $1.count }
    }

    func fraction(for entry: Entry) -> Double {
        total == 0 ? 0 : Double(entry.count) / Double(total)
    }
}
