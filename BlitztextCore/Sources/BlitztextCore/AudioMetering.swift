import Foundation

/// Pure audio-metering math, separated from AVFoundation so it can be unit-tested.
public enum AudioMetering {
    /// Maps a peak power level in decibels (typically about -50...0) to a clamped 0...1 display level.
    public static func normalizedLevel(powerDecibels power: Float) -> Float {
        max(0, min(1, (power + 50) / 50))
    }
}
