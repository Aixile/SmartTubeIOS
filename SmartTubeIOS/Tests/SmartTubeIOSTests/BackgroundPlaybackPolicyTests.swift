import AVFoundation
import SmartTubeIOSCore
import Testing

@testable import SmartTubeIOS

@Suite("Background audio policy")
@MainActor
struct BackgroundPlaybackPolicyTests {
    @Test("Background listening continues audio and disabling it restores pause policy")
    func changingPreferenceUpdatesPlayerPolicy() {
        var settings = AppSettings()
        settings.backgroundPlaybackEnabled = true
        let vm = PlaybackViewModel(settings: settings)
        #expect(vm.player.audiovisualBackgroundPlaybackPolicy == .continuesIfPossible)

        settings.backgroundPlaybackEnabled = false
        settings.pipEnabled = true
        vm.updateSettings(settings)
        #expect(vm.player.audiovisualBackgroundPlaybackPolicy == .automatic)

        settings.pipEnabled = false
        vm.updateSettings(settings)
        #expect(vm.player.audiovisualBackgroundPlaybackPolicy == .pauses)

        settings.backgroundPlaybackEnabled = true
        vm.updateSettings(settings)
        #expect(vm.player.audiovisualBackgroundPlaybackPolicy == .continuesIfPossible)
    }

    @Test("Background and foreground transitions do not start an idle player")
    func idlePlayerStaysPaused() {
        var settings = AppSettings()
        settings.backgroundPlaybackEnabled = true
        let vm = PlaybackViewModel(settings: settings)
        vm.handleBackground()
        vm.handleForeground()
        #expect(vm.player.rate == 0)
        #expect(!vm.isPlaying)
    }
}
