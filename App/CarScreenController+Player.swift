#if DEBUG
    import UIKit

    /// The car player's heart, screen layout, channels and split view, as CarTV's (DECISIONS 164).
    extension CarScreenController {
        /// The heart's change reaches the iPhone's lists and this screen through `libraryDidChange`.
        func toggleFavorite() {
            guard let environment = AppEnvironment.current, let current = environment.playback.current else { return }
            do {
                let isFavorite = try environment.repository.toggleFavorite(current.id)
                environment.playback.updateFavorite(isFavorite, for: current.id)
                environment.router.libraryDidChange()
            } catch {
                CarPlayTrace.write("favourite failed: \(error.localizedDescription)")
            }
            refresh()
        }

        func cycleAspect() {
            let all = VideoAspect.allCases
            let next = all.firstIndex(of: model.aspect).map { all[(all.index(after: $0)) % all.count] } ?? .fit
            model.aspect = next
            stage.setVideoGravity(next.gravity)
        }

        /// The iPhone's Cast picture, or how to cast, beside a smaller video, as in the browser's split view (owner:
        /// "on click the split icon show the cast screen page, the same as in the browser").
        func setPlayerSplit(_ isSplit: Bool) {
            guard model.isPlayerSplit != isSplit else { return }
            model.isPlayerSplit = isSplit
            // The old one goes before the new one, so the two never hold at once.
            let (old, new) = isSplit ? (stageFull, stageSplit) : (stageSplit, stageFull)
            old.isActive = false
            new.isActive = true
            showLayers()
        }

        func closeChannels() {
            model.showsChannels = false
        }

        /// The split panel beside the browser's page (under its bar) or the player's video (full height), or hidden.
        func layOutSplitPanel(browsing: Bool) {
            let splits = (browsing && model.isSplit) || (model.mode == .player && model.isPlayerSplit)
            splitPanel.isHidden = !splits
            let (narrow, wide) = splits ? (splitHidden, splitShown) : (splitShown, splitHidden)
            narrow.isActive = false
            wide.isActive = true
            // Under the bar beside the page; the full height beside the keyboard, which hides the bar.
            let underBar = browsing && model.page == nil
            let (oldTop, newTop) = underBar ? (splitFullHeight, splitUnderBar) : (splitUnderBar, splitFullHeight)
            oldTop.isActive = false
            newTop.isActive = true
            if model.mode == .player {
                showSplitPicture()
            }
        }

        func embed(_ child: UIViewController, in container: UIView, within guide: UILayoutGuide? = nil) {
            addChild(child)
            child.view.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(child.view)
            NSLayoutConstraint.activate([
                child.view.leadingAnchor.constraint(equalTo: guide?.leadingAnchor ?? container.leadingAnchor),
                child.view.trailingAnchor.constraint(equalTo: guide?.trailingAnchor ?? container.trailingAnchor),
                child.view.topAnchor.constraint(equalTo: guide?.topAnchor ?? container.topAnchor),
                child.view.bottomAnchor.constraint(equalTo: guide?.bottomAnchor ?? container.bottomAnchor)
            ])
            child.didMove(toParent: self)
        }

        /// The video and road within the safe area, its leading edge moving aside for the split view's panel.
        func addStage() {
            addChild(stage)
            stage.view.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(stage.view)
            let guide = view.safeAreaLayoutGuide
            NSLayoutConstraint.activate([
                stage.view.trailingAnchor.constraint(equalTo: guide.trailingAnchor),
                stage.view.topAnchor.constraint(equalTo: guide.topAnchor),
                stage.view.bottomAnchor.constraint(equalTo: guide.bottomAnchor),
                stageFull
            ])
            stage.didMove(toParent: self)
        }
    }
#endif
