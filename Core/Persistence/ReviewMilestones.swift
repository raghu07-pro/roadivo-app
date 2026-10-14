import Foundation

/// Asks for a rating after the 1st, 10th and 25th video, then every 25th. iOS shows the prompt
/// at most three times a year and may skip a request.
enum ReviewMilestones {
    static func shouldAsk(afterOpening count: Int) -> Bool {
        count == 1 || count == 10 || (count >= 25 && count % 25 == 0)
    }
}
