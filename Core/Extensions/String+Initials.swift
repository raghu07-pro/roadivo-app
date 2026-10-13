import Foundation

extension String {
    /// Up to two leading letters, for artwork placeholders ("BBC One" → "BO").
    var initials: String {
        let words = split { !$0.isLetter && !$0.isNumber }
        let letters = words.prefix(2).compactMap(\.first)
        return letters.isEmpty ? "•" : String(letters).uppercased()
    }

    /// A stable 0…1 value derived from the string, for placeholder colours.
    var stableHue: Double {
        var hash: UInt64 = 5381
        for byte in utf8 {
            hash = (hash &* 33) &+ UInt64(byte)
        }
        return Double(hash % 360) / 360
    }
}
