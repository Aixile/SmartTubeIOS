import AVFoundation
import Foundation
import SmartTubeIOSCore

#if os(iOS)
import UIKit
#endif

private let sourceLog = DiagnosticLogger(category: "StreamSource")

extension PlaybackViewModel {
    /// Try native HLS before entering the legacy extraction cascade. Both the
    /// request and AVPlayer readiness wait are cancelled when the deadline wins.
    func tryPreferredNativeStream(video: Video) async -> Bool {
        guard StreamMethodProbeSupport.forcedStreamMethod == nil else { return false }
        let source: any StreamSource = VisionOSStreamSource(api: api)
        let savedState = await VideoStateStore.shared.state(for: video.id)
        if let position = savedState?.position, position > 5 {
            savedPositionToRestore = position
        }
        if let startTime = StreamMethodProbeSupport.playbackStartTime {
            savedPositionToRestore = startTime
        }
        sourceLog.notice("Resolving \(video.id) with \(source.name)")
        let succeeded = await withTaskGroup(of: Bool.self) { group in
            group.addTask {
                await self.playStream(from: source, video: video)
            }
            group.addTask {
                do { try await Task.sleep(for: PlaybackTuning.preferredSourceTimeout) } catch { return false }
                sourceLog.notice("Preferred stream source timed out")
                return false
            }
            let result = await group.next() ?? false
            group.cancelAll()
            return result
        }
        guard succeeded, !Task.isCancelled, currentVideoId == video.id else { return false }
        await loadAudioOnlyItemIfEnabled()
        if let item = player.currentItem {
            endObserverTask?.cancel()
            endObserverTask = Task { [weak self] in
                for await _ in NotificationCenter.default.notifications(
                    named: AVPlayerItem.didPlayToEndTimeNotification, object: item
                ) {
                    guard let self, !Task.isCancelled, self.player.currentItem === item else { return }
                    self.handlePlaybackEnd()
                }
            }
        }
        #if os(iOS)
        UIApplication.shared.isIdleTimerDisabled = true
        updateNowPlayingInfo()
        #endif
        return true
    }

    private func playStream(from source: any StreamSource, video: Video) async -> Bool {
        do {
            let info = try await source.resolve(videoID: video.id)
            try Task.checkCancellation()
            guard currentVideoId == video.id, let url = info.hlsURL else { return false }
            return await attemptURL(url, for: video, info: info, label: "\(source.name)/HLS")
        } catch is CancellationError {
            return false
        } catch {
            sourceLog.notice("\(source.name) failed: \(error.localizedDescription)")
            return false
        }
    }
}
