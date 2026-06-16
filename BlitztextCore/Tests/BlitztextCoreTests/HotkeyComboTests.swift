import XCTest
import BlitztextCore

final class HotkeyComboTests: XCTestCase {
    func testEachComboMapsToItsWorkflow() {
        XCTAssertEqual(HotkeyCombo.workflowType(for: [.function, .shift, .control]), .localTranscription)
        XCTAssertEqual(HotkeyCombo.workflowType(for: [.function, .shift]), .transcription)
        XCTAssertEqual(HotkeyCombo.workflowType(for: [.function, .control]), .textImprover)
    }

    func testFunctionAloneEmptyAndRemovedCombosReturnNil() {
        XCTAssertNil(HotkeyCombo.workflowType(for: [.function]))
        XCTAssertNil(HotkeyCombo.workflowType(for: []))
        XCTAssertNil(HotkeyCombo.workflowType(for: [.shift]))
        XCTAssertNil(HotkeyCombo.workflowType(for: [.command]))
        XCTAssertNil(HotkeyCombo.workflowType(for: [.function, .option]))   // removed workflow
        XCTAssertNil(HotkeyCombo.workflowType(for: [.function, .command]))  // removed workflow
    }

    func testMoreSpecificComboWins() {
        // fn+shift+control must resolve to local transcription, not the fn+shift transcription.
        XCTAssertEqual(HotkeyCombo.workflowType(for: [.function, .shift, .control]), .localTranscription)
        // A superset that still contains fn+shift+control stays local transcription.
        XCTAssertEqual(HotkeyCombo.workflowType(for: [.function, .shift, .control, .command]), .localTranscription)
    }
}
