import Observation
import SwiftUI
import UIKit

struct NativeSessionAccessory: UIViewControllerRepresentable {
    let content: SessionActivityAttributes.ContentState?
    let isUpdating: Bool
    let accentColor: Color
    let onAdvance: () -> Void

    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.configuration = self
        controller.scheduleUpdate()
    }
    static func dismantleUIViewController(_ controller: Controller, coordinator: ()) { controller.tearDown() }

    final class Controller: UIViewController {
        var configuration: NativeSessionAccessory?
        private weak var owner: UITabBarController?
        private var host: AccessoryHost?
        private var accessory: UITabAccessory?
        private var updateScheduled = false

        override func loadView() {
            view = UIView()
            view.isUserInteractionEnabled = false
        }
        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            scheduleUpdate()
        }
        func scheduleUpdate() {
            guard !updateScheduled else { return }
            updateScheduled = true
            DispatchQueue.main.async { [weak self] in
                self?.updateScheduled = false
                self?.updateAccessory()
            }
        }
        private func findTabs(in controller: UIViewController) -> UITabBarController? {
            if let tabs = controller as? UITabBarController { return tabs }
            return controller.children.lazy.compactMap(findTabs).first
        }
        private func updateAccessory() {
            guard let configuration else { return }
            var root: UIViewController = self
            while let parent = root.parent { root = parent }
            guard let tabs = owner ?? findTabs(in: root) else { return }
            owner = tabs
            guard let content = configuration.content else {
                if tabs.bottomAccessory === accessory { tabs.setBottomAccessory(nil, animated: true) }
                tabs.tabBarMinimizeBehavior = .never
                return
            }
            tabs.tabBarMinimizeBehavior = .onScrollDown
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
            if tabs.bottomAccessory !== accessory { tabs.setBottomAccessory(accessory, animated: true) }
        }
        func tearDown() {
            if let accessory, owner?.bottomAccessory === accessory { owner?.setBottomAccessory(nil, animated: false) }
            host?.willMove(toParent: nil)
            host?.view.removeFromSuperview()
            host?.removeFromParent()
        }
    }

    @Observable
    final class AccessoryState {
        var content: SessionActivityAttributes.ContentState
        var isCompact = false
        var isUpdating: Bool
        var accentColor: Color
        var onAdvance: () -> Void
        init(content: SessionActivityAttributes.ContentState, configuration: NativeSessionAccessory) {
            self.content = content
            isUpdating = configuration.isUpdating
            accentColor = configuration.accentColor
            onAdvance = configuration.onAdvance
        }
        func update(content: SessionActivityAttributes.ContentState, configuration: NativeSessionAccessory) {
            self.content = content
            isUpdating = configuration.isUpdating
            accentColor = configuration.accentColor
            onAdvance = configuration.onAdvance
        }
    }

    private struct AccessoryContent: View {
        let state: AccessoryState
        var body: some View {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                HStack(spacing: state.isCompact ? 8 : 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.content.blockName)
                            .font(state.isCompact ? .caption.weight(.semibold) : .subheadline.weight(.semibold))
                            .lineLimit(1)
                        HStack(spacing: 4) {
                            Text(blockTime(at: context.date))
                                .font(state.isCompact ? .subheadline.monospacedDigit() : .title3.bold().monospacedDigit())
                            if state.isCompact {
                                Text("· \(elapsed(from: state.content.sessionStartedAt, at: context.date))")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Spacer(minLength: 4)
                    if !state.isCompact {
                        Text("Total \(elapsed(from: state.content.sessionStartedAt, at: context.date))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    Button(action: state.onAdvance) {
                        Image(systemName: state.content.isLastBlock ? "checkmark" : "forward.end.fill")
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.glassProminent)
                    .buttonBorderShape(.circle)
                    .tint(state.accentColor)
                    .disabled(state.isUpdating)
                    .accessibilityLabel(state.content.isLastBlock ? "Finish Session" : "Next Block")
                }
                .padding(.horizontal, 12)
                .frame(minHeight: state.isCompact ? 44 : 58)
            }
        }
        private func blockTime(at date: Date) -> String {
            if let end = state.content.restEndsAt {
                let remaining = end.timeIntervalSince(date)
                return (remaining < 0 ? "+" : "") + duration(abs(remaining))
            }
            return elapsed(from: state.content.blockStartedAt, at: date)
        }
        private func elapsed(from start: Date, at date: Date) -> String { duration(max(0, date.timeIntervalSince(start))) }
        private func duration(_ value: TimeInterval) -> String {
            let seconds = Int(value.rounded(.down))
            let hours = seconds / 3600
            return hours > 0
                ? String(format: "%d:%02d:%02d", hours, (seconds % 3600) / 60, seconds % 60)
                : String(format: "%d:%02d", seconds / 60, seconds % 60)
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
