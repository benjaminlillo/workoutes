import SwiftUI
import UIKit
import Observation

/// Lets UIKit animate the accessory surface and tab bar together in both directions.
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
        private var isDismissing = false
        private var dismissalGeneration = 0

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
            let animated = tabs.view.window != nil && !UIAccessibility.isReduceMotionEnabled

            guard let content = configuration.content else {
                host?.view.isUserInteractionEnabled = false
                if let accessory, tabs.bottomAccessory === accessory {
                    transition(to: nil, in: tabs, animated: animated)
                }
                // Retain the snapshot-backed host while UIKit animates its removal.
                return
            }

            if isDismissing {
                dismissalGeneration += 1
                isDismissing = false
                host?.view.layer.removeAllAnimations()
                host?.view.alpha = 1
                host?.view.isUserInteractionEnabled = true
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

            if tabs.bottomAccessory !== accessory {
                host?.view.isUserInteractionEnabled = true
                transition(to: accessory, in: tabs, animated: animated)
            }
        }

        private func transition(to accessory: UITabAccessory?, in tabs: UITabBarController, animated: Bool) {
            tabs.view.layoutIfNeeded()
            guard animated else {
                tabs.setBottomAccessory(accessory, animated: false)
                tabs.view.layoutIfNeeded()
                return
            }
            guard let accessory else {
                guard !isDismissing else { return }
                isDismissing = true
                dismissalGeneration += 1
                let generation = dismissalGeneration
                UIView.animate(withDuration: 0.15, delay: 0,
                               options: [.curveEaseInOut, .beginFromCurrentState]) {
                    self.host?.view.alpha = 0
                } completion: { [weak self, weak tabs] _ in
                    guard let self, let tabs, !self.isTornDown,
                          self.dismissalGeneration == generation,
                          self.configuration?.content == nil else { return }
                    // The content is already invisible before its glass container
                    // is removed, so UIKit cannot clip the text during contraction.
                    UIView.animate(withDuration: 0.3, delay: 0,
                                   options: [.curveEaseInOut, .beginFromCurrentState, .allowUserInteraction]) {
                        tabs.setBottomAccessory(nil, animated: false)
                        tabs.view.layoutIfNeeded()
                    } completion: { [weak self] _ in
                        guard let self, self.dismissalGeneration == generation else { return }
                        self.isDismissing = false
                        self.host?.view.alpha = 1
                    }
                }
                return
            }
            // Only insertion needs an explicit animation around the layout pass.
            UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 1,
                           initialSpringVelocity: 0, options: [.beginFromCurrentState, .allowUserInteraction]) {
                tabs.setBottomAccessory(accessory, animated: true)
                tabs.view.layoutIfNeeded()
            }
        }

        func tearDown() {
            isTornDown = true
            dismissalGeneration += 1
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
                self?.state.isCompact = view.traitCollection.tabAccessoryEnvironment == .inline
            }
        }
    }
}
