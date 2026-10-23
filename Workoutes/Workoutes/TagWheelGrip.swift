import SwiftUI
import UIKit

/// A fixed, opaque grip. The wheel's gesture handles dragging; this view has no button actions.
struct TagWheelGrip: UIViewRepresentable {
    func makeUIView(context: Context) -> TagWheelGripView { TagWheelGripView() }
    func updateUIView(_ view: TagWheelGripView, context: Context) {}
}

final class TagWheelGripView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .secondarySystemGroupedBackground
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        accessibilityIdentifier = "tag-wheel-grip"

        let grooves = UIStackView()
        grooves.axis = .vertical
        grooves.spacing = 4
        grooves.distribution = .fillEqually
        for _ in 0..<3 {
            let line = UIView()
            line.backgroundColor = .tertiaryLabel
            line.layer.cornerRadius = 1
            grooves.addArrangedSubview(line)
        }
        grooves.translatesAutoresizingMaskIntoConstraints = false
        addSubview(grooves)
        NSLayoutConstraint.activate([
            grooves.centerXAnchor.constraint(equalTo: centerXAnchor),
            grooves.centerYAnchor.constraint(equalTo: centerYAnchor),
            grooves.widthAnchor.constraint(equalToConstant: 20),
            grooves.heightAnchor.constraint(equalToConstant: 14)
        ])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = min(bounds.width, bounds.height) / 2
    }
}
