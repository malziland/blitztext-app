import XCTest
@testable import Blitztext

final class AudioRecorderCleanupTests: XCTestCase {
    func testSweepRemovesOnlyBlitztextRecordings() throws {
        let fileManager = FileManager.default
        let directory = fileManager.temporaryDirectory
            .appendingPathComponent("blitztext-tests-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: directory) }

        let orphanA = directory.appendingPathComponent("\(AudioRecorder.temporaryRecordingPrefix)\(UUID().uuidString).m4a")
        let orphanB = directory.appendingPathComponent("\(AudioRecorder.temporaryRecordingPrefix)\(UUID().uuidString).wav")
        let unrelatedDoc = directory.appendingPathComponent("notes.txt")
        let unrelatedAudio = directory.appendingPathComponent("recording.m4a")

        for url in [orphanA, orphanB, unrelatedDoc, unrelatedAudio] {
            try Data("x".utf8).write(to: url)
        }

        AudioRecorder.cleanupOrphanedRecordings(in: directory)

        XCTAssertFalse(fileManager.fileExists(atPath: orphanA.path))
        XCTAssertFalse(fileManager.fileExists(atPath: orphanB.path))
        XCTAssertTrue(fileManager.fileExists(atPath: unrelatedDoc.path))
        XCTAssertTrue(fileManager.fileExists(atPath: unrelatedAudio.path))
    }
}
