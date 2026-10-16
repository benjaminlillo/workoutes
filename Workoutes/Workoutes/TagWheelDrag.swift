import Foundation

/// Radial drags are ignored; only tangential motion rotates the tag selector.
nonisolated struct TagWheelDrag {
    enum Intent { case undecided, rotation, radial }

    private(set) var intent = Intent.undecided

    mutating func update(start: CGPoint, location: CGPoint, center: CGPoint) {
        let radius = hypot(start.x - center.x, start.y - center.y)
        // Taps and small drags on the axle belong to its native menu.
        guard radius > 42 else { return }
        let inwardX = (center.x - start.x) / radius
        let inwardY = (center.y - start.y) / radius
        let dx = location.x - start.x
        let dy = location.y - start.y
        let radialDistance = abs(dx * inwardX + dy * inwardY)
        guard intent == .undecided else { return }
        let tangentialDistance = abs(dx * inwardY - dy * inwardX)
        if radialDistance >= 8 && radialDistance > tangentialDistance * 1.25 {
            intent = .radial
        } else if tangentialDistance >= 8 {
            intent = .rotation
        }
    }
}
