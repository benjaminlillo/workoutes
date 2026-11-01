import SwiftUI

/// Anatomical names match tools/muscle-icons/body-paths.json and the existing tag icons.
enum MuscleBodySide: String, CaseIterable {
    case front, back

    var regions: [String] {
        switch self {
        case .front:
            ["chest", "obliques", "abs", "biceps", "triceps", "neck", "trapezius", "deltoids",
             "adductors", "quadriceps", "tibialis", "calves", "forearm"]
        case .back:
            ["neck", "trapezius", "deltoids", "upper-back", "triceps", "lower-back", "forearm",
             "gluteal-lateral", "gluteal-medial", "adductors", "hamstring", "calves"]
        }
    }

    func asset(_ region: String) -> String { "body-\(rawValue)-\(region)" }
}

struct MuscleBodyAnchor {
    let side: MuscleBodySide
    /// Original body coordinates, normalized to the common 724 × 1448 canvas.
    let point: CGPoint

    init(_ x: CGFloat, _ y: CGFloat, side: MuscleBodySide = .front) {
        self.side = side
        point = CGPoint(x: x / 724, y: y / 1448)
    }
}

enum MuscleBodyAnatomy {
    static func regions(for icon: MuscleIcon, on side: MuscleBodySide) -> [String] {
        let names: [String]
        switch icon {
        case .fullBody: names = side.regions
        case .upperBody:
            names = ["chest", "obliques", "abs", "biceps", "triceps", "neck", "trapezius", "deltoids", "upper-back", "lower-back", "forearm"]
        case .lowerBody:
            names = ["quadriceps", "adductors", "calves", "tibialis", "hamstring", "gluteal-lateral", "gluteal-medial"]
        case .arms: names = ["biceps", "triceps", "forearm"]
        case .core: names = ["abs", "obliques"]
        case .chest: names = ["chest"]
        case .back: names = side == .back ? ["upper-back", "lower-back", "trapezius"] : []
        case .shoulders: names = ["deltoids"]
        case .biceps: names = ["biceps"]
        case .triceps: names = ["triceps"]
        case .forearms: names = ["forearm"]
        case .trapezius: names = ["trapezius"]
        case .upperBack: names = ["upper-back"]
        case .lowerBack: names = ["lower-back"]
        case .abdominals: names = ["abs"]
        case .obliques: names = ["obliques"]
        case .neck: names = ["neck"]
        case .glutes: names = ["gluteal-lateral", "gluteal-medial"]
        case .quadriceps: names = ["quadriceps"]
        case .hamstrings: names = ["hamstring"]
        case .calves: names = ["calves"]
        case .adductors: names = ["adductors"]
        case .abductors: names = ["gluteal-lateral"]
        case .tibialis: names = ["tibialis"]
        }
        return side.regions.filter { names.contains($0) }
    }

    static func anchor(for icon: MuscleIcon) -> MuscleBodyAnchor {
        switch icon {
        case .fullBody: MuscleBodyAnchor(350, 570)
        case .upperBody, .chest: MuscleBodyAnchor(310, 380)
        case .lowerBody, .quadriceps: MuscleBodyAnchor(300, 850)
        case .arms, .biceps: MuscleBodyAnchor(235, 450)
        case .core, .abdominals: MuscleBodyAnchor(350, 520)
        case .back, .upperBack: MuscleBodyAnchor(350, 430, side: .back)
        case .shoulders: MuscleBodyAnchor(220, 320)
        case .triceps: MuscleBodyAnchor(520, 450, side: .back)
        case .forearms: MuscleBodyAnchor(165, 600)
        case .trapezius: MuscleBodyAnchor(365, 310, side: .back)
        case .lowerBack: MuscleBodyAnchor(365, 550, side: .back)
        case .obliques: MuscleBodyAnchor(285, 515)
        case .neck: MuscleBodyAnchor(335, 275)
        case .glutes: MuscleBodyAnchor(405, 690, side: .back)
        case .hamstrings: MuscleBodyAnchor(425, 850, side: .back)
        case .calves: MuscleBodyAnchor(425, 1110, side: .back)
        case .adductors: MuscleBodyAnchor(330, 760)
        case .abductors: MuscleBodyAnchor(460, 655, side: .back)
        case .tibialis: MuscleBodyAnchor(295, 1110)
        }
    }
}

struct WeeklyMuscleActivity {
    typealias Entry = WeeklyTagDistribution.Entry
    let entries: [Entry]

    init(summary: WeeklySummary) {
        entries = WeeklyTagDistribution(summary: summary).entries
    }

    func entries(for region: String, on side: MuscleBodySide) -> [Entry] {
        entries.filter { entry in
            guard let icon = entry.icon else { return false }
            return MuscleBodyAnatomy.regions(for: icon, on: side).contains(region)
        }
    }

    func callouts(on side: MuscleBodySide) -> [Entry] {
        entries.enumerated().filter { _, entry in
            entry.icon.map { MuscleBodyAnatomy.anchor(for: $0).side == side } ?? false
        }.sorted {
            let lhs = MuscleBodyAnatomy.anchor(for: $0.element.icon!).point.y
            let rhs = MuscleBodyAnatomy.anchor(for: $1.element.icon!).point.y
            return lhs == rhs ? $0.offset < $1.offset : lhs < rhs
        }.map(\.element)
    }
}

/// Moves crowded labels apart while preserving their anatomical order.
enum MuscleCalloutLayout {
    static func positions(targets: [CGFloat], height: CGFloat, spacing: CGFloat) -> [CGFloat] {
        guard !targets.isEmpty else { return [] }
        let lower = spacing / 2
        let upper = height - lower
        var positions: [CGFloat] = []
        for target in targets {
            positions.append(max(lower, min(upper, target), (positions.last ?? (lower - spacing)) + spacing))
        }
        if let last = positions.last, last > upper {
            positions[positions.count - 1] = upper
            for index in positions.indices.dropLast().reversed() {
                positions[index] = min(positions[index], positions[index + 1] - spacing)
            }
        }
        return positions
    }
}
