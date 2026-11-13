import Foundation

nonisolated enum MuscleIcon: String, CaseIterable, Identifiable {
    case fullBody, upperBody, lowerBody, arms, core
    case chest, back, shoulders, biceps, triceps, forearms, trapezius, upperBack, lowerBack, abdominals, obliques, neck
    case glutes, quadriceps, hamstrings, calves, adductors, abductors, tibialis
    case upperChest, middleChest, lowerChest
    case anteriorDeltoid, lateralDeltoid, posteriorDeltoid
    case bicepsLongHead, bicepsShortHead
    case tricepsLongHead, tricepsLateralHead, tricepsMedialHead
    case forearmFlexors, forearmExtensors, brachioradialis
    case lats, transverseAbdominis, externalObliques, internalObliques

    var id: String { rawValue }
    var baseAsset: String { "muscle-\(rawValue)-base" }
    var highlightAsset: String { "muscle-\(rawValue)-highlight" }

    var name: String {
        switch self {
        case .fullBody: String(localized: "Full Body")
        case .upperBody: String(localized: "Upper Body")
        case .lowerBody: String(localized: "Legs")
        case .arms: String(localized: "Arms")
        case .core: String(localized: "Core")
        case .chest: String(localized: "Chest")
        case .back: String(localized: "Back")
        case .shoulders: String(localized: "Shoulders")
        case .biceps: String(localized: "Biceps")
        case .triceps: String(localized: "Triceps")
        case .forearms: String(localized: "Forearms")
        case .trapezius: String(localized: "Trapezius")
        case .upperBack: String(localized: "Upper Back")
        case .lowerBack: String(localized: "Lower Back")
        case .abdominals: String(localized: "Rectus Abdominis")
        case .obliques: String(localized: "Obliques")
        case .neck: String(localized: "Neck")
        case .glutes: String(localized: "Glutes")
        case .quadriceps: String(localized: "Quadriceps")
        case .hamstrings: String(localized: "Hamstrings")
        case .calves: String(localized: "Calves")
        case .adductors: String(localized: "Adductors")
        case .abductors: String(localized: "Abductors")
        case .tibialis: String(localized: "Tibialis")
        case .upperChest: String(localized: "Upper Chest")
        case .middleChest: String(localized: "Middle Chest")
        case .lowerChest: String(localized: "Lower Chest")
        case .anteriorDeltoid: String(localized: "Anterior Deltoid")
        case .lateralDeltoid: String(localized: "Middle Deltoid")
        case .posteriorDeltoid: String(localized: "Posterior Deltoid")
        case .bicepsLongHead: String(localized: "Biceps Long Head")
        case .bicepsShortHead: String(localized: "Biceps Short Head")
        case .tricepsLongHead: String(localized: "Triceps Long Head")
        case .tricepsLateralHead: String(localized: "Triceps Lateral Head")
        case .tricepsMedialHead: String(localized: "Triceps Medial Head")
        case .forearmFlexors: String(localized: "Forearm Flexors")
        case .forearmExtensors: String(localized: "Forearm Extensors")
        case .brachioradialis: String(localized: "Brachioradialis")
        case .lats: String(localized: "Lats")
        case .transverseAbdominis: String(localized: "Transverse Abdominis")
        case .externalObliques: String(localized: "External Obliques")
        case .internalObliques: String(localized: "Internal Obliques")
        }
    }

    var group: Group {
        switch self {
        case .fullBody, .upperBody, .lowerBody, .arms, .core: .general
        case .glutes, .quadriceps, .hamstrings, .calves, .adductors, .abductors, .tibialis: .lowerBody
        default: .upperBody
        }
    }

    enum Group: String, CaseIterable, Identifiable {
        case general = "General"
        case upperBody = "Upper Body"
        case lowerBody = "Lower Body"
        var id: String { rawValue }
    }
}
