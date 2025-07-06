import XCTest
@testable import Fathom

@available(iOS 14.0, *)
@MainActor
final class PersonalizationEngineTests: XCTestCase {

    var personalizationEngine: PersonalizationEngine!

    override func setUpWithError() async throws {
        try await super.setUpWithError()
        personalizationEngine = PersonalizationEngine.shared
        // NOTE: A proper reset of the singleton's state is crucial for test isolation.
        await personalizationEngine.resetForTesting()
        try await personalizationEngine.initialize()
    }

    override func tearDown() {
        personalizationEngine = nil
        super.tearDown()
    }

    func testInitialization() {
        XCTAssertTrue(personalizationEngine.isInitialized)
        XCTAssertEqual(personalizationEngine.userRole, .other)
        XCTAssertEqual(personalizationEngine.userIndustry, .other)
        XCTAssertEqual(personalizationEngine.insightComplexity, .basic)
    }

    func testSetUserProfile() async throws {
        try await personalizationEngine.setUserProfile(role: .developer, industry: .technology)
        XCTAssertEqual(personalizationEngine.userRole, .developer)
        XCTAssertEqual(personalizationEngine.userIndustry, .technology)
    }

    func testSetInsightComplexity() async throws {
        try await personalizationEngine.setInsightComplexity(to: .advanced)
        XCTAssertEqual(personalizationEngine.insightComplexity, .advanced)
    }

    func testRecordInteraction() async throws {
        let insightType = InsightType.suggestion
        
        let initialPreference = await personalizationEngine.getPreference(for: insightType)

        try await personalizationEngine.recordInteraction(for: insightType, action: .viewed)
        var preference = await personalizationEngine.getPreference(for: insightType)
        XCTAssertGreaterThan(preference.score, initialPreference.score, "Score should increase after viewing")

        let scoreAfterViewing = preference.score
        try await personalizationEngine.recordInteraction(for: insightType, action: .actionTaken)
        preference = await personalizationEngine.getPreference(for: insightType)
        XCTAssertGreaterThan(preference.score, scoreAfterViewing, "Score should increase after action")

        let scoreAfterAction = preference.score
        try await personalizationEngine.recordInteraction(for: insightType, action: .dismissed)
        preference = await personalizationEngine.getPreference(for: insightType)
        XCTAssertLessThan(preference.score, scoreAfterAction, "Score should decrease after dismissing")
    }

    func testEvaluateContextualTriggers() async throws {
        // Setup a high-stress check-in
        let checkInData = WorkplaceCheckInData(
            id: UUID(),
            timestamp: Date(),
            stressLevel: 5,
            focusLevel: 2,
            energyLevel: 2,
            progress: "High stress test",
            sentimentScore: -0.9
        )

        // The engine should evaluate this and identify a trigger
        let triggeredNotification = await personalizationEngine.evaluateContextualTriggers(for: checkInData)
        
        XCTAssertNotNil(triggeredNotification, "A notification should be triggered for high stress")
        XCTAssertEqual(triggeredNotification?.title, "Mindful Moment Suggested")
    }
}
