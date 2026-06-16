import XCTest
@testable import Blitztext

final class WorkflowTypeTests: XCTestCase {
    func testAllCasesCount() {
        XCTAssertEqual(WorkflowType.allCases.count, 5)
    }

    func testMainMenuExcludesLocalTranscription() {
        XCTAssertFalse(WorkflowType.mainMenuCases.contains(.localTranscription))
        XCTAssertEqual(WorkflowType.mainMenuCases.count, 4)
    }

    func testDisplayNames() {
        XCTAssertEqual(WorkflowType.dampfAblassen.displayName, "Blitztext $%&!")
        XCTAssertEqual(WorkflowType.transcription.displayName, "Blitztext")
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

    func testLaunchSourcePresentsPage() {
        XCTAssertTrue(WorkflowLaunchSource.manual.presentsWorkflowPage)
        XCTAssertFalse(WorkflowLaunchSource.hotkeyBackground.presentsWorkflowPage)
    }
}
