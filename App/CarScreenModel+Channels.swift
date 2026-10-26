#if DEBUG
    import CoreGraphics

    extension CarScreenModel {
        /// The channels panel's lists, as CarTV's Home, Favorites and Episodes.
        enum ChannelList: CaseIterable {
            case home
            case favorites
            /// What's playing's group: what next and previous step through.
            case group
        }

        /// The channels panel's share of the screen's width, over the video.
        static let channelsWidth: CGFloat = 0.45
        /// The split view's Cast panel, beside the browser's page or the player's video, as CarTV's.
        static let splitWidth: CGFloat = 0.28

        func channels(in list: ChannelList) -> [MediaItem] {
            switch list {
            case .home: menu.home(limit: CarPlayMenu.itemLimit).recent
            case .favorites: menu.favorites
            case .group: playingQueue
            }
        }
    }
#endif
