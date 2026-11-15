import SwiftUI

/// Anatomical names match tools/muscle-icons/reference_artwork.py and the shared tag icons.
enum MuscleBodySide: String, CaseIterable {
    case front, back

    var regions: [String] {
        switch self {
        case .front:
            ["chest", "obliques", "abs", "biceps", "triceps", "neck", "trapezius", "deltoids",
             "adductors", "quadriceps", "tibialis", "calves", "forearm"]
        case .back:
            ["neck", "trapezius", "deltoids", "upper-back", "lats", "triceps", "lower-back", "forearm",
             "gluteal-lateral", "gluteal-medial", "adductors", "hamstring", "calves"]
        }
    }

    func asset(_ region: String) -> String { "body-\(rawValue)-\(region)" }

    var columnCenter: CGFloat { self == .front ? 0.25 : 0.75 }
}

/// Shares the same layout between the chart and its loading placeholder.
enum MuscleBodyLayout {
    static let height: CGFloat = 280

    static func frame(for side: MuscleBodySide, in size: CGSize) -> CGRect {
        let height = min(Self.height, size.width, size.height)
        let center = size.width * side.columnCenter
        return CGRect(x: center - height / 4, y: (size.height - height) / 2,
                      width: height / 2, height: height)
    }
}

enum MuscleBodyAnatomy {
    static func regions(for icon: MuscleIcon, on side: MuscleBodySide) -> [String] {
        let names: [String]
        switch icon {
        case .fullBody: names = side.regions
        case .upperBody:
            names = ["chest", "obliques", "abs", "biceps", "triceps", "neck", "trapezius", "deltoids", "upper-back", "lats", "lower-back", "forearm"]
        case .lowerBody:
            names = ["quadriceps", "adductors", "calves", "tibialis", "hamstring", "gluteal-lateral", "gluteal-medial"]
        case .arms: names = ["biceps", "triceps", "forearm"]
        case .core: names = ["abs", "obliques"]
        case .chest, .upperChest, .middleChest, .lowerChest: names = ["chest"]
        case .back: names = side == .back ? ["upper-back", "lats", "lower-back", "trapezius"] : []
        case .shoulders: names = ["deltoids"]
        case .anteriorDeltoid: names = side == .front ? ["deltoids"] : []
        case .lateralDeltoid: names = ["deltoids"]
        case .posteriorDeltoid: names = side == .back ? ["deltoids"] : []
        case .biceps, .bicepsLongHead, .bicepsShortHead: names = ["biceps"]
        case .triceps: names = ["triceps"]
        case .tricepsLongHead, .tricepsLateralHead, .tricepsMedialHead: names = side == .back ? ["triceps"] : []
        case .forearms: names = ["forearm"]
        case .forearmFlexors, .brachioradialis: names = side == .front ? ["forearm"] : []
        case .forearmExtensors: names = side == .back ? ["forearm"] : []
        case .trapezius: names = ["trapezius"]
        case .lats: names = side == .back ? ["lats"] : []
        case .upperBack: names = ["upper-back", "trapezius"]
        case .lowerBack: names = ["lower-back"]
        case .abdominals: names = ["abs"]
        case .obliques, .externalObliques, .internalObliques, .transverseAbdominis: names = ["obliques"]
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
}

struct WeeklyMuscleActivity {
    typealias Entry = WeeklyTagDistribution.Entry
    let entries: [Entry]
    private let regionEntries: [MuscleBodySide: [String: [Entry]]]

    init(summary: WeeklySummary) {
        self.init(distribution: WeeklyTagDistribution(summary: summary))
    }

    init(distribution: WeeklyTagDistribution) {
        entries = distribution.entries
        var regions: [MuscleBodySide: [String: [Entry]]] = [:]
        for entry in entries {
            guard let icon = entry.icon else { continue }
            for side in MuscleBodySide.allCases {
                for region in MuscleBodyAnatomy.regions(for: icon, on: side) {
                    regions[side, default: [:]][region, default: []].append(entry)
                }
            }
        }
        regionEntries = regions
    }

    func entries(for region: String, on side: MuscleBodySide) -> [Entry] {
        regionEntries[side]?[region] ?? []
    }
}
