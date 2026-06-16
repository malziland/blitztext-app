import AVFoundation
import Observation
import BlitztextCore

@Observable
@MainActor
final class AudioRecorder: NSObject, AVCaptureFileOutputRecordingDelegate, AudioRecording {
    var isRecording = false
    var recordingURL: URL?
    var errorMessage: String?
    var audioLevel: Float = 0
    var maximumAudioLevel: Float = 0
    var lastRecordingDuration: TimeInterval = 0
    var inputDeviceName: String?

    private var captureSession: AVCaptureSession?
    private var audioOutput: AVCaptureAudioFileOutput?
    private var levelTimer: Timer?
    private var currentFileURL: URL?
    private var recordingStartDate: Date?
    private var stopContinuation: CheckedContinuation<Void, Never>?
    private var discardCurrentRecording = false

    /// Filename prefix for every temporary recording, so orphans can be swept on launch.
    nonisolated static let temporaryRecordingPrefix = "blitztext-"

    private func makeRecordingURL(fileExtension: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("\(Self.temporaryRecordingPrefix)\(UUID().uuidString).\(fileExtension)")
    }

    /// Removes recordings left in the shared temporary directory by a previous run
    /// that was hard-killed before its per-workflow cleanup ran (defense in depth for
    /// the `defer`-based deletion). Best effort and safe to call at launch.
    nonisolated static func cleanupOrphanedRecordings(in directory: URL = FileManager.default.temporaryDirectory) {
        guard let entries = try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }

        for url in entries where url.lastPathComponent.hasPrefix(temporaryRecordingPrefix) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    func startRecording(audioInputDeviceID: String?) {
        errorMessage = nil
        lastRecordingDuration = 0
        maximumAudioLevel = 0
        recordingURL = nil
        inputDeviceName = nil
        discardCurrentRecording = false
        if let currentFileURL {
            try? FileManager.default.removeItem(at: currentFileURL)
        }
        currentFileURL = nil

        guard AVCaptureDevice.authorizationStatus(for: .audio) != .denied else {
            errorMessage = "Mikrofon-Zugriff ist fuer Blitztext nicht freigegeben."
            return
        }

        guard let device = AudioInputDeviceService.device(for: audioInputDeviceID) else {
            errorMessage = "Kein Mikrofon gefunden. Pruefe Systemeinstellungen > Ton > Eingabe."
            return
        }

        inputDeviceName = device.localizedName
        let outputFileType = Self.preferredOutputFileType()
        let fileURL = makeRecordingURL(fileExtension: Self.fileExtension(for: outputFileType))

        do {
            let session = AVCaptureSession()
            let input = try AVCaptureDeviceInput(device: device)
            let output = AVCaptureAudioFileOutput()
            output.audioSettings = Self.audioSettings(for: outputFileType)

            session.beginConfiguration()
            if session.canSetSessionPreset(.high) {
                session.sessionPreset = .high
            }

            guard session.canAddInput(input) else {
                session.commitConfiguration()
                errorMessage = "Mikrofon \"\(device.localizedName)\" kann nicht verwendet werden."
                return
            }

            guard session.canAddOutput(output) else {
                session.commitConfiguration()
                errorMessage = "Audio-Ausgabe konnte fuer \"\(device.localizedName)\" nicht erstellt werden."
                return
            }

            session.addInput(input)
            session.addOutput(output)
            session.commitConfiguration()

            currentFileURL = fileURL
            captureSession = session
            audioOutput = output

            session.startRunning()
            guard session.isRunning else {
                cleanupCaptureSession()
                currentFileURL = nil
                try? FileManager.default.removeItem(at: fileURL)
                errorMessage = "Aufnahme konnte nicht gestartet werden. Pruefe Mikrofon \"\(device.localizedName)\"."
                return
            }

            output.startRecording(to: fileURL, outputFileType: outputFileType, recordingDelegate: self)
            recordingStartDate = Date()
            isRecording = true
            startMetering()
        } catch {
            currentFileURL = nil
            cleanupCaptureSession()
            errorMessage = "Aufnahme konnte nicht gestartet werden: \(error.localizedDescription)"
        }
    }

