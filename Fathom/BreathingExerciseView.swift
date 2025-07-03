import SwiftUI
import CoreData

struct BreathingExerciseView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @StateObject private var userStatsManager = UserStatsManager.shared

    enum BreathingPhase: String {
        case inhale = "Inhale"
        case hold = "Hold"
        case exhale = "Exhale"
    }
    
    @State private var isRunning = false
    @State private var breathCount = 0
    @State private var timer: Timer? = nil
    @State private var phase: BreathingPhase = .inhale
    @State private var phaseProgress: Double = 0.0
    @State private var circleScale: CGFloat = 1.0
    @State private var sessionStartTime: Date?

    // Customize durations (in seconds)
    let inhaleDuration: Double = 4
    let holdDuration: Double = 4
    let exhaleDuration: Double = 6
    let totalBreaths: Int = 5
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            ZStack {
                Circle()
                    .fill(phase == .inhale ? Color.blue.opacity(0.5) : phase == .hold ? Color.green.opacity(0.5) : Color.purple.opacity(0.5))
                    .frame(width: 220, height: 220)
                    .scaleEffect(circleScale)
                    .animation(.easeInOut(duration: currentPhaseDuration()), value: circleScale)
                Text(phase.rawValue)
                    .font(.largeTitle)
                    .bold()
                    .foregroundColor(.white)
            }
            
            Text("Breath \(breathCount + (isRunning ? 1 : 0)) of \(totalBreaths)")
                .font(.title2)
                .foregroundColor(.secondary)
            
            if !isRunning {
                Button(action: startExercise) {
                    Text("Start")
                        .font(.title2)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding(.horizontal, 40)
                }
            } else {
                Button(action: { stopExercise() }) {
                    Text("Stop")
                        .font(.title2)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding(.horizontal, 40)
                }
            }
            Spacer()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }
    
    private func currentPhaseDuration() -> Double {
        switch phase {
        case .inhale: return inhaleDuration
        case .hold: return holdDuration
        case .exhale: return exhaleDuration
        }
    }
    
    private func startExercise() {
        isRunning = true
        breathCount = 0
        phase = .inhale
        sessionStartTime = Date()
        animatePhase()
    }
    
    private func stopExercise() {
        isRunning = false
        timer?.invalidate()
        timer = nil

        // Save completed breathing exercise session if we completed at least one breath
        if breathCount > 0, let startTime = sessionStartTime {
            let newExercise = BreathingExercise(context: viewContext)
            newExercise.id = UUID()
            newExercise.completedAt = Date()
            newExercise.duration = Date().timeIntervalSince(startTime)
            newExercise.totalBreaths = Int16(breathCount)
            newExercise.exerciseTypes = "4-4-6 Breathing" // Current breathing pattern
            newExercise.userRating = 0 // Could be expanded to ask user for rating
            
            do {
                try viewContext.save()
                // Update user stats after successful save
                userStatsManager.logBreathingExercise()
            } catch {
                print("Failed to save breathing exercise: \(error)")
            }
        }

        breathCount = 0
        phase = .inhale
        circleScale = 1.0
        sessionStartTime = nil
    }

    private func animatePhase() {
        guard isRunning else { return }
        withAnimation(.easeInOut(duration: currentPhaseDuration())) {
            switch phase {
            case .inhale:
                circleScale = 1.35
            case .hold:
                circleScale = 1.35
            case .exhale:
                circleScale = 1.0
            }
        }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: currentPhaseDuration(), repeats: false) { _ in
            DispatchQueue.main.async {
                nextPhase()
            }
        }
    }
    
    private func nextPhase() {
        guard isRunning else { return }
        switch phase {
        case .inhale:
            phase = .hold
        case .hold:
            phase = .exhale
        case .exhale:
            breathCount += 1
            if breathCount >= totalBreaths {
                stopExercise()
                return
            }
            phase = .inhale
        }
        animatePhase()
    }
}
