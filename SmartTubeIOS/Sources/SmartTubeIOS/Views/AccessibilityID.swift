enum AccessibilityID {
    enum VideoCard {
        static let uploadTime = "video.card.uploadTime"
    }

    enum MiniPlayer {
        static let window = "miniPlayer.bar"
        static let expand = "miniPlayer.expandButton"
        static let playPause = "miniPlayer.playPauseButton"
        static let close = "miniPlayer.closeButton"
        static let webWindow = "tosPlayer.miniPlayerBar"
        static let webExpand = "tosPlayer.miniPlayer.expandButton"
        static let webPlayPause = "tosPlayer.miniPlayer.playPauseButton"
        static let webClose = "tosPlayer.miniPlayer.closeButton"
    }

    enum Player {
        static let channel = "player.channelName"
        static let publicationDate = "player.publicationDate"
        static let viewCount = "player.viewCount"
        static let audioPreference = "settings.preferredAudioLanguageRow"
        static let previousVideo = "player.prevBtn"
        static let nextVideo = "player.nextBtn"
        static let webPreviousVideo = "tosPlayer.previousButton"
        static let webNextVideo = "tosPlayer.nextButton"
    }

    enum Channel {
        static let browseHeader = "channel.browseHeader"
        static let resultCount = "channel.resultCount"
        static let filterSummary = "channel.filterSummary"
        static let searchButton = "channel.searchButton"
        static let clearSearch = "channel.clearSearch"
        static let sortMenu = "channel.sortMenu"
        static let view = "channel.view"
        static let title = "channel.title"
        static let subscribers = "channel.subscribers"
        static let header = "channel.header"
        static let videoGrid = "channel.videoGrid"
        static let followButton = "channel.followButton"
        static let sponsorBlockButton = "channel.sponsorBlockButton"
        static let search = "channel.search"
        static let filtersButton = "channel.filtersButton"
        static let filtersSheet = "channel.filtersSheet"
        static let filtersDone = "channel.filtersDone"
        static let kind = "channel.filterPicker"
        static let access = "channel.access"
        static let watchStatus = "channel.watchStatus"
        static let duration = "channel.duration"
        static let sort = "channel.sort"
        static let reset = "channel.resetFilters"
        static let loadMore = "channel.loadMore"
        static func membersBadge(_ id: String) -> String { "video.membersOnly.\(id)" }
        static func videoCard(_ id: String) -> String { "video.card.\(id)" }
    }

    enum Home {
        static let header = "home.chipBar"
        static let feedMenu = "home.feedMenu"
        static let groupingMenu = "home.groupingMenu"
        static let groupingPicker = "home.groupingPicker"
        static let filtersButton = "home.filtersButton"
        static let filtersSheet = "home.filtersSheet"
        static let filtersDone = "home.filtersDone"
        static let filterSearch = "home.filterSearch"
        static let filterKind = "home.filterKind"
        static let filterDuration = "home.filterDuration"
        static let filterWatchStatus = "home.filterWatchStatus"
        static let filterUploadDate = "home.filterUploadDate"
        static let filterSort = "home.filterSort"
        static let filterReset = "home.filterReset"
        static let filterSummary = "home.filterSummary"
        static let filteredFeed = "home.filteredFeed"
        static let filteredLoadMore = "home.filteredLoadMore"
        static let topicBar = "home.topicBar"
        static let topicFeed = "home.topicFeed"
        static let allTopics = "home.topic.all"
        static let topicRetry = "home.topic.retry"
        static let scrollFeed = "home.scrollFeed"
        static let topicPickerButton = "home.topicPickerButton"
        static let topicPicker = "home.topicPicker"
        static let topicSearch = "home.topicSearch"
        static let topicPickerDone = "home.topicPickerDone"
        static func topicChoice(_ id: String) -> String { "home.topicChoice.\(id)" }
        static func topic(_ id: String) -> String { "home.topic.\(id)" }
    }

    enum FeedCountry {
        static let button = "feedCountry.button"
        static let picker = "feedCountry.picker"
        static let search = "feedCountry.search"
        static let done = "feedCountry.done"
        static func country(_ code: String) -> String { "feedCountry.\(code)" }
    }
}
