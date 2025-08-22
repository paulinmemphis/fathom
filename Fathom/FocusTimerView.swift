//
//  FocusTimerView 2.swift
//  Fathom
//
//  Created by Paul Thomas on 6/10/25.
//


import SwiftUI
import ActivityKit
import Combine

@available(iOS 16.1, *)
struct FocusTimerView: View {
    @State private var timeRemaining = 1500 // 25 minutes
    @State private var isTimerRunning = false
    @State private var activity: Activity<FathomActivityAttributes>? = nil

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 30) {
            Text("Focus Timer")
                .font(.largeTitle.weight(.bold))
            
            Text(timeString(time: timeRemaining))
                .font(.system(size: 80, weight: .thin, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding()
                .background(.ultraThinMaterial)
                .clipShape(Circle())
            
            HStack(spacing: 20) {
                Button(action: toggleTimer) {
                    Image(systemName: isTimerRunning ? "pause.fill" : "play.fill")
                        .font(.largeTitle)
                }
                
                Button(action: resetTimer) {
                    Image(systemName: "arrow.clockwise")
                        .font(.largeTitle)
                }
            }
        }
        .onReceive(timer) { _ in
            guard isTimerRunning else { return }
            if timeRemaining > 0 {
                timeRemaining -= 1
                updateActivity()
            } else {
                endSession()
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
        isTimerRunning.toggle()
        if isTimerRunning {
            startActivity()
        } else {
            updateActivity() // Update to show "Paused"
        }
    }

    private func resetTimer() {
        endSession()
        isTimerRunning = false
        timeRemaining = 1500
    }

    private func startActivity() {
        let attributes = FathomActivityAttributes(sessionName: "Work Focus")
        let initialState = FathomActivityAttributes.ContentState(
            timeRemaining: timeString(time: timeRemaining),
            sessionState: .focused
        )
        
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
        isTimerRunning = false
    }
}
