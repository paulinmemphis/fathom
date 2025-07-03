import XCTest
@testable import Fathom
import CoreData

final class PersonalizationEngineTests: XCTestCase {
    
    private var engine: PersonalizationEngine!

    override func setUp() async throws {
        try await super.setUp()
        engine = PersonalizationEngine.shared
        await engine.initialize()
    }

    override func tearDown() async throws {
        engine = nil
        try await super.tearDown()
    }

    func testInitialization() async {
        let role = await engine.getCurrentUserRole()
        let industry = await engine.getCurrentUserIndustry()
        let complexity = await engine.getCurrentInsightComplexity()
        
        XCTAssertEqual(role, .other)
        XCTAssertEqual(industry, .other)
        XCTAssertEqual(complexity, .basic)
    }

    func testUpdateUserProfile() async {
        // Test updating user role
        await engine.updateUserRole(.developer)
        var currentRole = await engine.getCurrentUserRole()
        XCTAssertEqual(currentRole, .developer)

        // Test updating user industry
        await engine.updateUserIndustry(.technology)
        var currentIndustry = await engine.getCurrentUserIndustry()
        XCTAssertEqual(currentIndustry, .technology)

        // Test updating insight complexity
        await engine.updateInsightComplexity(.advanced)
        var currentComplexity = await engine.getCurrentInsightComplexity()
        XCTAssertEqual(currentComplexity, .advanced)
    }
    
    func testUserInteractionTracking() async {
        let insightType = InsightType.trend
        
        // Ensure preference is at default state
        var initialPref = await engine.getPreference(for: insightType)
        XCTAssertEqual(initialPref.viewCount, 0)
        XCTAssertEqual(initialPref.dismissalCount, 0)
        XCTAssertEqual(initialPref.actionCount, 0)

        // Simulate user viewing the insight
        await engine.trackInteraction(for: insightType, action: .viewed)
        var afterViewPref = await engine.getPreference(for: insightType)
        XCTAssertEqual(afterViewPref.viewCount, 1)

        // Simulate user taking action
        await engine.trackInteraction(for: insightType, action: .actionTaken)
        var afterActionPref = await engine.getPreference(for: insightType)
        XCTAssertEqual(afterActionPref.actionCount, 1)

        // Simulate user dismissing the insight
        await engine.trackInteraction(for: insightType, action: .dismissed)
        var afterDismissalPref = await engine.getPreference(for: insightType)
        XCTAssertEqual(afterDismissalPref.dismissalCount, 1)
    }
    
    func testContextualTriggerProcessing() async {
        let context = PersistenceController.preview.container.viewContext
        let checkIn = WorkplaceCheckIn(context: context)
        checkIn.stressRating = 4.5 // High stress
        checkIn.checkOutTime = Date()
        checkIn.checkInTime = Date().addingTimeInterval(-3600)

        let notificationContext = NotificationContext(stressLevel: checkIn.stressRating)
        
        // Get the trigger we expect to fire
        let triggers = await engine.getContextualTriggers()
        guard let highStressTrigger = triggers.first(where: { $0.type == .highStress }) else {
            XCTFail("High stress trigger not found in default set.")
            return
        }
        
        // Ensure it hasn't been triggered recently
        XCTAssertTrue(highStressTrigger.canTrigger, "Expected trigger to be available.")

        // Process the check-in
        await engine.processCheckInForContextualTriggers(checkIn: checkIn, with: notificationContext)
        
        // Verify that the trigger's lastTriggered date has been updated
        let updatedTriggers = await engine.getContextualTriggers()
        guard let updatedHighStressTrigger = updatedTriggers.first(where: { $0.id == highStressTrigger.id }) else {
            XCTFail("High stress trigger not found after processing.")
            return
        }
        
        XCTAssertNotNil(updatedHighStressTrigger.lastTriggered, "lastTriggered date should be set after firing.")
        XCTAssertFalse(updatedHighStressTrigger.canTrigger, "Trigger should be on cooldown after firing.")
    }
}
