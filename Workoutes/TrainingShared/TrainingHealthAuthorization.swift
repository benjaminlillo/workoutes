import HealthKit

enum TrainingHealthAuthorization {
    static var writeTypes: Set<HKSampleType> {
        [HKObjectType.workoutType(), HKQuantityType(.activeEnergyBurned),
         HKQuantityType(.basalEnergyBurned), HKQuantityType(.workoutEffortScore)]
    }

    static var readTypes: Set<HKObjectType> {
        [HKObjectType.workoutType(), HKQuantityType(.heartRate), HKQuantityType(.activeEnergyBurned),
         HKQuantityType(.basalEnergyBurned), HKQuantityType(.heartRateRecoveryOneMinute),
         HKQuantityType(.workoutEffortScore)]
    }

    enum Failure: LocalizedError {
        case unavailable, notDetermined, denied

        var errorDescription: String? {
            switch self {
            case .unavailable:
                "Health is unavailable on this device."
            case .notDetermined:
                "Health permission hasn't been completed. Open Workoutes on your iPhone, start training, and allow it to save Workouts in the Health permission screen."
            case .denied:
                "Workoutes can't save workouts to Health. On your iPhone, open Health → your profile → Apps → Workoutes and enable Workouts under Allow Workoutes to Write. Then try starting again."
            }
        }
    }

    static func check(_ status: HKAuthorizationStatus) throws {
        switch status {
        case .sharingAuthorized: return
        case .sharingDenied: throw Failure.denied
        case .notDetermined: throw Failure.notDetermined
        @unknown default: throw Failure.notDetermined
        }
    }

    @MainActor
    static func request(using store: HKHealthStore) async throws {
        guard HKHealthStore.isHealthDataAvailable() else { throw Failure.unavailable }
        // Completion means the sheet was handled, not that the user granted access.
        try await store.requestAuthorization(toShare: writeTypes, read: readTypes)
        #if DEBUG
        let requestStatus = try? await store.statusForAuthorizationRequest(toShare: writeTypes, read: readTypes)
        NSLog("Training Health authorization: request=%ld, workoutWrite=%ld",
              requestStatus?.rawValue ?? -1, store.authorizationStatus(for: HKObjectType.workoutType()).rawValue)
        #endif
        try check(store.authorizationStatus(for: HKObjectType.workoutType()))
    }
}
