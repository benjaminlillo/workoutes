import SwiftUI
import UIKit

/// A fixed metal end cap. The wheel's gesture handles dragging; the reflections stay still.
struct TagWheelGrip: UIViewRepresentable {
    func makeUIView(context: Context) -> TagWheelGripView { TagWheelGripView() }
    func updateUIView(_ view: TagWheelGripView, context: Context) {}
}

final class TagWheelGripView: UIView {
    private let bevel = CAGradientLayer()
    private let face = CAGradientLayer()
    private let machining = CAShapeLayer()
    private let lip = CAShapeLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        accessibilityIdentifier = "tag-wheel-grip"

        func silver(_ value: CGFloat) -> CGColor {
            UIColor(red: value * 0.98, green: value * 0.99, blue: value, alpha: 1).cgColor
        }
        bevel.colors = [silver(1), silver(0.68), silver(0.95), silver(0.52)]
        bevel.locations = [0, 0.42, 0.65, 1]
        bevel.startPoint = CGPoint(x: 0.15, y: 0)
        bevel.endPoint = CGPoint(x: 0.85, y: 1)
        layer.addSublayer(bevel)

        // Alternating, broad reflections give the circular face a turned-steel finish.
        face.type = .conic
        face.colors = [silver(0.92), silver(0.70), silver(0.96), silver(0.79),
                       silver(0.98), silver(0.72), silver(0.94), silver(0.92)]
        face.locations = [0, 0.15, 0.30, 0.47, 0.58, 0.75, 0.91, 1]
        face.startPoint = CGPoint(x: 0.5, y: 0.5)
        face.endPoint = CGPoint(x: 1, y: 0)
        face.masksToBounds = true
        layer.addSublayer(face)

        machining.fillColor = nil
        machining.strokeColor = UIColor(white: 0.25, alpha: 0.07).cgColor
        machining.lineWidth = 0.3
        layer.addSublayer(machining)

        lip.fillColor = nil
        lip.strokeColor = UIColor(white: 1, alpha: 0.65).cgColor
        lip.lineWidth = 0.65
        layer.addSublayer(lip)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Resizing the wheel must not trigger independent Core Animation transitions.
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        bevel.frame = bounds
        bevel.cornerRadius = min(bounds.width, bounds.height) / 2
        face.frame = bounds.insetBy(dx: 2, dy: 2)
        face.cornerRadius = min(face.bounds.width, face.bounds.height) / 2

        let rings = UIBezierPath()
        for inset in stride(from: CGFloat(4), through: min(bounds.width, bounds.height) / 2 - 2, by: 2) {
            rings.append(UIBezierPath(ovalIn: bounds.insetBy(dx: inset, dy: inset)))
        }
        machining.frame = bounds
        machining.path = rings.cgPath
        lip.frame = bounds
        lip.path = UIBezierPath(ovalIn: bounds.insetBy(dx: 2.3, dy: 2.3)).cgPath
        CATransaction.commit()
    }
}
