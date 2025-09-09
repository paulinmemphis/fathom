//
//  FocusTimerView 2.swift
//  Fathom
//
//  Created by Paul Thomas on 6/10/25.
//


import SwiftUI
import ActivityKit
import Combine
import CoreData
#if canImport(UIKit)
import UIKit
#endif

@available(iOS 16.1, *)
struct FocusTimerView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var timeRemaining = 1500 // 25 minutes (in seconds)
    @State private var isTimerRunning = false
    @State private var activity: Activity<FathomActivityAttributes>? = nil
    @State private var endDate: Date? = nil // Drives accurate countdown
    @State private var totalDuration = 1500 // Track full session seconds
    @State private var selectedMinutes: Int = 25
    @StateObject private var userStatsManager = UserStatsManager.shared
    @State private var showCelebration = false
    @State private var isReflectionPresented = false
    @State private var reflectionCheckIn: Fathom.WorkplaceCheckIn? = nil

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
        .sheet(isPresented: $isReflectionPresented) {
            if let checkIn = reflectionCheckIn {
                WorkSessionReflectionView(checkIn: checkIn)
                    .environment(\.managedObjectContext, viewContext)
            } else {
                Text("Great session!")
            }
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

            // Streak summary and gentle nudge
            VStack(spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill").foregroundColor(.orange)
                    Text("Streak: \(userStatsManager.currentWorkSessionStreak) day\(userStatsManager.currentWorkSessionStreak == 1 ? "" : "s")")
                        .font(.headline)
                    Spacer()
                    Text("Best: \(userStatsManager.longestWorkSessionStreak)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                if !isTimerRunning && timeRemaining == totalDuration {
                    Text(userStatsManager.currentWorkSessionStreak > 0 ? "Keep the chain going today." : "Start a 25m session to begin your streak.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
            }
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
        .overlay(alignment: .top) {
            if showCelebration {
                celebrationBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 8)
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
            AnalyticsService.shared.logEvent("focus_timer_pause", parameters: [
                "remaining_sec": timeRemaining,
                "total_sec": totalDuration
            ])
        } else {
            // Currently paused/stopped -> start/resume
            if endDate == nil {
                endDate = Date().addingTimeInterval(TimeInterval(timeRemaining))
            }
            isTimerRunning = true
            startActivity()
            haptic(.rigid)
            AnalyticsService.shared.logEvent("focus_timer_start", parameters: [
                "remaining_sec": timeRemaining,
                "total_sec": totalDuration
            ])
        }
    }

    private func resetTimer() {
        // End any active session and reset back to preset duration
        endSession()
        isTimerRunning = false
        endDate = nil
        timeRemaining = totalDuration
        haptic(.light)
        AnalyticsService.shared.logEvent("focus_timer_reset", parameters: [
            "total_sec": totalDuration
        ])
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

        // Habit-forming hooks: log session, schedule nudge, celebrate, analytics
        UserStatsManager.shared.logWorkSessionCompleted()
        NotificationManager.shared.scheduleProactiveInsight(
            title: "Keep your focus streak going",
            body: "Great job today! Schedule another 25m session tomorrow to keep the chain alive."
        )
        AnalyticsService.shared.logEvent("focus_timer_complete", parameters: [
            "planned_sec": totalDuration,
            "completed": true
        ])
        celebrateCompletion()
        // No need for today's streak saver anymore
        NotificationManager.shared.cancelStreakSaver()

        // Create a Core Data check-in record for reflection
        let checkIn = WorkplaceCheckIn(context: viewContext)
        checkIn.id = UUID()
        checkIn.checkOutTime = Date()
        // Approximate start based on selected/planned duration
        checkIn.checkInTime = Date().addingTimeInterval(-TimeInterval(totalDuration))
        checkIn.notes = "Focus Timer session"
        do {
            try viewContext.save()
            reflectionCheckIn = checkIn
            isReflectionPresented = true
        } catch {
            print("Failed to save focus session check-in: \(error)")
        }
    }

    private func applyDuration(minutes: Int) {
        totalDuration = max(1, minutes * 60)
        timeRemaining = totalDuration
        endDate = nil
        updateActivity()
        AnalyticsService.shared.logEvent("focus_timer_set_duration", parameters: [
            "minutes": minutes
        ])
    }

    // MARK: - Haptics
    private func haptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        #if canImport(UIKit)
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
        #endif
    }

    // MARK: - Celebration UI
    private var celebrationBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles")
                .foregroundColor(.yellow)
            VStack(alignment: .leading, spacing: 2) {
                Text("Nice work! Session complete")
                    .font(.headline)
                Text("Streak: \(userStatsManager.currentWorkSessionStreak) • Best: \(userStatsManager.longestWorkSessionStreak)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.15), radius: 10, y: 4)
        .padding(.horizontal)
    }

    private func celebrateCompletion() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            showCelebration = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation(.easeOut(duration: 0.3)) {
                showCelebration = false
            }
        }
    }
}
