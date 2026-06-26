import XCTest
@testable import BlitztextCore

final class TranscriptFormatterTests: XCTestCase {
    func testCapitalizesFirstLetterAndSentenceStarts() {
        let result = TranscriptFormatter.format("hallo welt. das ist ein test! und noch einer?")
        XCTAssertEqual(result, "Hallo welt. Das ist ein test! Und noch einer?")
    }

    func testCollapsesWhitespaceAndStripsSpaceBeforePunctuation() {
        let result = TranscriptFormatter.format("hallo   welt  ,   wie geht es  ?")
        XCTAssertEqual(result, "Hallo welt, wie geht es?")
    }

    func testNeueZeileBecomesLineBreakAndCapitalizesNextLine() {
        let result = TranscriptFormatter.format("erste zeile neue zeile zweite zeile")
        XCTAssertEqual(result, "Erste zeile\nZweite zeile")
    }

    func testNeuerAbsatzBecomesParagraph() {
        let result = TranscriptFormatter.format("ende des absatzes neuer absatz start des naechsten")
        XCTAssertEqual(result, "Ende des absatzes\n\nStart des naechsten")
    }

    func testSpokenPunctuationCommands() {
        let result = TranscriptFormatter.format("stimmt das fragezeichen ja ausrufezeichen")
        XCTAssertEqual(result, "Stimmt das? Ja!")
    }

    func testSpokenCommandsAreCaseInsensitive() {
        let result = TranscriptFormatter.format("zeile eins Neue Zeile zeile zwei")
        XCTAssertEqual(result, "Zeile eins\nZeile zwei")
    }

    func testPunktAndKommaWordsAreLeftUntouched() {
        // "Punkt"/"Komma" are content words too often; the offline pass must not
        // turn them into punctuation. (The online pass handles them in context.)
        let result = TranscriptFormatter.format("das bringt es auf den punkt")
        XCTAssertEqual(result, "Das bringt es auf den punkt")
    }

    func testCollapsesExcessiveBlankLines() {
        let result = TranscriptFormatter.format("a neuer absatz neuer absatz b")
        XCTAssertEqual(result, "A\n\nB")
    }

    func testTrimsLeadingAndTrailingWhitespace() {
        let result = TranscriptFormatter.format("   hallo welt   ")
        XCTAssertEqual(result, "Hallo welt")
    }

    func testEmptyStringStaysEmpty() {
        XCTAssertEqual(TranscriptFormatter.format("   "), "")
    }

    func testIsIdempotentOnAlreadyCleanText() {
        let once = TranscriptFormatter.format("Hallo welt. Das ist ein test.")
        let twice = TranscriptFormatter.format(once)
        XCTAssertEqual(once, twice)
    }

    // MARK: - Plausibility guard

    func testPlausibleReformattingAcceptsAReformat() {
        XCTAssertTrue(TranscriptFormatter.isPlausibleReformatting(
            original: "hallo welt das ist ein test",
            formatted: "Hallo Welt, das ist ein Test."
        ))
    }

    func testPlausibleReformattingAcceptsCommandShortening() {
        // The formatter legitimately drops spoken command words.
        XCTAssertTrue(TranscriptFormatter.isPlausibleReformatting(
            original: "sag mal neue zeile bitte",
            formatted: "Sag mal\nBitte"
        ))
    }

    func testPlausibleReformattingRejectsExplosion() {
        XCTAssertFalse(TranscriptFormatter.isPlausibleReformatting(
            original: "ja",
            formatted: "Hier ist der formatierte Text, den du angefragt hast, in mehreren Saetzen."
        ))
    }

    func testPlausibleReformattingRejectsEmpty() {
        XCTAssertFalse(TranscriptFormatter.isPlausibleReformatting(original: "hallo welt", formatted: "   "))
    }

    func testTrivialForOnlineFormatting() {
        XCTAssertTrue(TranscriptFormatter.isTrivialForOnlineFormatting("ja danke"))
        XCTAssertTrue(TranscriptFormatter.isTrivialForOnlineFormatting("eins zwei drei"))
        XCTAssertFalse(TranscriptFormatter.isTrivialForOnlineFormatting("das sind jetzt vier woerter"))
    }
}
