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

    var columnCenter: CGFloat { self == .front ? 0.285 : 0.715 }
}

/// Keep the original artwork proportions, with room for the count badges outside the hands.
enum MuscleBodyLayout {
    static func frame(for side: MuscleBodySide, in size: CGSize) -> CGRect {
        let height = min(320, size.width * 0.74, size.height)
        let center = size.width * side.columnCenter
        return CGRect(x: center - height / 4, y: (size.height - height) / 2,
                      width: height / 2, height: height)
    }
}

struct MuscleBodyLabels: View {
    var body: some View {
        MuscleBodyLabelsLayout {
            Text("Front")
            Text("Back")
        }
        .font(.caption).foregroundStyle(.secondary)
    }
}

private struct MuscleBodyLabelsLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        CGSize(width: proposal.width ?? 330,
               height: subviews.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for (side, subview) in zip(MuscleBodySide.allCases, subviews) {
            subview.place(at: CGPoint(x: bounds.minX + bounds.width * side.columnCenter, y: bounds.midY),
                          anchor: .center, proposal: .unspecified)
        }
    }
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
            names = ["chest", "obliques", "abs", "biceps", "triceps", "neck", "trapezius", "deltoids", "upper-back", "lats", "lower-back", "forearm"]
        case .lowerBody:
            names = ["quadriceps", "adductors", "calves", "tibialis", "hamstring", "gluteal-lateral", "gluteal-medial"]
        case .arms: names = ["biceps", "triceps", "forearm"]
        case .core: names = ["abs", "obliques"]
        case .chest: names = ["chest"]
        case .back: names = side == .back ? ["upper-back", "lats", "lower-back", "trapezius"] : []
        case .shoulders: names = ["deltoids"]
        case .biceps: names = ["biceps"]
        case .triceps: names = ["triceps"]
        case .forearms: names = ["forearm"]
        case .trapezius: names = ["trapezius"]
        case .upperBack: names = ["upper-back", "trapezius"]
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
        case .fullBody, .core, .abdominals: MuscleBodyAnchor(335, 627)
        case .upperBody, .chest: MuscleBodyAnchor(305, 337)
        case .lowerBody, .quadriceps: MuscleBodyAnchor(302, 842)
        case .arms, .biceps: MuscleBodyAnchor(190, 431)
        case .back: MuscleBodyAnchor(429, 464, side: .back)
        case .upperBack: MuscleBodyAnchor(436, 321, side: .back)
        case .shoulders: MuscleBodyAnchor(216, 305)
        case .triceps: MuscleBodyAnchor(543, 431, side: .back)
        case .forearms: MuscleBodyAnchor(153, 597)
        case .trapezius: MuscleBodyAnchor(382, 354, side: .back)
        case .lowerBack: MuscleBodyAnchor(454, 571, side: .back)
        case .obliques: MuscleBodyAnchor(277, 538)
        case .neck: MuscleBodyAnchor(370, 237)
        case .glutes: MuscleBodyAnchor(415, 706, side: .back)
        case .hamstrings: MuscleBodyAnchor(438, 879, side: .back)
        case .calves: MuscleBodyAnchor(471, 1115, side: .back)
        case .adductors: MuscleBodyAnchor(328, 758)
        case .abductors: MuscleBodyAnchor(471, 709, side: .back)
        case .tibialis: MuscleBodyAnchor(258, 1129)
        }
    }
}

struct WeeklyMuscleActivity {
    typealias Entry = WeeklyTagDistribution.Entry
    let entries: [Entry]
    let diagramSignature: String
    private let regionEntries: [MuscleBodySide: [String: [Entry]]]
    private let sideCallouts: [MuscleBodySide: [Entry]]

    init(summary: WeeklySummary) {
        self.init(distribution: WeeklyTagDistribution(summary: summary))
    }

    init(distribution: WeeklyTagDistribution) {
        entries = distribution.entries
        var regions: [MuscleBodySide: [String: [Entry]]] = [:]
        var callouts: [MuscleBodySide: [(index: Int, entry: Entry, anchor: MuscleBodyAnchor)]] = [:]
        for (index, entry) in entries.enumerated() {
            guard let icon = entry.icon else { continue }
            for side in MuscleBodySide.allCases {
                for region in MuscleBodyAnatomy.regions(for: icon, on: side) {
                    regions[side, default: [:]][region, default: []].append(entry)
                }
            }
            let anchor = MuscleBodyAnatomy.anchor(for: icon)
            callouts[anchor.side, default: []].append((index, entry, anchor))
        }
        regionEntries = regions
        let sortedCallouts = callouts.mapValues { values in
            values.sorted {
                $0.anchor.point.y == $1.anchor.point.y ? $0.index < $1.index : $0.anchor.point.y < $1.anchor.point.y
            }.map(\.entry)
        }
        sideCallouts = sortedCallouts
        diagramSignature = MuscleBodySide.allCases.map { side in
            let paints = side.regions.map { region in
                region + ":" + (regions[side]?[region] ?? []).map { $0.colorHex ?? "808080" }.joined(separator: ",")
            }.joined(separator: ";")
            let labels = (sortedCallouts[side] ?? []).map { entry in
                "\(entry.icon?.rawValue ?? ""):\(entry.colorHex ?? "808080"):\(entry.count)"
            }.joined(separator: ";")
            return side.rawValue + "|" + paints + "|" + labels
        }.joined(separator: "/")
    }

    func entries(for region: String, on side: MuscleBodySide) -> [Entry] {
        regionEntries[side]?[region] ?? []
    }

    func callouts(on side: MuscleBodySide) -> [Entry] {
        sideCallouts[side] ?? []
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
