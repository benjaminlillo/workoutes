import SwiftUI
import UIKit
import Observation

/// Uses UIKit's native layout transition and fades only the exercise content.
struct NativeExerciseAccessory: UIViewControllerRepresentable {
    let content: ExerciseActivityAttributes.ContentState?
    let isUpdating: Bool
    let accentColor: Color
    let onStop: () -> Void

    func makeUIViewController(context: Context) -> Controller { Controller() }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.configuration = self
        controller.scheduleUpdate()
    }

    static func dismantleUIViewController(_ controller: Controller, coordinator: ()) {
        controller.tearDown()
    }

    final class Controller: UIViewController {
        var configuration: NativeExerciseAccessory?
        private weak var owner: UITabBarController?
        private var host: AccessoryHost?
        private var accessory: UITabAccessory?
        private var updateScheduled = false
        private var isTornDown = false
        private var isFadingOut = false
        private var fadeGeneration = 0

        override func loadView() {
            view = UIView()
            view.isUserInteractionEnabled = false
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            scheduleUpdate()
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            if owner == nil { scheduleUpdate() }
        }

        func scheduleUpdate() {
            guard !updateScheduled, !isTornDown else { return }
            updateScheduled = true
            // Apply after SwiftUI finishes updating the surrounding controller hierarchy.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.updateScheduled = false
                guard !self.isTornDown else { return }
                self.updateAccessory()
            }
        }

        private func findTabController(in controller: UIViewController) -> UITabBarController? {
            if let tabs = controller as? UITabBarController { return tabs }
            for child in controller.children {
                if let tabs = findTabController(in: child) { return tabs }
            }
            return nil
        }

        private func updateAccessory() {
            guard let configuration else { return }
            var root: UIViewController = self
            while let parent = root.parent { root = parent }
            guard let tabs = owner ?? findTabController(in: root) else { return }
            owner = tabs
            guard let content = configuration.content else {
                host?.view.isUserInteractionEnabled = false
                if let accessory, tabs.bottomAccessory === accessory {
                    fadeOutAccessory(in: tabs)
                } else {
                    tabs.tabBarMinimizeBehavior = .never
                }
                return
            }

            tabs.tabBarMinimizeBehavior = .onScrollDown
            if isFadingOut {
                fadeGeneration += 1
                isFadingOut = false
                fadeContent(to: 1)
            }
            if let host {
                host.state.update(content: content, configuration: configuration)
            } else {
                let newHost = AccessoryHost(state: AccessoryState(content: content, configuration: configuration))
                tabs.addChild(newHost)
                newHost.view.backgroundColor = .clear
                newHost.sizingOptions = .intrinsicContentSize
                newHost.didMove(toParent: tabs)
                host = newHost
                accessory = UITabAccessory(contentView: newHost.view)
            }

            host?.view.isUserInteractionEnabled = true
            if tabs.bottomAccessory !== accessory {
                host?.view.alpha = UIAccessibility.isReduceMotionEnabled ? 1 : 0
                setAccessory(accessory, in: tabs)
                fadeContent(to: 1)
            }
        }

        private func fadeContent(to alpha: CGFloat) {
            guard let host else { return }
            UIView.animate(withDuration: UIAccessibility.isReduceMotionEnabled ? 0 : 0.2,
                           delay: 0, options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseInOut]) {
                host.view.alpha = alpha
            }
        }

        private func fadeOutAccessory(in tabs: UITabBarController) {
            guard !isFadingOut, let host else { return }
            isFadingOut = true
            fadeGeneration += 1
            let generation = fadeGeneration
            UIView.animate(withDuration: UIAccessibility.isReduceMotionEnabled ? 0 : 0.2,
                           delay: 0, options: [.beginFromCurrentState, .allowUserInteraction, .curveEaseInOut]) {
                host.view.alpha = 0
            } completion: { [weak self, weak tabs] _ in
                guard let self, let tabs, !self.isTornDown,
                      self.fadeGeneration == generation,
                      self.configuration?.content == nil else { return }
                self.isFadingOut = false
                self.setAccessory(nil, in: tabs)
                tabs.tabBarMinimizeBehavior = .never
            }
        }

        private func setAccessory(_ accessory: UITabAccessory?, in tabs: UITabBarController) {
            let animated = tabs.view.window != nil && !UIAccessibility.isReduceMotionEnabled
            tabs.setBottomAccessory(accessory, animated: animated)
            tabs.view.layoutIfNeeded()
        }

        func tearDown() {
            isTornDown = true
            fadeGeneration += 1
            if let accessory, owner?.bottomAccessory === accessory {
                owner?.setBottomAccessory(nil, animated: false)
            }
            host?.willMove(toParent: nil)
            host?.view.removeFromSuperview()
            host?.removeFromParent()
            host = nil
            accessory = nil
        }
    }

    @Observable
    final class AccessoryState {
        var content: ExerciseActivityAttributes.ContentState
        var isCompact = false
        var isUpdating: Bool
        var accentColor: Color
        var onStop: () -> Void

        init(content: ExerciseActivityAttributes.ContentState, configuration: NativeExerciseAccessory) {
            self.content = content
            isUpdating = configuration.isUpdating
            accentColor = configuration.accentColor
            onStop = configuration.onStop
        }

        func update(content: ExerciseActivityAttributes.ContentState, configuration: NativeExerciseAccessory) {
            self.content = content
            isUpdating = configuration.isUpdating
            accentColor = configuration.accentColor
            onStop = configuration.onStop
        }
    }

    private struct AccessoryContent: View {
        let state: AccessoryState
        var body: some View {
            ActiveExerciseBar(exercise: state.content, isCompact: state.isCompact,
                              isUpdating: state.isUpdating, onStop: state.onStop)
                .tint(state.accentColor)
        }
    }

    final class AccessoryHost: UIHostingController<AnyView> {
        let state: AccessoryState

        init(state: AccessoryState) {
            self.state = state
            super.init(rootView: AnyView(AccessoryContent(state: state)))
        }

        @MainActor required dynamic init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

        override func viewDidLoad() {
            super.viewDidLoad()
            view.registerForTraitChanges([UITraitTabAccessoryEnvironment.self]) { [weak self] (view: UIView, _) in
                guard let self else { return }
                self.state.isCompact = view.traitCollection.tabAccessoryEnvironment == .inline
            }
        }
    }
}