    func stopRecording() async {
        stopMetering()
        isRecording = false
        lastRecordingDuration = currentRecordingDuration()

        guard let output = audioOutput else {
            recordingURL = currentFileURL
            currentFileURL = nil
            cleanupCaptureSession()
            audioLevel = 0
            return
        }

        if output.isRecording {
            await withCheckedContinuation { continuation in
                stopContinuation = continuation
                output.stopRecording()
                scheduleStopFallback()
            }
        } else {
            recordingURL = currentFileURL
        }

        currentFileURL = nil
        cleanupCaptureSession()
        audioLevel = 0
    }

    func cancelRecording() {
        stopMetering()
        discardCurrentRecording = true
        isRecording = false
        lastRecordingDuration = currentRecordingDuration()

        if audioOutput?.isRecording == true {
            audioOutput?.stopRecording()
        } else if let currentFileURL {
            try? FileManager.default.removeItem(at: currentFileURL)
            self.currentFileURL = nil
        }

        cleanupCaptureSession()
        audioLevel = 0
        stopContinuation?.resume()
        stopContinuation = nil
    }

    func discardRecording() {
        if let recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
            self.recordingURL = nil
        }

        if let currentFileURL {
            try? FileManager.default.removeItem(at: currentFileURL)
            self.currentFileURL = nil
        }
    }

    private func startMetering() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateMetering()
            }
        }
    }

    private func stopMetering() {
        levelTimer?.invalidate()
        levelTimer = nil
    }

    private func updateMetering() {
        let channels = audioOutput?.connections.flatMap(\.audioChannels) ?? []
        let power = channels.map(\.peakHoldLevel).max() ?? -160
        let normalized = AudioMetering.normalizedLevel(powerDecibels: power)
        audioLevel = normalized
        maximumAudioLevel = max(maximumAudioLevel, normalized)
        lastRecordingDuration = currentRecordingDuration()
    }

    private func currentRecordingDuration() -> TimeInterval {
        if let output = audioOutput {
            let seconds = CMTimeGetSeconds(output.recordedDuration)
            if seconds.isFinite, seconds > 0 {
                return seconds
            }
        }

        if let recordingStartDate {
            return Date().timeIntervalSince(recordingStartDate)
        }

        return 0
    }

    private func cleanupCaptureSession() {
        captureSession?.stopRunning()
        captureSession = nil
        audioOutput = nil
        recordingStartDate = nil
    }

    private func scheduleStopFallback() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            Task { @MainActor in
                guard let self, self.stopContinuation != nil else { return }
                // The recording delegate did not finalize the file within the
                // timeout. The capture output may still be writing, so the file is
                // not safe to transcribe. Surface an error and discard the partial
                // file instead of handing it off; a late delegate callback then
                // takes the discard branch and removes it as well.
                self.discardCurrentRecording = true
                if let url = self.currentFileURL {
                    try? FileManager.default.removeItem(at: url)
                }
                self.recordingURL = nil
                self.errorMessage = "Aufnahme konnte nicht rechtzeitig abgeschlossen werden. Bitte erneut versuchen."
                self.stopContinuation?.resume()
                self.stopContinuation = nil
            }
        }
    }

    private static func preferredOutputFileType() -> AVFileType {
        let availableTypes = AVCaptureAudioFileOutput.availableOutputFileTypes()
        if availableTypes.contains(.m4a) {
            return .m4a
        }
        if availableTypes.contains(.wav) {
            return .wav
        }
        return availableTypes.first ?? .m4a
    }

    private static func fileExtension(for fileType: AVFileType) -> String {
        switch fileType {
        case .wav:
            return "wav"
        case .mp3:
            return "mp3"
        default:
            return "m4a"
        }
    }

    private static func audioSettings(for fileType: AVFileType) -> [String: Any] {
        if fileType == .wav {
            return [
                AVFormatIDKey: Int(kAudioFormatLinearPCM),
                AVSampleRateKey: 16000,
                AVNumberOfChannelsKey: 1,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false,
            ]
        }

        return [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 16000,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]
    }

    // MARK: - AVCaptureFileOutputRecordingDelegate

    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        Task { @MainActor in
            if self.discardCurrentRecording {
                try? FileManager.default.removeItem(at: outputFileURL)
                self.recordingURL = nil
                self.discardCurrentRecording = false
            } else if let error {
                try? FileManager.default.removeItem(at: outputFileURL)
                self.recordingURL = nil
                self.errorMessage = "Aufnahme fehlgeschlagen: \(error.localizedDescription)"
            } else {
                self.recordingURL = outputFileURL
            }

            self.stopContinuation?.resume()
            self.stopContinuation = nil
        }
    }
}
