import SwiftUI
import UIKit

/// Crossfades visible content without moving it or clearing the viewport.
/// Fast filter updates inherit the current fade instead of restarting it.
@MainActor
final class ExerciseFilterTransition {
    weak var viewport: ExerciseFilterViewport?
    static let duration = 0.2

    func begin() {
        guard viewport?.prepare() == true else { return }
        viewport?.fadeAfterUpdate()
    }

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
    var duration = ExerciseFilterTransition.duration
    var showsEmptyMessage = false {
        didSet { emptyMessage.isHidden = !showsEmptyMessage }
    }
    private weak var list: UICollectionView?
    private let emptyMessage: UIContentUnavailableView
    private var animator: UIViewPropertyAnimator?
    private var pendingStart: Task<Void, Never>?

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

    func prepare() -> Bool {
        // Selection still changes immediately during this interval. Only its
        // container animation is reused; there is no queue or repeated snapshot.
        let attachedList = list?.window == nil ? nil : list
        guard !isActive, window != nil, let list = attachedList ?? findList() else { return false }
        self.list = list
        capture(list)
        isActive = true
        UIView.performWithoutAnimation {
            list.alpha = 0
            emptyMessage.alpha = 0
        }
        return true
    }

    func fadeAfterUpdate() {
        // Let SwiftUI commit the new rows once. This task belongs to the native
        // transition, so subsequent filter changes cannot cancel its entrance.
        pendingStart = Task { [weak self] in
            do { try await Task.sleep(for: .milliseconds(16)) }
            catch { return }
            guard !Task.isCancelled, let self else { return }
            self.pendingStart = nil
            guard self.isActive, let list = self.list else { self.clear(); return }
            let animator = UIViewPropertyAnimator(duration: self.duration, curve: .easeInOut) {
                list.alpha = 1
                self.emptyMessage.alpha = 1
                self.outgoing?.alpha = 0
            }
            self.animator = animator
            animator.addCompletion { [weak self] _ in self?.clear() }
            animator.startAnimation()
        }
    }

    func clear() {
        pendingStart?.cancel()
        pendingStart = nil
        if animator?.state == .active { animator?.stopAnimation(true) }
        animator = nil
        outgoing?.superview?.removeFromSuperview()
        outgoing = nil
        UIView.performWithoutAnimation {
            list?.alpha = 1
            emptyMessage.alpha = 1
        }
        isActive = false
    }

    private func capture(_ list: UICollectionView) {
        // Only settled, visible content is captured, never another snapshot.
        // Exclude navigation and tab chrome even when scrolled underneath them.
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
            guard frame.intersects(clip.bounds), let snapshot = cell.snapshotView(afterScreenUpdates: false) else { continue }
            snapshot.frame = frame
            content.addSubview(snapshot)
        }
        if showsEmptyMessage, let snapshot = emptyMessage.snapshotView(afterScreenUpdates: false) {
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
