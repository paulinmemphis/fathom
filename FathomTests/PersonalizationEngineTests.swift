import XCTest
@testable import Fathom

@available(iOS 14.0, *)
final class PersonalizationEngineTests: XCTestCase {

    override func setUpWithError() throws {
        // No-op. Use MainActor.run in each test method to access PersonalizationEngine.shared.
    }

    override func tearDown() {
        super.tearDown()
    }

    func testInitialization() async {
        let engine = await MainActor.run { PersonalizationEngine.shared }
        let isInitialized = await MainActor.run { engine.isInitialized }
        let userRole = await MainActor.run { engine.userRole }
        let userIndustry = await MainActor.run { engine.userIndustry }
        let insightComplexity = await MainActor.run { engine.insightComplexity }
        XCTAssertTrue(isInitialized)
        XCTAssertEqual(userRole, .other)
        XCTAssertEqual(userIndustry, .other)
        XCTAssertEqual(insightComplexity, .basic)
    }

    func testSetUserProfile() async throws {
        let engine = await MainActor.run { PersonalizationEngine.shared }
        try await engine.setUserProfile(role: .developer, industry: .technology)
        let userRole = await MainActor.run { engine.userRole }
        let userIndustry = await MainActor.run { engine.userIndustry }
        XCTAssertEqual(userRole, .developer)
        XCTAssertEqual(userIndustry, .technology)
    }

    func testSetInsightComplexity() async throws {
        let engine = await MainActor.run { PersonalizationEngine.shared }
        try await MainActor.run { try engine.setInsightComplexity(.advanced) }
        let insightComplexity = await MainActor.run { engine.insightComplexity }
        XCTAssertEqual(insightComplexity, .advanced)
    }

    func testRecordInteraction() async throws {
        let engine = await MainActor.run { PersonalizationEngine.shared }
        let insightType = InsightType.suggestion

        try await MainActor.run { try engine.recordInteraction(for: insightType, action: .viewed) }
        try await MainActor.run { try engine.recordInteraction(for: insightType, action: .actionTaken) }
        try await MainActor.run { try engine.recordInteraction(for: insightType, action: .dismissed) }
    }

    func testEvaluateContextualTriggers() async throws {
        let engine = await MainActor.run { PersonalizationEngine.shared }
        // Setup a high-stress check-in
        let checkInData = WorkplaceCheckInData(
            id: UUID(),
            timestamp: Date(),
            stressLevel: 1.0,
            focusLevel: 0.2,
            sessionDuration: 0
        )

        // The engine should evaluate this and identify a trigger
        let triggeredTriggers = await MainActor.run { engine.evaluateContextualTriggers(for: checkInData) }
        XCTAssertFalse(triggeredTriggers.isEmpty, "A trigger should be returned for high stress")
        let hasHighStress = triggeredTriggers.contains { $0.name == "High Stress Detection" }
        XCTAssertTrue(hasHighStress, "High Stress Detection trigger should be present")
    }
}
