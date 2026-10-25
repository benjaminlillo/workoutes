import SwiftData
import SwiftUI
import UIKit

/// Shared tag actions hosted in the native navigation toolbar.
/// Actions that present another interface wait for menu dismissal to finish.
struct TagWheelMenu: UIViewRepresentable {
    let tags: [Tag]
    let selection: PersistentIdentifier?
    let onChoose: (Tag) -> Void
    let onDeselect: () -> Void
    let onAdd: () -> Void
    let onEdit: (Tag) -> Void
    let onDelete: (Tag) -> Void
    @AppStorage("appAccentColor") private var accentColorRawValue = ThemeColor.indigo.rawValue
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.displayScale) private var displayScale

    func makeUIView(context: Context) -> TagWheelMenuButton {
        TagWheelMenuButton(frame: .zero)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func updateUIView(_ button: TagWheelMenuButton, context: Context) {
        let theme = ThemeColor.resolve(accentColorRawValue)
        let tint = selection == nil ? UIColor.label : UIColor(Color(hex: theme.hex(for: colorScheme)))
        button.setSymbolColor(tint.resolvedColor(with: UITraitCollection(
            userInterfaceStyle: colorScheme == .dark ? .dark : .light)))
        if button.tintColor != tint || button.configuration?.baseForegroundColor != tint {
            UIView.animate(withDuration: reduceMotion ? 0 : 0.35,
                           delay: 0, options: [.beginFromCurrentState, .allowUserInteraction]) {
                button.tintColor = tint
                button.configuration?.baseForegroundColor = tint
            }
        }
        button.accessibilityValue = tags.first { $0.persistentModelID == selection }?.name ?? "No Tag Selected"

        updateMenu(button, coordinator: context.coordinator, theme: theme,
                   scheme: colorScheme, scale: displayScale)
    }

    func updateMenu(_ button: TagWheelMenuButton, coordinator: Coordinator,
                    theme: ThemeColor, scheme: ColorScheme, scale: CGFloat) {
        // Refresh handlers even when the menu's appearance is unchanged, so cached
        // actions always use the current SwiftUI bindings and model instances.
        coordinator.tags = tags
        coordinator.onChoose = onChoose
        coordinator.onDeselect = onDeselect
        coordinator.onAdd = onAdd
        coordinator.onEdit = onEdit
        coordinator.onDelete = onDelete
        let key = MenuKey(tags: tags.map { TagKey(id: $0.persistentModelID, name: $0.name,
                                                 colorHex: $0.colorHex, iconName: $0.iconName) },
                          selection: selection, theme: theme, scheme: scheme, scale: scale)
        guard coordinator.menuKey != key else { return }
        coordinator.menuKey = key
        coordinator.usedImages.removeAll(keepingCapacity: true)

        func action(_ title: String, image: UIImage? = nil, attributes: UIMenuElement.Attributes = [],
                    state: UIMenuElement.State = .off, afterMenuDismissal: Bool = false,
                    perform: @escaping (Coordinator) -> Void) -> UIAction {
            UIAction(title: title, image: image, attributes: attributes, state: state) { [weak button, weak coordinator] _ in
                guard let coordinator else { return }
                if afterMenuDismissal {
                    button?.performAfterMenuDismissal { [weak coordinator] in
                        if let coordinator { perform(coordinator) }
                    }
                } else {
                    perform(coordinator)
                }
            }
        }

        func menuImage(_ name: String) -> UIImage? {
            let key = ImageKey(name: "system-\(name)", colorHex: theme.hex(for: scheme), scheme: scheme, scale: scale)
            return coordinator.image(for: key) {
                UIImage(systemName: name)?.withTintColor(UIColor(theme.color), renderingMode: .alwaysOriginal)
            }
        }

        func tagImage(_ tag: Tag) -> UIImage? {
            let key = ImageKey(name: tag.muscleIcon?.rawValue ?? "color-dot", colorHex: tag.colorHex,
                               scheme: scheme, scale: scale)
            return coordinator.image(for: key) {
                guard let icon = tag.muscleIcon else {
                    return UIImage(systemName: "circle.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 8))?
                        .withTintColor(UIColor(Color(hex: tag.colorHex)), renderingMode: .alwaysOriginal)
                }
                let renderer = ImageRenderer(content: MuscleIconView(icon: icon, color: Color(hex: tag.colorHex))
                    .frame(width: 24, height: 24).environment(\.colorScheme, scheme))
                renderer.scale = scale
                return renderer.uiImage?.withRenderingMode(.alwaysOriginal)
            }
        }

        var children: [UIMenuElement] = []
        if !tags.isEmpty {
            let options = tags.map { tag in
                let id = tag.persistentModelID
                return action(tag.name, image: tagImage(tag), state: id == selection ? .on : .off) {
                    if let tag = $0.tag(id) { $0.onChoose?(tag) }
                }
            }
            children.append(UIMenu(title: "Filter by Tag", options: .displayInline, children: options))
            let deselect = action("Deselect All Tags", image: menuImage("xmark.circle"),
                                  attributes: selection == nil ? .disabled : []) { $0.onDeselect?() }
            children.append(UIMenu(options: .displayInline, children: [deselect]))
        }

        var management: [UIMenuElement] = [action("Add Tag", image: menuImage("plus"), afterMenuDismissal: true) { $0.onAdd?() }]
        if !tags.isEmpty {
            management.append(UIMenu(title: "Edit Tag", image: menuImage("pencil"), children: tags.map { tag in
                let id = tag.persistentModelID
                return action(tag.name, afterMenuDismissal: true) { if let tag = $0.tag(id) { $0.onEdit?(tag) } }
            }))
            management.append(UIMenu(title: "Delete Tag", image: menuImage("trash"), children: tags.map { tag in
                let id = tag.persistentModelID
                return action(tag.name, attributes: .destructive, afterMenuDismissal: true) { if let tag = $0.tag(id) { $0.onDelete?(tag) } }
            }))
        }
        children.append(UIMenu(options: .displayInline, children: management))
        button.menu = UIMenu(children: children)
        coordinator.images = coordinator.images.filter { coordinator.usedImages.contains($0.key) }
    }

    fileprivate struct TagKey: Equatable {
        let id: PersistentIdentifier
        let name: String
        let colorHex: String
        let iconName: String?
    }

    fileprivate struct MenuKey: Equatable {
        let tags: [TagKey]
        let selection: PersistentIdentifier?
        let theme: ThemeColor
        let scheme: ColorScheme
        let scale: CGFloat
    }

    fileprivate struct ImageKey: Hashable {
        let name: String
        let colorHex: String
        let scheme: ColorScheme
        let scale: CGFloat
    }

    final class Coordinator {
        fileprivate var menuKey: MenuKey?
        fileprivate var images: [ImageKey: UIImage] = [:]
        fileprivate var usedImages: Set<ImageKey> = []
        fileprivate var tags: [Tag] = []
        fileprivate var onChoose: ((Tag) -> Void)?
        fileprivate var onDeselect: (() -> Void)?
        fileprivate var onAdd: (() -> Void)?
        fileprivate var onEdit: ((Tag) -> Void)?
        fileprivate var onDelete: ((Tag) -> Void)?

        fileprivate func tag(_ id: PersistentIdentifier) -> Tag? {
            tags.first { $0.persistentModelID == id }
        }

        fileprivate func image(for key: ImageKey, render: () -> UIImage?) -> UIImage? {
            usedImages.insert(key)
            if let cached = images[key] { return cached }
            let image = render()
            images[key] = image
            return image
        }
    }
}

final class TagWheelMenuButton: UIButton {
    private var menuIsPresented = false
    private var pendingAction: (() -> Void)?
    private var symbolColor: UIColor?

    override init(frame: CGRect) {
        super.init(frame: frame)
        var configuration = UIButton.Configuration.plain()
        configuration.contentInsets = .zero
        configuration.baseForegroundColor = .label
        configuration.image = UIImage(systemName: "tag")
        configuration.preferredSymbolConfigurationForImage = ExerciseToolbarStyle.symbolConfiguration
        self.configuration = configuration
        tintColor = .label
        showsMenuAsPrimaryAction = true
        preferredMenuElementOrder = .fixed
        accessibilityLabel = "Filter and Manage Tags"
        accessibilityIdentifier = "tag-management-menu"
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setSymbolColor(_ color: UIColor) {
        guard symbolColor != color else { return }
        symbolColor = color
        // Preserve the selected-filter indicator when the navigation bar applies its own tint.
        configuration?.image = UIImage(systemName: "tag", withConfiguration: ExerciseToolbarStyle.symbolConfiguration)?
            .withTintColor(color, renderingMode: .alwaysOriginal)
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
