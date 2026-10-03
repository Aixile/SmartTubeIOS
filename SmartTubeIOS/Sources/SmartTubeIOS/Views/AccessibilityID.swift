enum AccessibilityID {
    enum Player {
        static let audioPreference = "settings.preferredAudioLanguageRow"
        static let previousVideo = "player.prevBtn"
        static let nextVideo = "player.nextBtn"
        static let webPreviousVideo = "tosPlayer.previousButton"
        static let webNextVideo = "tosPlayer.nextButton"
    }

    enum Channel {
        static let view = "channel.view"
        static let title = "channel.title"
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
