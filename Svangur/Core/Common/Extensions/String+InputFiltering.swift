import Foundation

extension String {
    /// Strips digits/punctuation/symbols (keeps letters — including accented ones, e.g.
    /// Icelandic þ/ð/æ/ö — and spaces), then truncates to `maxLength`. Used for name-style
    /// fields that shouldn't accept numbers or special characters.
    func filteredToLettersAndSpaces(maxLength: Int) -> String {
        let filtered = self.filter { $0.isLetter || $0 == " " }
        return String(filtered.prefix(maxLength))
    }

    /// Truncates so at most `maxDigits` digits remain, while still allowing non-digit
    /// formatting characters (`+`, spaces, dashes) typed before that point — used to enforce
    /// phone-number length limits at input time (`.onChange` in the owning screen), since
    /// self-reassignment from inside a `didSet` isn't reliable on `@Observable` properties.
    func clampedToMaxDigits(_ maxDigits: Int) -> String {
        var digitCount = 0
        var result = ""
        for character in self {
            if character.isNumber {
                guard digitCount < maxDigits else { break }
                digitCount += 1
            }
            result.append(character)
        }
        return result
    }
}
