import AVFoundation

struct AudioInputDevice: Identifiable, Equatable {
    let id: String
    let name: String
    let isDefault: Bool

    var displayName: String {
        isDefault ? "\(name) (Standard)" : name
    }
}

enum AudioInputDeviceService {
    static let systemDefaultDeviceID = "__system_default__"

    static func availableDevices() -> [AudioInputDevice] {
        let defaultDeviceID = AVCaptureDevice.default(for: .audio)?.uniqueID
        var devicesByID: [String: AVCaptureDevice] = [:]

        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )
        for device in discoverySession.devices {
            devicesByID[device.uniqueID] = device
        }

        for device in AVCaptureDevice.devices(for: .audio) {
            devicesByID[device.uniqueID] = device
        }

        return devicesByID.values
            .sorted { first, second in
                if first.uniqueID == defaultDeviceID { return true }
                if second.uniqueID == defaultDeviceID { return false }
                return first.localizedName.localizedCaseInsensitiveCompare(second.localizedName) == .orderedAscending
            }
            .map { device in
                AudioInputDevice(
                    id: device.uniqueID,
                    name: device.localizedName,
                    isDefault: device.uniqueID == defaultDeviceID
                )
            }
    }

    static func device(for selectedDeviceID: String?) -> AVCaptureDevice? {
        if let selectedDeviceID,
           selectedDeviceID != systemDefaultDeviceID,
           let selectedDevice = AVCaptureDevice(uniqueID: selectedDeviceID) {
            return selectedDevice
        }

        return AVCaptureDevice.default(for: .audio) ?? AVCaptureDevice.devices(for: .audio).first
    }

    static func displayName(for selectedDeviceID: String?) -> String {
        guard let device = device(for: selectedDeviceID) else {
            return "kein Mikrofon"
        }

        return device.localizedName
    }
}
