import SmartTubeIOSCore

extension PlaybackViewModel {
    func videoDetails(fallback video: Video) -> Video {
        (currentVideo ?? video).mergingPlaybackMetadata(playerInfo?.video)
    }
}
