//
//  FocusTimerView 2.swift
//  Fathom
//
//  Created by Paul Thomas on 6/10/25.
//


import SwiftUI
import ActivityKit
import Combine
#if canImport(UIKit)
import UIKit
#endif

@available(iOS 16.1, *)
struct FocusTimerView: View {
    @State private var timeRemaining = 1500 // 25 minutes (in seconds)
    @State private var isTimerRunning = false
    @State private var activity: Activity<FathomActivityAttributes>? = nil
    @State private var endDate: Date? = nil // Drives accurate countdown
    @State private var totalDuration = 1500 // Track full session seconds
    @State private var selectedMinutes: Int = 25

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var progress: Double {
        guard totalDuration > 0 else { return 0 }
        return max(0, min(1, Double(timeRemaining) / Double(totalDuration)))
    }

    var body: some View {
        let ringSize: CGFloat = 260
        VStack(spacing: 28) {
            Text("Focus Timer")
                .font(.largeTitle.weight(.bold))
                .padding(.top, 8)

            // Circular progress ring with animated countdown
            ZStack {
                // Track
                Circle()
                    .stroke(Color.secondary.opacity(0.15), style: StrokeStyle(lineWidth: 18))
                // Progress
                Circle()
                    .trim(from: 0, to: CGFloat(max(0.001, progress)))
                    .stroke(
                        AngularGradient(
                            gradient: Gradient(colors: [Color.blue, Color.purple, Color.blue]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 18, lineCap: .round, lineJoin: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.25), value: progress)

                VStack(spacing: 6) {
                    Text(timeString(time: timeRemaining))
                        .font(.system(size: 64, weight: .semibold, design: .monospaced))
                        .monospacedDigit()
                        .foregroundColor(.primary)
                        .accessibilityLabel("Time remaining")
                        .accessibilityValue(timeString(time: timeRemaining))
                    Text("remaining")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: ringSize, height: ringSize)
            .padding(.vertical, 4)
            
            // Controls
            HStack(spacing: 24) {
                Button(action: toggleTimer) {
                    Image(systemName: isTimerRunning ? "pause.fill" : "play.fill")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 64, height: 64)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .clipShape(Circle())
                        .shadow(color: Color.purple.opacity(0.25), radius: 12, y: 6)
                }
                .buttonStyle(.plain)

                Button(action: resetTimer) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 52, height: 52)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            // Duration presets
            VStack(alignment: .leading, spacing: 8) {
                Picker("Duration", selection: $selectedMinutes) {
                    Text("15m").tag(15)
                    Text("25m").tag(25)
                    Text("50m").tag(50)
                }
                .pickerStyle(.segmented)
                .disabled(isTimerRunning)
                .onChange(of: selectedMinutes) { newValue in
                    if !isTimerRunning { applyDuration(minutes: newValue) }
                }
                if isTimerRunning {
                    Text("Pause to change duration")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
        }
        .onReceive(timer) { _ in
            guard isTimerRunning else { return }
            if let end = endDate {
                let remaining = max(0, Int(end.timeIntervalSinceNow.rounded(.down)))
                if remaining != timeRemaining { // avoid redundant updates
                    timeRemaining = remaining
                    updateActivity()
                }
                if remaining <= 0 {
                    endSession()
                }
            }
        }
    }
    
    private func timeString(time: Int) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format:"%02i:%02i", minutes, seconds)
    }
    
    // MARK: - Live Activity Logic
    
    private func toggleTimer() {
        if isTimerRunning {
            // Currently running -> pause
            // Capture latest remaining based on endDate and stop the clock
            if let end = endDate {
                let remaining = max(0, Int(end.timeIntervalSinceNow.rounded(.down)))
                timeRemaining = remaining
            }
            isTimerRunning = false
            endDate = nil
            updateActivity() // reflect paused state
            haptic(.soft)
        } else {
            // Currently paused/stopped -> start/resume
            if endDate == nil {
                endDate = Date().addingTimeInterval(TimeInterval(timeRemaining))
            }
            isTimerRunning = true
            startActivity()
            haptic(.rigid)
        }
    }

    private func resetTimer() {
        // End any active session and reset back to preset duration
        endSession()
        isTimerRunning = false
        endDate = nil
        timeRemaining = totalDuration
        haptic(.light)
    }

    private func startActivity() {
        let attributes = FathomActivityAttributes(sessionName: "Work Focus")
        let initialState = FathomActivityAttributes.ContentState(
            timeRemaining: timeString(time: timeRemaining),
            sessionState: .focused
        )
        
        if activity == nil {
            let content = ActivityContent(state: initialState, staleDate: nil)
            do {
                activity = try Activity<FathomActivityAttributes>.request(
                    attributes: attributes,
                    content: content,
                    pushType: nil
                )
            } catch {
                print("Error requesting Live Activity: \(error.localizedDescription)")
            }
        } else {
            updateActivity()
        }
    }

    private func updateActivity() {
        let state = FathomActivityAttributes.ContentState(
            timeRemaining: timeString(time: timeRemaining),
            sessionState: isTimerRunning ? .focused : .paused
        )
        let activity = self.activity // capture before Task
        Task {
            await activity?.update(using: state)
        }
    }

    private func endSession() {
        let finalState = FathomActivityAttributes.ContentState(
            timeRemaining: "Done!",
            sessionState: .paused
        )
        let content = ActivityContent(state: finalState, staleDate: nil)
        let activity = self.activity // capture before Task
        Task {
            await activity?.end(content, dismissalPolicy: .immediate)
        }
        // Keep UI at 00:00 while Live Activity says "Done!"
        isTimerRunning = false
        endDate = nil
        timeRemaining = 0
        haptic(.heavy)
    }

    private func applyDuration(minutes: Int) {
        totalDuration = max(1, minutes * 60)
        timeRemaining = totalDuration
        endDate = nil
        updateActivity()
    }

    // MARK: - Haptics
    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }
}
