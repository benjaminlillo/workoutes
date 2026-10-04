import Observation
import UIKit

@MainActor
protocol AppIconUpdating {
    var supportsAlternateIcons: Bool { get }
    var alternateIconName: String? { get }
    func setAlternateIconName(_ name: String?) async throws
}

extension UIApplication: AppIconUpdating {}

@MainActor
@Observable
final class ThemeIconController {
    var errorMessage: String?
    private let application: any AppIconUpdating
    private var pendingTheme: ThemeColor?
    private var isUpdating = false

    init(application: (any AppIconUpdating)? = nil) {
        self.application = application ?? UIApplication.shared
    }

    func update(for theme: ThemeColor) async {
        errorMessage = nil
        pendingTheme = theme
        guard !isUpdating else { return }
        isUpdating = true
        defer { isUpdating = false }

        // Serialize requests so a quick second selection becomes the final icon.
        while let theme = pendingTheme {
            pendingTheme = nil
            guard application.supportsAlternateIcons else { return }
            let name = theme.alternateIconName
            guard application.alternateIconName != name else { continue }
            do {
                try await application.setAlternateIconName(name)
                errorMessage = nil
            } catch {
                if pendingTheme == nil {
                    errorMessage = "Your theme was applied, but its app icon couldn't be changed. \(error.localizedDescription)"
                }
            }
        }
    }
}
