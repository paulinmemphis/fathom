//
//  UserGoal.swift
//  Fathom
//
//  Created by Cascade on $(DATE).
//

import Foundation
import Combine

enum GoalCategory: String, CaseIterable {
    case productivity = "Productivity"
    case wellness = "Wellness"
    case workLifeBalance = "Work-Life Balance"
    case focus = "Focus"
    case stress = "Stress Management"
}

enum GoalType: String, CaseIterable {
    case dailyWorkHours = "Daily Work Hours"
    case weeklyBreathingMinutes = "Weekly Breathing Minutes"
    case dailyFocusScore = "Daily Focus Score"
    case weeklyStressReduction = "Weekly Stress Reduction"
    case reflectionFrequency = "Reflection Frequency"
}

struct UserGoal: Identifiable {
    let id = UUID()
    let type: GoalType
    let category: GoalCategory
    let title: String
    let description: String
    let targetValue: Double
    let currentValue: Double
    let unit: String
    let isActive: Bool
    let createdAt: Date
    let targetDate: Date?
    
    var progress: Double {
        guard targetValue > 0 else { return 0 }
        return min(currentValue / targetValue, 1.0)
    }
    
    var isCompleted: Bool {
        return progress >= 1.0
    }
}

@MainActor
class UserGoalsManager: ObservableObject {
    nonisolated(unsafe) static let shared = UserGoalsManager()
    
    @Published var goals: [UserGoal] = []
    
    nonisolated private init() {
        Task { @MainActor in
            loadDefaultGoals()
        }
    }
    
    private func loadDefaultGoals() {
        goals = [
            UserGoal(
                type: .dailyWorkHours,
                category: .workLifeBalance,
                title: "Healthy Work Hours",
                description: "Maintain 6-8 productive work hours per day",
                targetValue: 7.0,
                currentValue: 0,
                unit: "hours",
                isActive: true,
                createdAt: Date(),
                targetDate: nil
            ),
            UserGoal(
                type: .weeklyBreathingMinutes,
                category: .wellness,
                title: "Weekly Breathing Practice",
                description: "Complete 30 minutes of breathing exercises per week",
                targetValue: 30.0,
                currentValue: 0,
                unit: "minutes",
                isActive: true,
                createdAt: Date(),
                targetDate: nil
            ),
            UserGoal(
                type: .dailyFocusScore,
                category: .focus,
                title: "Daily Focus Target",
                description: "Maintain an average focus score of 4+ out of 5",
                targetValue: 4.0,
                currentValue: 0,
                unit: "score",
                isActive: true,
                createdAt: Date(),
                targetDate: nil
            )
        ]
    }
    
    func updateGoalProgress(type: GoalType, value: Double) {
        if let index = goals.firstIndex(where: { $0.type == type && $0.isActive }) {
            let updatedGoal = UserGoal(
                type: goals[index].type,
                category: goals[index].category,
                title: goals[index].title,
                description: goals[index].description,
                targetValue: goals[index].targetValue,
                currentValue: value,
                unit: goals[index].unit,
                isActive: goals[index].isActive,
                createdAt: goals[index].createdAt,
                targetDate: goals[index].targetDate
            )
            goals[index] = updatedGoal
        }
    }
}
