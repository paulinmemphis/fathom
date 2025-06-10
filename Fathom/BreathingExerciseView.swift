import SwiftUI
import CoreData

struct BreathingExerciseView: View {
    @Environment(\.managedObjectContext) private var viewContext

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
                Button(action: stopExercise) {
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
        animatePhase()
    }
    
    private func stopExercise(completedSuccessfully: Bool = false) {
        isRunning = false
        timer?.invalidate()
        timer = nil

        if completedSuccessfully {
            logCompletedExercise()
        }

        breathCount = 0
        phase = .inhale
        circleScale = 1.0
    }

    private func logCompletedExercise() {
        let newLog = BreathingExerciseLog(context: viewContext)
        newLog.timestamp = Date()
        newLog.breathsCompleted = Int16(totalBreaths) // Assuming totalBreaths is the intended value

        do {
            try viewContext.save()
            print("Breathing exercise logged successfully.")
        } catch {
            // Replace this implementation with code to handle the error appropriately.
            // fatalError() causes the application to generate a crash log and terminate.
            // You should not use this function in a shipping application, although it may be useful during development.
            let nsError = error as NSError
            print("Unresolved error \(nsError), \(nsError.userInfo)")
            // For now, we'll just print the error. Consider more robust error handling.
        }
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
                stopExercise(completedSuccessfully: true)
                return
            }
            phase = .inhale
        }
        animatePhase()
    }
}

