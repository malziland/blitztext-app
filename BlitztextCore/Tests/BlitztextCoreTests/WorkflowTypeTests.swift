import XCTest
import BlitztextCore

final class WorkflowTypeTests: XCTestCase {
    func testAllCasesCount() {
        XCTAssertEqual(WorkflowType.allCases.count, 3)
    }

    func testMainMenuExcludesLocalTranscription() {
        XCTAssertFalse(WorkflowType.mainMenuCases.contains(.localTranscription))
        XCTAssertEqual(WorkflowType.mainMenuCases.count, 2)
    }

    func testDisplayNames() {
        XCTAssertEqual(WorkflowType.transcription.displayName, "Blitztext")
        XCTAssertEqual(WorkflowType.textImprover.displayName, "Blitztext+")
    }

    func testCodableRoundTrip() throws {
        for type in WorkflowType.allCases {
            let data = try JSONEncoder().encode(type)
            let decoded = try JSONDecoder().decode(WorkflowType.self, from: data)
            XCTAssertEqual(decoded, type)
        }
    }

    func testPhaseIsActive() {
        XCTAssertFalse(WorkflowPhase.idle.isActive)
        XCTAssertTrue(WorkflowPhase.running("rec").isActive)
        XCTAssertTrue(WorkflowPhase.done("ok").isActive)
        XCTAssertTrue(WorkflowPhase.error("x").isActive)
    }

}
