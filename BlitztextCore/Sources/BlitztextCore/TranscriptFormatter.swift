import Foundation

/// Deterministic, fully offline transcript formatting.
///
/// Whisper (and especially the small on-device models) returns a continuous run
/// of text with weak punctuation and no paragraph structure. This formatter
/// improves the "shape" of a transcript without any network call:
///
/// - turns spoken formatting commands into real breaks / punctuation
///   ("neue Zeile" → line break, "neuer Absatz" → paragraph,
///    "Fragezeichen"/"Ausrufezeichen"/"Doppelpunkt" → the punctuation mark),
/// - normalizes whitespace and the spacing around punctuation,
/// - capitalizes the first letter of every sentence and line.
///
/// It is intentionally conservative: it never adds, removes, translates or
/// rephrases words. German noun capitalization is *not* attempted — that needs
/// a language model and is handled by the online formatting pass instead.
/// Because it is pure, it is used directly for the on-device (local) backend and
/// as a fallback when the online formatting pass fails.
public enum TranscriptFormatter {
    /// A spoken command and the literal it expands to.
    private struct Command {
        let pattern: String      // case-insensitive, ASCII word-bounded
        let replacement: String
    }

    /// Multi-word structural commands are listed before single words so the more
    /// specific phrase wins. Single-word punctuation commands are deliberately
    /// limited to words that are rarely meant literally mid-sentence; "Punkt" and
    /// "Komma" are intentionally excluded here (too many false positives) and are
    /// left to the online pass.
    private static let commands: [Command] = [
        Command(pattern: #"[ \t]*\bneuer (absatz|abschnitt)\b[ \t]*"#, replacement: "\n\n"),
        Command(pattern: #"[ \t]*\bneue zeile\b[ \t]*"#, replacement: "\n"),
        Command(pattern: #"[ \t]*\bzeilenumbruch\b[ \t]*"#, replacement: "\n"),
        Command(pattern: #"[ \t]*\bfragezeichen\b"#, replacement: "?"),
        Command(pattern: #"[ \t]*\bausrufezeichen\b"#, replacement: "!"),
        Command(pattern: #"[ \t]*\bdoppelpunkt\b"#, replacement: ":"),
    ]

    public static func format(_ text: String) -> String {
        var result = text
        result = applySpokenCommands(result)
        result = normalizeWhitespace(result)
        result = capitalizeSentenceStarts(result)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A sanity check on the online formatting pass: the result must look like a
    /// reformatted version of the input, not a rewrite, an appended explanation,
    /// or a refusal. It compares alphanumeric content length (case, punctuation
    /// and whitespace stripped). Formatting may legitimately *drop* a few spoken
    /// command words, so only the upper bound is enforced — a substantially
    /// longer result means the model added content and is rejected.
    public static func isPlausibleReformatting(original: String, formatted: String) -> Bool {
        let originalLength = contentLength(original)
        let formattedLength = contentLength(formatted)

        guard formattedLength > 0 else { return false }
        guard originalLength > 0 else { return true }

        // Pure formatting never adds alphanumeric content (case/punctuation
        // changes don't count, spoken-command words only get removed). A clearly
        // longer result means the model rewrote, explained or refused.
        let upperBound = Double(originalLength) * 1.2 + 10
        return Double(formattedLength) <= upperBound
    }

    /// Very short utterances ("ja danke") gain little from an LLM formatting
    /// call; the offline formatter (capitalization) is enough and avoids the
    /// extra network round-trip and cost.
    public static func isTrivialForOnlineFormatting(_ text: String) -> Bool {
        text.split { $0.isWhitespace }.count <= 3
    }

    private static func contentLength(_ text: String) -> Int {
        text.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) }.count
    }

    // MARK: - Steps

    static func applySpokenCommands(_ text: String) -> String {
        var result = text
        for command in commands {
            result = result.replacingOccurrences(
                of: command.pattern,
                with: command.replacement,
                options: [.regularExpression, .caseInsensitive]
            )
        }
        return result
    }

    static func normalizeWhitespace(_ text: String) -> String {
        var result = text
        // Collapse runs of spaces/tabs (newlines are preserved).
        result = result.replacingOccurrences(of: #"[ \t]+"#, with: " ", options: .regularExpression)
        // Drop a space sitting in front of closing punctuation.
        result = result.replacingOccurrences(of: #" +([.,;:!?])"#, with: "$1", options: .regularExpression)
        // Trim spaces/tabs hugging a line break.
        result = result.replacingOccurrences(of: #"[ \t]*\n[ \t]*"#, with: "\n", options: .regularExpression)
        // At most one blank line between paragraphs.
        result = result.replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
        return result
    }

    static func capitalizeSentenceStarts(_ text: String) -> String {
        var result = ""
        result.reserveCapacity(text.count)
        var atSentenceStart = true

        for character in text {
            if atSentenceStart, character.isLetter {
                result.append(contentsOf: character.uppercased())
                atSentenceStart = false
            } else {
                result.append(character)
                if character.isLetter || character.isNumber {
                    atSentenceStart = false
                } else if character == "." || character == "!" || character == "?" || character == "\n" {
                    atSentenceStart = true
                }
                // Spaces and inner punctuation (",", ";", ":") leave the flag untouched.
            }
        }

        return result
    }
}
