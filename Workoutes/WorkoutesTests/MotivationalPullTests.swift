import XCTest
@testable import Workoutes

final class MotivationalPullTests: XCTestCase {
    func testSelectionStaysStableAndOnlyCrossingThresholdTriggersCelebration() throws {
        var pull = MotivationalPullState()
        pull.beginGesture()
        pull.updateDistance(20)
        let emoji = try XCTUnwrap(pull.emoji)
        let phrase = try XCTUnwrap(pull.phrase)
        XCTAssertTrue(MotivationalPullState.emojis.contains(emoji))
        XCTAssertTrue(MotivationalPullState.phrases.contains(phrase))
        pull.updateDistance(MotivationalPullState.threshold)
        XCTAssertNil(pull.celebration)
        XCTAssertEqual(pull.emoji, emoji)
        XCTAssertEqual(pull.phrase, phrase)

        pull.updateDistance(MotivationalPullState.threshold + 1)
        XCTAssertEqual(pull.celebration?.emoji, emoji)
        XCTAssertEqual(pull.celebration?.particles.count, 24)
        XCTAssertEqual(pull.hapticTrigger, 1)
        XCTAssertEqual(pull.progress, 1)
    }

    func testReboundAndHoldingGestureDoNotRetriggerAfterAnimationEnds() {
        var pull = MotivationalPullState()
        pull.beginGesture()
        pull.updateDistance(121)
        pull.finishCelebration()
        pull.updateDistance(10)
        pull.updateDistance(150)
        XCTAssertNil(pull.celebration)
        XCTAssertEqual(pull.hapticTrigger, 1)

        pull.endGesture()
        pull.updateDistance(180)
        XCTAssertNil(pull.celebration)
        pull.updateDistance(-20)
        XCTAssertEqual(pull.distance, 0)

        pull.beginGesture()
        pull.updateDistance(121)
        XCTAssertNotNil(pull.celebration)
        XCTAssertEqual(pull.hapticTrigger, 2)
    }

    func testPassiveScrollingAndAnotherGestureDuringCelebrationCannotTrigger() throws {
        var pull = MotivationalPullState()
        pull.updateDistance(180)
        XCTAssertNil(pull.emoji)
        XCTAssertNil(pull.celebration)
        XCTAssertEqual(pull.hapticTrigger, 0)

        pull.beginGesture()
        pull.updateDistance(121)
        let celebrationID = try XCTUnwrap(pull.celebration?.id)
        pull.endGesture()
        pull.beginGesture()
        pull.updateDistance(180)
        XCTAssertEqual(pull.celebration?.id, celebrationID)
        XCTAssertEqual(pull.hapticTrigger, 1)
        pull.finishCelebration()
        pull.updateDistance(200)
        XCTAssertNil(pull.celebration)
        XCTAssertEqual(pull.hapticTrigger, 1)
    }

    func testLeavingHomeClearsEffectsWithoutTriggeringAnotherHaptic() {
        var pull = MotivationalPullState()
        pull.beginGesture()
        pull.updateDistance(121)
        pull.reset()
        XCTAssertNil(pull.celebration)
        XCTAssertNil(pull.emoji)
        XCTAssertNil(pull.phrase)
        XCTAssertEqual(pull.distance, 0)
        XCTAssertEqual(pull.hapticTrigger, 1)
        pull.updateDistance(150)
        XCTAssertNil(pull.celebration)
        pull.beginGesture()
        pull.updateDistance(121)
        XCTAssertEqual(pull.hapticTrigger, 2)
    }

    func testParticlesFinishWithinThreeSecondsAndUseDifferentSizes() throws {
        var pull = MotivationalPullState()
        pull.beginGesture()
        pull.updateDistance(121)
        let particles = try XCTUnwrap(pull.celebration?.particles)
        XCTAssertTrue(particles.allSatisfy {
            $0.delay + $0.duration <= MotivationalPullState.celebrationDuration
        })
        XCTAssertGreaterThan(Set(particles.map(\.size)).count, 1)
    }

    func testParticlesCoverFullWidthAndLaunchAtDifferentTimes() {
        let particles = EmojiCelebration(emoji: "💪").particles
        XCTAssertEqual(Set(particles.map { Int($0.x * 24) }), Set(0..<24))
        XCTAssertLessThan(particles.map(\.x).min()!, 0.04)
        XCTAssertGreaterThan(particles.map(\.x).max()!, 0.96)
        XCTAssertGreaterThan(particles.map(\.delay).max()! - particles.map(\.delay).min()!, 1)
    }
}
