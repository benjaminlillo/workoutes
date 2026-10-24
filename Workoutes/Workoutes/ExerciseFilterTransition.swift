import SwiftUI
import UIKit

/// Keeps at most one outgoing snapshot and one pending entrance for the latest filter.
@MainActor
final class ExerciseFilterTransition {
    weak var viewport: ExerciseFilterViewport?
    static let duration = 0.12

    func begin() { viewport?.changeSelection() }
    func cancel() { viewport?.clear() }
}

struct ExerciseFilterTransitionLayer: UIViewRepresentable {
    let transition: ExerciseFilterTransition
    let showsEmptyMessage: Bool

    func makeUIView(context: Context) -> ExerciseFilterViewport {
        let view = ExerciseFilterViewport()
        transition.viewport = view
        view.showsEmptyMessage = showsEmptyMessage
        return view
    }

    func updateUIView(_ view: ExerciseFilterViewport, context: Context) {
        transition.viewport = view
        view.showsEmptyMessage = showsEmptyMessage
    }

    static func dismantleUIView(_ view: ExerciseFilterViewport, coordinator: ()) { view.clear() }
}

final class ExerciseFilterViewport: UIView {
    private(set) var outgoing: UIView?
    private(set) var isActive = false
    private(set) var isEntering = false
    var duration = ExerciseFilterTransition.duration
    var showsEmptyMessage = false {
        didSet { emptyMessage.isHidden = !showsEmptyMessage }
    }
    private weak var list: UICollectionView?
    private let emptyMessage: UIContentUnavailableView
    private var exitAnimator: UIViewPropertyAnimator?
    private var entranceAnimators: [UIViewPropertyAnimator] = []
    private var animatedCells: [UICollectionViewCell] = []
    private var pendingStart: Task<Void, Never>?
    private var generation = 0
    private var isExiting = false
    private var lastSelection = ContinuousClock.now
    private let settlingInterval: Duration = .milliseconds(60)

    override init(frame: CGRect) {
        var configuration = UIContentUnavailableConfiguration.empty()
        configuration.image = UIImage(systemName: "dumbbell")
        configuration.text = String(localized: "No Exercises")
        configuration.secondaryText = String(localized: "No exercises with this tag.")
        emptyMessage = UIContentUnavailableView(configuration: configuration)
        super.init(frame: frame)
        isUserInteractionEnabled = false
        clipsToBounds = true
        emptyMessage.backgroundColor = .clear
        emptyMessage.isHidden = true
        addSubview(emptyMessage)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        emptyMessage.frame = bounds
    }

    func changeSelection() {
        let attachedList = list?.window == nil ? nil : list
        guard window != nil, let list = attachedList ?? findList() else { return }
        self.list = list
        generation += 1
        lastSelection = .now
        pendingStart?.cancel()
        pendingStart = nil
        isActive = true

        // Rapid wheel changes reuse this exit and never restart its clock.
        guard !isExiting else { return }
        if list.alpha > 0 { capture(list) }
        UIView.performWithoutAnimation {
            list.alpha = 0
            emptyMessage.alpha = 0
        }
        stopEntrance()

        guard outgoing != nil else { scheduleEntrance(); return }
        isExiting = true
        let animator = UIViewPropertyAnimator(duration: duration, curve: .easeOut) { [weak self] in
            self?.outgoing?.alpha = 0
        }
        exitAnimator = animator
        animator.addCompletion { [weak self, weak animator] _ in
            guard let self, let animator, self.exitAnimator === animator, self.isExiting else { return }
            self.removeOutgoing()
            self.exitAnimator = nil
            self.isExiting = false
            self.scheduleEntrance()
        }
        animator.startAnimation()
    }

    private func scheduleEntrance() {
        pendingStart?.cancel()
        let request = generation
        let deadline = lastSelection.advanced(by: settlingInterval)
        pendingStart = Task { [weak self] in
            do {
                if deadline > .now { try await Task.sleep(until: deadline, clock: .continuous) }
                // Commit the newest SwiftUI rows while the live list is hidden.
                try await Task.sleep(for: .milliseconds(16))
            } catch { return }
            guard !Task.isCancelled, let self, self.generation == request else { return }
            self.pendingStart = nil
            self.enter(request: request)
        }
    }

