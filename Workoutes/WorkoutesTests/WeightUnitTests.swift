import XCTest
@testable import Workoutes

@MainActor
final class WeightUnitTests: XCTestCase {
    func testPoundsConvertToStoredKilograms() {
        XCTAssertEqual(WeightUnit.imperial.kilograms(from: 100), 45.359237, accuracy: 0.000001)
        XCTAssertEqual(WeightUnit.imperial.displayedWeight(from: 45.359237), 100, accuracy: 0.000001)
        XCTAssertEqual(WeightUnit.metric.displayedWeight(from: 50), 50)
    }

    func testPickerStepsInBothSystems() {
        for unit in WeightUnit.allCases {
            let first = unit.kilograms(from: 20)
            let expectedStep = unit == .metric ? 0.5 : 1.0
            let next = unit.kilograms(from: 20 + unit.pickerStep)
            XCTAssertEqual(unit.displayedWeight(from: next) - unit.displayedWeight(from: first), expectedStep, accuracy: 0.000001)
        }
    }
}
