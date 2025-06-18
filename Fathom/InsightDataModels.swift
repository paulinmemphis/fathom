import Foundation

/// A `Sendable` struct to pass workplace check-in data across actor boundaries safely.
struct CheckInData: Sendable {
    let focusLevel: Double
    let stressLevel: Double
    let timestamp: Date
    let workplaceName: String?
    let sessionDuration: Int32
    let sessionNote: String?

    init(from checkIn: WorkplaceCheckIn) {
        self.focusLevel = checkIn.focusLevel
        self.stressLevel = checkIn.stressLevel
        self.timestamp = checkIn.timestamp ?? Date()
        self.workplaceName = checkIn.workplace?.name
        self.sessionDuration = Int32(checkIn.sessionDuration)
        self.sessionNote = checkIn.sessionNote
    }
}

/// A `Sendable` struct to pass breathing exercise data across actor boundaries safely.
struct BreathingData: Sendable {
    let duration: Int32
    let timestamp: Date
    
    init(from log: BreathingExercise) {
        self.duration = Int32(log.duration)
        self.timestamp = log.completedAt ?? Date()
    }
}