    private func enter(request: Int) {
        guard let list, window != nil else { clear(); return }
        list.layoutIfNeeded()
        let visible = list.bounds.inset(by: list.adjustedContentInset)
        let cells = list.visibleCells.filter { $0.frame.intersects(visible) }
            .sorted { $0.frame.minY < $1.frame.minY }
        animatedCells = cells
        isEntering = true
        UIView.performWithoutAnimation {
            for cell in cells { cell.alpha = 0 }
            list.alpha = 1
            emptyMessage.alpha = 0
        }

        let targets: [(UIView, TimeInterval)] = cells.map { cell in
            // Exercise cards have ten points of vertical padding inside their list row.
            let top = cell.convert(cell.bounds, to: window).minY + 10
            return (cell, ContainerAppearanceTiming.delay(at: top))
        } + (showsEmptyMessage ? [(emptyMessage, 0)] : [])
        guard !targets.isEmpty else { finishEntrance(request: request); return }
        var remaining = targets.count
        for (view, delay) in targets {
            let animator = UIViewPropertyAnimator(duration: ContainerAppearanceTiming.duration, curve: .easeOut) {
                view.alpha = 1
            }
            animator.addCompletion { [weak self] _ in
                guard let self, self.generation == request else { return }
                remaining -= 1
                if remaining == 0 { self.finishEntrance(request: request) }
            }
            entranceAnimators.append(animator)
            animator.startAnimation(afterDelay: delay)
        }
    }

    private func finishEntrance(request: Int) {
        guard generation == request else { return }
        entranceAnimators.removeAll()
        animatedCells.removeAll()
        emptyMessage.alpha = 1
        isEntering = false
        isActive = false
    }

    func clear() {
        generation += 1
        pendingStart?.cancel()
        pendingStart = nil
        isExiting = false
        if exitAnimator?.state == .active { exitAnimator?.stopAnimation(true) }
        exitAnimator = nil
        stopEntrance()
        removeOutgoing()
        UIView.performWithoutAnimation {
            list?.alpha = 1
            list?.visibleCells.forEach { $0.alpha = 1 }
            emptyMessage.alpha = 1
        }
        isActive = false
    }

    private func stopEntrance() {
        for animator in entranceAnimators where animator.state == .active { animator.stopAnimation(true) }
        entranceAnimators.removeAll()
        UIView.performWithoutAnimation { animatedCells.forEach { $0.alpha = 1 } }
        animatedCells.removeAll()
        isEntering = false
    }

    private func removeOutgoing() {
        outgoing?.superview?.removeFromSuperview()
        outgoing = nil
    }

    private func capture(_ list: UICollectionView) {
        // Capture only visible live cells, never another snapshot or the wheel/chrome.
        let visible = list.convert(list.bounds.inset(by: list.adjustedContentInset), to: self).intersection(bounds)
        guard !visible.isNull, !visible.isEmpty else { return }
        let clip = UIView(frame: visible)
        clip.clipsToBounds = true
        clip.accessibilityElementsHidden = true
        addSubview(clip)
        let content = UIView(frame: clip.bounds)
        clip.addSubview(content)
        for cell in list.visibleCells {
            let frame = cell.convert(cell.bounds, to: clip)
            let alpha = CGFloat(cell.layer.presentation()?.opacity ?? Float(cell.alpha))
            guard frame.intersects(clip.bounds), alpha > 0.01,
                  let snapshot = cell.snapshotView(afterScreenUpdates: false) else { continue }
            snapshot.frame = frame
            // UIKit already captures the currently displayed opacity, including an interrupted fade.
            content.addSubview(snapshot)
        }
        let emptyAlpha = emptyMessage.layer.presentation()?.opacity ?? Float(emptyMessage.alpha)
        if showsEmptyMessage, emptyAlpha > 0.01,
           let snapshot = emptyMessage.snapshotView(afterScreenUpdates: false) {
            snapshot.frame = emptyMessage.convert(emptyMessage.bounds, to: clip)
            content.addSubview(snapshot)
        }
        guard !content.subviews.isEmpty else { clip.removeFromSuperview(); return }
        outgoing = content
    }

    private func findList() -> UICollectionView? {
        func search(_ view: UIView) -> UICollectionView? {
            guard view !== self else { return nil }
            if let list = view as? UICollectionView { return list }
            for child in view.subviews {
                if let list = search(child) { return list }
            }
            return nil
        }
        var ancestor = superview
        while let view = ancestor {
            if let list = search(view) { return list }
            ancestor = view.superview
        }
        return nil
    }
}
