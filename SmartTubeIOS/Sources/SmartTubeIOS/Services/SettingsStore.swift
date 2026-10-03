import Foundation
import OSLog
import Observation
import SmartTubeIOSCore

private let settingsLog = Logger(subsystem: appSubsystem, category: "Settings")

// MARK: - SettingsStore
//
// Persists `AppSettings` in `UserDefaults` and notifies observers via
// `@Observable`.  Used as an `@Environment` value throughout the app.

@MainActor
@Observable
public final class SettingsStore {

    public var settings: AppSettings {
        didSet {
            if self.settings.hideShorts != oldValue.hideShorts {
                settingsLog.notice(
                    "hideShorts \(oldValue.hideShorts ? "ON" : "OFF", privacy: .public) → \(self.settings.hideShorts ? "ON" : "OFF", privacy: .public)"
                )
            }
            self.save()
        }
    }

    /// Test override for the embedded player. Normal iOS playback uses AVPlayer.
    /// This is never persisted; embedded-player suites opt in with
    /// `--uitesting-enable-tos-player-on-ios`. Has no effect on macOS or tvOS.
    public var useTOSPlayerOnIOS: Bool = false

    private static let key = "smarttube_app_settings"
    private static let backgroundAudioMigrationKey = "smarttube_background_audio_default_v1"

    public init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
            let decoded = try? JSONDecoder().decode(AppSettings.self, from: data)
        {
            self.settings = decoded
        } else {
            self.settings = AppSettings()
        }
        #if os(iOS)
        // Enable lock-screen listening for existing installations once. Subsequent
        // launches preserve the user's choice if they turn it off in Settings.
        if !UserDefaults.standard.bool(forKey: Self.backgroundAudioMigrationKey) {
            self.settings.backgroundPlaybackEnabled = true
            save()
            UserDefaults.standard.set(true, forKey: Self.backgroundAudioMigrationKey)
        }
        #endif
        // Reset settings to defaults when launched for UI testing so each test
        // suite starts from a clean, known state and prior runs cannot bleed in.
        if ProcessInfo.processInfo.arguments.contains("--uitesting-reset-settings") {
            self.settings = AppSettings()
        }
        if ProcessInfo.processInfo.arguments.contains("--uitesting-disable-sponsorblock") {
            self.settings.sponsorBlockEnabled = false
        }
        if ProcessInfo.processInfo.arguments.contains("--uitesting-audio-only-mode") {
            self.settings.audioOnlyMode = true
        }
        if ProcessInfo.processInfo.arguments.contains("--uitesting-hide-shorts") {
            self.settings.hideShorts = true
        }
        if ProcessInfo.processInfo.arguments.contains("--uitesting-enable-tos-player-on-ios") {
            self.useTOSPlayerOnIOS = true
        }
        // Retained for existing suites that explicitly select the native player.
        if ProcessInfo.processInfo.arguments.contains("--uitesting-disable-tos-player-on-ios") {
            self.useTOSPlayerOnIOS = false
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
        iCloudSyncManager.shared.syncEnabled = settings.iCloudSyncEnabled
    }

    public func reset() {
        settings = AppSettings()
    }
}
