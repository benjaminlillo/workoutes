import SwiftUI

struct MotivationalPullState {
    static let threshold: CGFloat = 120
    static let celebrationDuration: TimeInterval = 3
    static let emojis = ["💪", "🏋️", "🏃", "🤸", "🔥", "🏆"]
    static let phrases = [
        "One rep at a time.",
        "Small steps. Stronger you.",
        "Show up for yourself.",
        "Progress starts with movement.",
        "Your pace. Your progress.",
        "Every effort counts.",
        "Build strength. Build confidence.",
        "Consistency is your superpower."
    ]

    private(set) var distance: CGFloat = 0
    private(set) var emoji: String?
    private(set) var phrase: String?
    private(set) var celebration: EmojiCelebration?
    private(set) var hapticTrigger = 0
    private var isInteracting = false
    private var didCelebrate = false

    var progress: CGFloat { min(distance / Self.threshold, 1) }

    mutating func beginGesture() {
        isInteracting = true
        didCelebrate = celebration != nil
        emoji = nil
        phrase = nil
    }

    mutating func endGesture() {
        isInteracting = false
    }

    mutating func updateDistance(_ distance: CGFloat) {
        self.distance = max(0, distance)
        guard isInteracting, celebration == nil, !didCelebrate else { return }

        if self.distance > 0, emoji == nil {
            emoji = Self.emojis.randomElement()
            phrase = Self.phrases.randomElement()
        }

        guard self.distance > Self.threshold, !didCelebrate, let emoji else { return }
        didCelebrate = true
        hapticTrigger += 1
        celebration = EmojiCelebration(emoji: emoji)
    }

    mutating func finishCelebration() {
        celebration = nil
    }

    mutating func reset() {
        distance = 0
        emoji = nil
        phrase = nil
        celebration = nil
        isInteracting = false
        didCelebrate = false
        // Preserve the feedback token so dismissing/backgrounding home never vibrates.
    }
}

struct EmojiCelebration: Identifiable {
    let id = UUID()
    let emoji: String
    let startedAt: Date
    let particles: [EmojiParticle]

    init(emoji: String, startedAt: Date = .now) {
        self.emoji = emoji
        self.startedAt = startedAt
        // Cover the entire width without random clusters, and shuffle launch order.
        let lanes = (0..<24).map { (CGFloat($0) + .random(in: 0.15...0.85)) / 24 }.shuffled()
        particles = lanes.enumerated().map { EmojiParticle(id: $0.offset, x: $0.element) }
    }
}

struct EmojiParticle: Identifiable {
    let id: Int
    let x: CGFloat
    let restingY = CGFloat.random(in: 0.12...0.88)
    let size = CGFloat.random(in: 24...76)
    let drift = CGFloat.random(in: -42...42)
    let delay: TimeInterval
    let duration: TimeInterval
    let rotation = Double.random(in: -24...24)

    init(id: Int, x: CGFloat) {
        self.id = id
        self.x = x
        delay = Double(id) / 23 * 1.15 + .random(in: 0...0.05)
        duration = .random(in: 1.65...min(2.4, MotivationalPullState.celebrationDuration - delay))
    }
}

struct MotivationalScrollView<Content: View>: View {
    @Environment(\.scenePhase) private var scenePhase
    @Binding var pull: MotivationalPullState
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            content()
        }
        .scrollBounceBehavior(.always)
        .onScrollPhaseChange { oldPhase, newPhase in
            let wasTouching = oldPhase == .tracking || oldPhase == .interacting
            let isTouching = newPhase == .tracking || newPhase == .interacting
            if isTouching && !wasTouching {
                pull.beginGesture()
            } else if !isTouching {
                pull.endGesture()
            }
        }
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            // The resting offset includes the navigation bar's top inset.
            max(0, -(geometry.contentOffset.y + geometry.contentInsets.top))
        } action: { _, distance in
            pull.updateDistance(distance)
        }
        .sensoryFeedback(.impact(weight: .heavy, intensity: 1), trigger: pull.hapticTrigger)
        .task(id: pull.celebration?.id) {
            guard pull.celebration != nil else { return }
            do {
                try await Task.sleep(for: .seconds(MotivationalPullState.celebrationDuration))
                pull.finishCelebration()
            } catch {
                // SwiftUI cancels this task when the home disappears.
            }
        }
        .onDisappear { pull.reset() }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { pull.reset() }
        }
    }
}

/// Sits above the entire TabView so neither navigation bar clips the effect.
struct MotivationalPullOverlay: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let pull: MotivationalPullState

    var body: some View {
        ZStack(alignment: .top) {
            Color.clear
            if let celebration = pull.celebration {
                EmojiCelebrationView(celebration: celebration, reduceMotion: reduceMotion)
                    .ignoresSafeArea()
            }
            if let emoji = pull.emoji, let phrase = pull.phrase, pull.distance > 0 {
                VStack(spacing: 4) {
                    Text(emoji)
                        .font(.system(size: 56))
                        .scaleEffect(0.45 + 0.9 * pull.progress)
                        .frame(height: 78)
                        .accessibilityHidden(true)
                    Text(phrase)
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        // Reveal the phrase once dragging has moved the title out of its way.
                        .opacity(min(max((pull.distance - 35) / 45, 0), 1))
                        .accessibilityIdentifier("motivationalPullPhrase")
                }
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity)
                .opacity(min(pull.distance / 40, 1))
            }
        }
        .allowsHitTesting(false)
    }
}

private struct EmojiCelebrationView: View {
    let celebration: EmojiCelebration
    let reduceMotion: Bool

    var body: some View {
        GeometryReader { geometry in
            TimelineView(.animation) { timeline in
                let elapsed = timeline.date.timeIntervalSince(celebration.startedAt)
                ZStack {
                    ForEach(celebration.particles) { particle in
                        let progress = min(max((elapsed - particle.delay) / particle.duration, 0), 1)
                        let opacity = reduceMotion
                            ? min(progress * 8, (1 - progress) * 5)
                            : min(progress * 30, (1 - progress) * 30)
                        Text(celebration.emoji)
                            .font(.system(size: particle.size))
                            .rotationEffect(.degrees(reduceMotion ? 0 : particle.rotation * progress))
                            .position(
                                x: geometry.size.width * particle.x
                                    + (reduceMotion ? 0 : sin(progress * .pi * 2) * particle.drift),
                                y: reduceMotion ? geometry.size.height * particle.restingY
                                    : geometry.size.height + particle.size
                                        - (geometry.size.height + particle.size * 2) * progress
                            )
                            .opacity(opacity)
                            .accessibilityHidden(true)
                    }
                }
            }
        }
    }
}
