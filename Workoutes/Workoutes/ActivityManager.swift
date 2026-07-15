import Foundation
import ActivityKit
import SwiftUI
import SwiftData

@Observable
class ActivityManager {
    static let shared = ActivityManager()
    
    var currentActivity: Activity<ExerciseAttributes>?
    
    private init() {}
    
    func startActivity(for exercise: WorkoutExercise) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            print("Live Activities are not enabled.")
            return
        }
        
        // End any existing activity first
        endActivity()
        
        let attributes = ExerciseAttributes(
            exerciseID: exercise.persistentModelID.hashValue.description,
            title: exercise.title,
            subtitle: exercise.subtitle
        )
        
        let initialContentState = ExerciseAttributes.ContentState(
            isDone: exercise.isDone,
            weight: exercise.weight,
            reps: exercise.reps,
            sets: exercise.numberOfSets
        )
        
        do {
            if #available(iOS 16.2, *) {
                let activityContent = ActivityContent(state: initialContentState, staleDate: nil)
                currentActivity = try Activity.request(attributes: attributes, content: activityContent)
            } else {
                currentActivity = try Activity.request(attributes: attributes, contentState: initialContentState)
            }
            print("Live Activity started successfully. ID: \(currentActivity?.id ?? "nil")")
            
            Task {
                try await Task.sleep(nanoseconds: 3_000_000_000)
                if let state = currentActivity?.activityState {
                    print("3 seconds later, activity state is: \(state)")
                } else {
                    print("3 seconds later, activity is nil")
                }
            }
        } catch {
            print("Error starting Live Activity: \(error.localizedDescription)")
        }
    }
    
    func updateActivity(for exercise: WorkoutExercise) {
        guard let activity = currentActivity else { return }
        
        let updatedContentState = ExerciseAttributes.ContentState(
            isDone: exercise.isDone,
            weight: exercise.weight,
            reps: exercise.reps,
            sets: exercise.numberOfSets
        )
        
        Task {
            if #available(iOS 16.2, *) {
                let activityContent = ActivityContent(state: updatedContentState, staleDate: nil)
                await activity.update(activityContent)
            } else {
                await activity.update(using: updatedContentState)
            }
        }
    }
    
    func endActivity() {
        guard let activity = currentActivity else {
            // Failsafe: End all activities
            Task {
                for act in Activity<ExerciseAttributes>.activities {
                    if #available(iOS 16.2, *) {
                        let finalContent = ActivityContent(state: act.content.state, staleDate: nil)
                        await act.end(finalContent, dismissalPolicy: .immediate)
                    } else {
                        await act.end(using: act.content.state, dismissalPolicy: .immediate)
                    }
                }
            }
            return
        }
        
        Task {
            if #available(iOS 16.2, *) {
                let finalContent = ActivityContent(state: activity.content.state, staleDate: nil)
                await activity.end(finalContent, dismissalPolicy: .immediate)
            } else {
                await activity.end(using: activity.content.state, dismissalPolicy: .immediate)
            }
            currentActivity = nil
        }
    }
}
