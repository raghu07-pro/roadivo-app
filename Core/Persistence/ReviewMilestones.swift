import Foundation

/// When to ask for an App Store rating: after the 1st, 10th and 25th video
/// opened, then every 25th (50, 75, 100…). iOS shows the prompt at most three
/// times a year and may skip a request, so asking at milestones is safe.
enum ReviewMilestones {
    static func shouldAsk(afterOpening count: Int) -> Bool {
        count == 1 || count == 10 || (count >= 25 && count % 25 == 0)
    }
}
