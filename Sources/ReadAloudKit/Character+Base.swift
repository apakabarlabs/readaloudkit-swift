extension Character {
    var base: Unicode.Scalar {
        let scalars = unicodeScalars
        let first = scalars[scalars.startIndex]
        guard scalars.count > 1 else { return first }
        return scalars.first { !$0.isPrependedToWhatFollows } ?? first
    }
}

extension Unicode.Scalar {
    fileprivate var isPrependedToWhatFollows: Bool {
        let aScalarThatStandsAlone = " "
        return (String(self) + aScalarThatStandsAlone).count == 1
    }
}
