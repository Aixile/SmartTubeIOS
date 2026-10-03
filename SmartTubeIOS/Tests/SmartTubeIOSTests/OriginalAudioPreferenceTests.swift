import AVFoundation
import Foundation
import Testing

@testable import SmartTubeIOS
@testable import SmartTubeIOSCore

@Suite("Original audio preference")
struct OriginalAudioPreferenceTests {
    private let chinese = AudioTrack(
        id: "zh.1", name: "Chinese", languageCode: "zh", isOriginal: true, contentID: "zh.1")
    private let englishDub = AudioTrack(
        id: "en.2", name: "English", languageCode: "en", isOriginal: false, contentID: "en.2")

    @Test("English device language cannot override Chinese original by default")
    func originalOnEnglishDevice() {
        for preference in [nil, AudioTrackPreference.original] as [String?] {
            let selected = AudioTrackPreference.select(
                from: [englishDub, chinese], preferred: preference, deviceLanguages: ["en-US"])
            #expect(selected == chinese)
        }
        #expect(AudioTrackPreference.select(from: [], preferred: nil) == nil)
    }

    @Test("Saved Original follows the next video's language")
    func followsCreator() {
        let preference = AudioTrackPreference.savedPreference(for: chinese)
        #expect(preference == AudioTrackPreference.original)
        let englishOriginal = AudioTrack(id: "en.1", name: "English", languageCode: "en", isOriginal: true)
        let chineseDub = AudioTrack(id: "zh.2", name: "Chinese", languageCode: "zh", isOriginal: false)
        #expect(
            AudioTrackPreference.select(from: [chineseDub, englishOriginal], preferred: preference) == englishOriginal)
        #expect(AudioTrackPreference.savedPreference(for: englishDub) == "en")
    }

    @Test("Missing and legacy automatic settings migrate to Original; explicit choices survive")
    func settingsMigration() throws {
        #expect(AppSettings().preferredAudioLanguage == AudioTrackPreference.original)
        for json in ["{}", #"{"preferredAudioLanguage":null}"#] {
            let settings = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
            #expect(settings.preferredAudioLanguage == AudioTrackPreference.original)
        }
        for preference in ["en", "zh-Hant", AudioTrackPreference.system] {
            let settings = try JSONDecoder().decode(
                AppSettings.self, from: Data("{\"preferredAudioLanguage\":\"\(preference)\"}".utf8))
            #expect(settings.preferredAudioLanguage == preference)
        }
    }

    @Test("Native track manager saves Original and reloads the original content ID")
    @MainActor
    func nativeManagerSelection() {
        let delegate = AudioPreferenceDelegate()
        let manager = AudioTrackManager(player: AVPlayer())
        manager.delegate = delegate
        manager.loadHLSVariantTracks([englishDub, chinese])
        #expect(manager.selectedAudioTrack == chinese)
        var requested: AudioTrack?
        manager.onHLSLanguageChange = { requested = $0 }
        manager.selectAudioTrack(englishDub)
        #expect(delegate.settings.preferredAudioLanguage == "en")
        manager.selectAudioTrack(nil)
        #expect(requested == chinese)
        #expect(manager.selectedAudioTrack == chinese)
        #expect(delegate.settings.preferredAudioLanguage == AudioTrackPreference.original)
    }

    @Test("Master demotes English dub default only within the original audio group")
    func originalRenditionDefault() {
        let xtags = Data("acont=original".utf8).base64EncodedString()
        let manifest = """
            #EXTM3U
            #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="a",NAME="English",DEFAULT=YES,URI="english.m3u8"
            #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="a",NAME="Chinese",DEFAULT=NO,YT-EXT-XTAGS="\(xtags)",URI="chinese.m3u8"
            #EXT-X-MEDIA:TYPE=AUDIO,GROUP-ID="b",NAME="Other",DEFAULT=YES,URI="other.m3u8"
            #EXT-X-STREAM-INF:RESOLUTION=1920x1080,CODECS="avc1",AUDIO="a"
            video.m3u8
            """
        let filtered = filterHLSMasterManifest(manifest, maximumHeight: 1080, requiredVideoCodec: "avc1")
        #expect(filtered.contains("NAME=\"English\",DEFAULT=NO"))
        #expect(filtered.contains("NAME=\"Chinese\",DEFAULT=YES"))
        #expect(filtered.contains("NAME=\"Other\",DEFAULT=YES"))
        #expect(filtered.contains("english.m3u8"))
        #expect(filtered.contains("chinese.m3u8"))
    }

    @Test("Original variants with content IDs override English dubs")
    func originalContentID() {
        let xtags = Data("acont=original".utf8).base64EncodedString()
        let manifest = """
            #EXTM3U
            #EXT-X-STREAM-INF:RESOLUTION=1920x1080,YT-EXT-AUDIO-CONTENT-ID="en.2"
            english.m3u8
            #EXT-X-STREAM-INF:RESOLUTION=1920x1080,YT-EXT-AUDIO-CONTENT-ID="zh.1",YT-EXT-XTAGS="\(xtags)"
            chinese.m3u8
            """
        let baseURL = URL(string: "https://example.com/master.m3u8")!
        #expect(
            parseHLSVariantURLsForLanguage(nil, from: manifest, baseURL: baseURL)[1080]?.lastPathComponent
                == "chinese.m3u8")
        #expect(
            parseHLSVariantURLsForLanguage("en.2", from: manifest, baseURL: baseURL)[1080]?.lastPathComponent
                == "english.m3u8")
        #expect(!hlsVariantMatchesAudioContentID("#EXT-X-STREAM-INF:YT-EXT-AUDIO-CONTENT-ID=en.20", contentID: "en.2"))
    }
}

@MainActor
private final class AudioPreferenceDelegate: AudioTrackDelegate {
    var settings = AppSettings()
}
