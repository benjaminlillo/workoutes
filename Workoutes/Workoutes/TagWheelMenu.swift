import SwiftData
import SwiftUI
import UIKit

/// The wheel must wait for the native menu's source preview to return before
/// changing scale or position. A dismissal completion also respects Reduce Motion.
struct TagWheelMenu: UIViewRepresentable {
    let tags: [Tag]
    let selection: PersistentIdentifier?
    let color: Color
    let onChoose: (Tag) -> Void
    let onDeselect: () -> Void
    let onAdd: () -> Void
    let onEdit: (Tag) -> Void
    let onDelete: (Tag) -> Void
    @AppStorage("appAccentColor") private var accentColorRawValue = ThemeColor.primary.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale

    func makeUIView(context: Context) -> TagWheelMenuButton {
        TagWheelMenuButton(frame: .zero)
    }

    func updateUIView(_ button: TagWheelMenuButton, context: Context) {
        button.setEmpty(tags.isEmpty)
        let tint = UIColor(color)
        if button.tintColor != tint {
            UIView.animate(withDuration: reduceMotion ? 0 : 0.35,
                           delay: 0, options: [.beginFromCurrentState, .allowUserInteraction]) {
                button.tintColor = tint
            }
        }
        button.accessibilityValue = tags.first { $0.persistentModelID == selection }?.name ?? "No Tag Selected"

        func action(_ title: String, image: UIImage? = nil, attributes: UIMenuElement.Attributes = [],
                    state: UIMenuElement.State = .off, perform: @escaping () -> Void) -> UIAction {
            UIAction(title: title, image: image, attributes: attributes, state: state) { [weak button] _ in
                button?.performAfterMenuDismissal(perform)
            }
        }

        var children: [UIMenuElement] = []
        if !tags.isEmpty {
            let options = tags.map { tag in
                action(tag.name, image: tagImage(tag),
                       state: tag.persistentModelID == selection ? .on : .off) { onChoose(tag) }
            }
            children.append(UIMenu(title: "Filter by Tag", options: .displayInline, children: options))
            let deselect = action("Deselect All Tags", image: menuImage("xmark.circle"),
                                  attributes: selection == nil ? .disabled : []) { onDeselect() }
            children.append(UIMenu(options: .displayInline, children: [deselect]))
        }

        var management: [UIMenuElement] = [action("Add Tag", image: menuImage("plus")) { onAdd() }]
        if !tags.isEmpty {
            management.append(UIMenu(title: "Edit Tag", image: menuImage("pencil"), children: tags.map { tag in
                action(tag.name) { onEdit(tag) }
            }))
            management.append(UIMenu(title: "Delete Tag", image: menuImage("trash"), children: tags.map { tag in
                action(tag.name, attributes: .destructive) { onDelete(tag) }
            }))
        }
        children.append(UIMenu(options: .displayInline, children: management))
        button.menu = UIMenu(children: children)
    }

    private func menuImage(_ name: String) -> UIImage? {
        UIImage(systemName: name)?.withTintColor(UIColor(ThemeColor.resolve(accentColorRawValue).color),
                                                renderingMode: .alwaysOriginal)
    }

    private func tagImage(_ tag: Tag) -> UIImage? {
        guard let icon = tag.muscleIcon else {
            return UIImage(systemName: "circle.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 8))?
                .withTintColor(UIColor(Color(hex: tag.colorHex)), renderingMode: .alwaysOriginal)
        }
        let renderer = ImageRenderer(content: MuscleIconView(icon: icon, color: Color(hex: tag.colorHex))
            .frame(width: 24, height: 24).environment(\.colorScheme, colorScheme))
        renderer.scale = displayScale
        return renderer.uiImage?.withRenderingMode(.alwaysOriginal)
    }
}

final class TagWheelMenuButton: UIButton {
    private let symbol = UIImageView()
    private let chevron = UIImageView(image: UIImage(systemName: "chevron.down",
                                                    withConfiguration: UIImage.SymbolConfiguration(pointSize: 8, weight: .bold)))
    private var menuIsPresented = false
    private var pendingAction: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        var configuration = UIButton.Configuration.glass()
        configuration.cornerStyle = .capsule
        configuration.contentInsets = .zero
        self.configuration = configuration
        showsMenuAsPrimaryAction = true
        preferredMenuElementOrder = .fixed
        accessibilityLabel = "Filter and Manage Tags"
        accessibilityIdentifier = "tag-wheel-menu"

        let label = UIStackView(arrangedSubviews: [symbol, chevron])
        label.alignment = .center
        label.spacing = 3
        label.isUserInteractionEnabled = false
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setEmpty(_ isEmpty: Bool) {
        symbol.image = UIImage(systemName: isEmpty ? "plus" : "tag",
                               withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold))
        chevron.isHidden = isEmpty
    }

    func performAfterMenuDismissal(_ action: @escaping () -> Void) {
        if menuIsPresented { pendingAction = action }
        else { action() }
    }

    override func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
                                        willDisplayMenuFor configuration: UIContextMenuConfiguration,
                                        animator: (any UIContextMenuInteractionAnimating)?) {
        super.contextMenuInteraction(interaction, willDisplayMenuFor: configuration, animator: animator)
        menuIsPresented = true
    }

    override func contextMenuInteraction(_ interaction: UIContextMenuInteraction,
                                        willEndFor configuration: UIContextMenuConfiguration,
                                        animator: (any UIContextMenuInteractionAnimating)?) {
        super.contextMenuInteraction(interaction, willEndFor: configuration, animator: animator)
        if let animator {
            animator.addCompletion { [weak self] in self?.finishMenuDismissal() }
        } else {
            finishMenuDismissal()
        }
    }

    private func finishMenuDismissal() {
        menuIsPresented = false
        let action = pendingAction
        pendingAction = nil
        action?()
    }
}
