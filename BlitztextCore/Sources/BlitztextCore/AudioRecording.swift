import Foundation

/// Platform-agnostic recording interface the workflows depend on, so they can be
/// driven by a real AVFoundation recorder in the app and by a fake one in tests.
@MainActor
public protocol AudioRecording: AnyObject {
    var isRecording: Bool { get }
    var recordingURL: URL? { get }
    var errorMessage: String? { get }
    var lastRecordingDuration: TimeInterval { get }
    var maximumAudioLevel: Float { get }
    var audioLevel: Float { get }
    var inputDeviceName: String? { get }

    func startRecording(audioInputDeviceID: String?)
    func stopRecording() async
    func cancelRecording()
    func discardRecording()
}
