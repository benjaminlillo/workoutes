import Foundation

enum WeightUnit: String, CaseIterable, Identifiable {
    case metric
    case imperial

    var id: String { rawValue }
    var symbol: String { self == .metric ? "kg" : "lb" }
    var name: String { self == .metric ? "Metric (kg)" : "Imperial (lb)" }
    var accessibilityName: String { self == .metric ? "kilograms" : "pounds" }
    var pickerStep: Double { self == .metric ? 0.5 : 1 }

    // Stored exercise weights remain in kilograms when the display unit changes.
    func displayedWeight(from kilograms: Double) -> Double {
        self == .metric ? kilograms : kilograms / 0.45359237
    }

    func kilograms(from displayedWeight: Double) -> Double {
        self == .metric ? displayedWeight : displayedWeight * 0.45359237
    }

    func label(for kilograms: Double) -> String {
        "\(displayedWeight(from: kilograms).formatted(.number.precision(.fractionLength(0...2)))) \(symbol)"
    }
}
