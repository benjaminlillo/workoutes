import Foundation
import UIKit
import UserNotifications

@MainActor
final class SessionNotificationManager: NSObject {
    static let shared = SessionNotificationManager()
    static let categoryIdentifier = "FLEXIBLE_SESSION_REST"
    static let nextActionIdentifier = "FLEXIBLE_SESSION_NEXT"

    func configure() {
        let action = UNNotificationAction(
            identifier: Self.nextActionIdentifier,
            title: "Next Block",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [action],
            intentIdentifiers: []
        )
        let center = UNUserNotificationCenter.current()
        center.setNotificationCategories([category])
        center.delegate = SessionNotificationDelegate.shared
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .notDetermined:
            return (try? await center.requestAuthorization(options: [.alert, .sound])) == true
        default:
            return false
        }
    }

    func scheduleRestEnd(sessionID: UUID, blockID: UUID, blockName: String, at date: Date) async -> Bool {
        guard await requestAuthorizationIfNeeded() else { return false }
        cancel(blockID: blockID)
        let content = UNMutableNotificationContent()
        content.title = "Rest finished"
        content.body = "\(blockName) is complete. Continue with the next block."
        content.sound = .default
        content.categoryIdentifier = Self.categoryIdentifier
        content.userInfo = ["sessionID": sessionID.uuidString, "blockID": blockID.uuidString]
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(1, date.timeIntervalSinceNow),
            repeats: false
        )
        let request = UNNotificationRequest(identifier: identifier(for: blockID), content: content, trigger: trigger)
        do {
            try await UNUserNotificationCenter.current().add(request)
            return true
        } catch {
            return false
        }
    }

    func cancel(blockID: UUID) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier(for: blockID)])
    }

    private func identifier(for blockID: UUID) -> String { "session-rest-\(blockID.uuidString)" }
}

final class SessionNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = SessionNotificationDelegate()

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        []
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier == SessionNotificationManager.nextActionIdentifier,
              let sessionValue = response.notification.request.content.userInfo["sessionID"] as? String,
              let blockValue = response.notification.request.content.userInfo["blockID"] as? String,
              let sessionID = UUID(uuidString: sessionValue),
              let blockID = UUID(uuidString: blockValue) else { return }
        await MainActor.run {
            ExerciseActivityRuntime.shared.sessionController.advance(
                expectedSessionID: sessionID,
                expectedBlockID: blockID
            )
        }
    }
}

final class WorkoutesAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        Task { @MainActor in SessionNotificationManager.shared.configure() }
        return true
    }
}
