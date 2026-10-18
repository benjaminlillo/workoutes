import Foundation

nonisolated enum MuscleIcon: String, CaseIterable, Identifiable {
    case fullBody, upperBody, lowerBody, arms, core
    case chest, back, shoulders, biceps, triceps, forearms, trapezius, upperBack, lowerBack, abdominals, obliques, neck
    case glutes, quadriceps, hamstrings, calves, adductors, abductors, tibialis

    var id: String { rawValue }
    var baseAsset: String { "muscle-\(rawValue)-base" }
    var highlightAsset: String { "muscle-\(rawValue)-highlight" }

    var name: String {
        switch self {
        case .fullBody: "Full Body"
        case .upperBody: "Upper Body"
        case .lowerBody: "Legs"
        case .arms: "Arms"
        case .core: "Core"
        case .chest: "Chest"
        case .back: "Back"
        case .shoulders: "Shoulders"
        case .biceps: "Biceps"
        case .triceps: "Triceps"
        case .forearms: "Forearms"
        case .trapezius: "Trapezius"
        case .upperBack: "Upper Back"
        case .lowerBack: "Lower Back"
        case .abdominals: "Abdominals"
        case .obliques: "Obliques"
        case .neck: "Neck"
        case .glutes: "Glutes"
        case .quadriceps: "Quadriceps"
        case .hamstrings: "Hamstrings"
        case .calves: "Calves"
        case .adductors: "Adductors"
        case .abductors: "Abductors"
        case .tibialis: "Tibialis"
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
