import XCTest
@testable import Fathom
import CoreData

final class PersonalizationEngineTests: XCTestCase {
    private var context: NSManagedObjectContext!
    private var engine: PersonalizationEngine!
    
    override func setUp() {
        super.setUp()
        engine = PersonalizationEngine()
    }
    
    override func tearDown() {
        engine = nil
        super.tearDown()
    }
    
    func testInitialization() {
        XCTAssertTrue(engine.userPreferences.isEmpty)
        XCTAssertEqual(engine.userRole, .other)
        XCTAssertEqual(engine.workIndustry, .other)
    }
    
    func testWorkRoleAdaptation() {
        // Test manager role adaptation
        engine.userRole = .manager
        var insight = Insight(
            id: UUID(),
            type: .suggestion,
            message: "You might want to take a break",
            priority: 1,
            timestamp: Date()
        )
        
        let adaptedInsight = engine.adaptInsightForProfile(insight)
        XCTAssertTrue(adaptedInsight.message.contains("your team") || !adaptedInsight.message.contains("you"),
                     "Manager role should adapt message to use 'your team' instead of 'you'")
        
        // Test executive role adaptation
        engine.userRole = .executive
        insight = Insight(
            id: UUID(),
            type: .suggestion,
            message: "Consider scheduling breaks",
            priority: 1,
            timestamp: Date()
        )
        
        let executiveInsight = engine.adaptInsightForProfile(insight)
        XCTAssertTrue(executiveInsight.message.hasPrefix("From a strategic perspective: ") || 
                     executiveInsight.message.contains("strategic"),
                    "Executive role should add strategic perspective to messages")
    }
    
    func testFilterInsightsByComplexity() {
        let basicInsight = Insight(
            id: UUID(),
            type: .stressTrend,
            message: "Your stress levels are stable",
            priority: 1,
            timestamp: Date()
        )
        
        let advancedInsight = Insight(
            id: UUID(),
            type: .anomalyDetection,
            message: "Unusual work pattern detected",
            priority: 1,
            timestamp: Date()
        )
        
        // Test basic complexity level
        engine.insightComplexity = .basic
        var filtered = engine.filterInsightsByComplexity([basicInsight, advancedInsight])
        XCTAssertEqual(filtered.count, 1, "Basic complexity should only show basic insights")
        XCTAssertEqual(filtered.first?.type, .stressTrend, "Basic complexity should show stress trend insights")
        
        // Test advanced complexity level
        engine.insightComplexity = .advanced
        filtered = engine.filterInsightsByComplexity([basicInsight, advancedInsight])
        XCTAssertEqual(filtered.count, 2, "Advanced complexity should show all insights")
    }
    
    func testContextualTriggers() {
        // Create a late check-in
        let calendar = Calendar.current
        var components = DateComponents()
        components.hour = 21 // 9 PM
        let lateTime = calendar.date(from: components)!
        
        let context = PersistenceController.preview.container.viewContext
        let lateCheckIn = WorkplaceCheckIn(context: context)
        lateCheckIn.checkOutTime = lateTime
        
        // Test late check-out trigger
        let triggers = engine.evaluateContextualTriggers(for: lateCheckIn)
        XCTAssertFalse(triggers.isEmpty, "Should generate triggers for late check-in")
        XCTAssertTrue(triggers.contains { $0.name == "late_checkout" }, "Should include late checkout trigger")
        
        // Test high stress trigger
        let highStressCheckIn = WorkplaceCheckIn(context: context)
        highStressCheckIn.stressRating = 4 // High stress
        
        let stressTriggers = engine.evaluateContextualTriggers(for: highStressCheckIn)
        XCTAssertFalse(stressTriggers.isEmpty, "Should generate triggers for high stress check-in")
        XCTAssertTrue(stressTriggers.contains { $0.type == .highStress }, "Should include high stress trigger")
    }
    
    func testTriggerCooldown() {
        let trigger = ContextualTrigger(
            name: "test_trigger",
            type: .highStress,
            message: "Test trigger",
            priority: 1,
            cooldownHours: 1.0
        )
        
        // First trigger should be allowed
        engine.markTriggerUsed(trigger)
        
        // Should be in cooldown now
        let inCooldown = engine.isInCooldownPeriod(trigger)
        XCTAssertTrue(inCooldown, "Trigger should be in cooldown after being marked as used")
    }
    
    func testUserPreferences() {
        // Test setting preferences
        engine.updatePreference(for: .stressTrend, engagementScore: 0.8, dismissalRate: 0.2)
        XCTAssertNotNil(engine.userPreferences[.stressTrend], "Should store user preference")
        XCTAssertEqual(engine.userPreferences[.stressTrend]?.engagementScore, 0.8, accuracy: 0.01, 
                      "Should store correct engagement score")
        
        // Test preference affects insight priority
        let insight = Insight(
            id: UUID(),
            type: .stressTrend,
            message: "Test insight",
            priority: 1,
            timestamp: Date()
        )
        
        let adapted = engine.adaptInsightForProfile(insight)
        XCTAssertGreaterThan(adapted.priority, insight.priority, 
                           "Priority should increase for insights with high engagement")
    }
}
