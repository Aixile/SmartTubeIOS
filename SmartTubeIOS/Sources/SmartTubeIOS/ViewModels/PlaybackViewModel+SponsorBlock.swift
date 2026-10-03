import AVFoundation
import SmartTubeIOSCore
import os

private let sponsorLog = DiagnosticLogger(category: "SponsorBlock")

// MARK: - SponsorBlock (thin wrapper — logic lives in SponsorBlockSkipManager)

extension PlaybackViewModel {

    @discardableResult
    public func checkSponsorSkip(at time: TimeInterval) -> Bool {
        let wasSkipping = sponsorBlockManager.isSkippingSegment
        let handled = sponsorBlockManager.checkSponsorSkip(at: time)
        if !wasSkipping, sponsorBlockManager.isSkippingSegment {
            sponsorLog.notice("Automatic segment skip started at \(time)s")
        }
        return handled
    }

    public func skipToastSegment() {
        sponsorBlockManager.skipToastSegment()
    }
}
