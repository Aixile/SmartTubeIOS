import Foundation
import SmartTubeIOSCore
import os

/// Device-local diagnostics. No logs or playback information are uploaded.
struct DiagnosticLogger: Sendable {
    static let sessionReportID = String(UUID().uuidString.prefix(8)).uppercased()
    private static let playback = DiagnosticLogger(category: "PlaybackDiagnostics")
    private let logger: Logger

    init(subsystem: String = appSubsystem, category: String) {
        logger = Logger(subsystem: subsystem, category: category)
    }

    func notice(_ message: @autoclosure () -> String) {
        let text = message()
        logger.notice("\(text, privacy: .public)")
    }

    func error(_ message: @autoclosure () -> String) {
        let text = message()
        logger.error("\(text, privacy: .public)")
    }

    func debug(_ message: @autoclosure () -> String) {
        let text = message()
        logger.debug("\(text, privacy: .public)")
    }

    func recordNonFatal(_ error: Error, userInfo: [String: String] = [:]) {
        logger.error("\(error.localizedDescription, privacy: .public)")
        logger.debug("Context: \(userInfo.description, privacy: .private)")
    }

    static func setVideoContext(id: String, title: String) {
        playback.logger.debug("Active video: \(id, privacy: .private) \(title, privacy: .private)")
    }

    static func setIntendedVideo(id: String, title: String) {
        playback.logger.debug("Requested video: \(id, privacy: .private) \(title, privacy: .private)")
    }

    static func recordSlowVideoLoad(
        videoId: String,
        elapsedMs: Int,
        streamType: String,
        hasError: Bool,
        errorDescription: String? = nil
    ) {
        playback.logger.notice(
            "Slow load: \(elapsedMs)ms stream=\(streamType, privacy: .public) hasError=\(hasError) video=\(videoId, privacy: .private) error=\(errorDescription ?? "none", privacy: .private)"
        )
    }

    static func sendAutoPlaybackDiagnostic() {
        playback.error("Playback failed; see local session diagnostics.")
    }

    static func sendWrongVideoReport(
        intendedId: String,
        intendedTitle: String,
        activeId: String,
        activeTitle: String
    ) {
        playback.logger.error(
            "Wrong video: intended=\(intendedId, privacy: .private) (\(intendedTitle, privacy: .private)) active=\(activeId, privacy: .private) (\(activeTitle, privacy: .private))"
        )
    }
}
