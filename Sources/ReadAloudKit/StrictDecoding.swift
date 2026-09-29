private struct WrittenKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }

    init(stringValue: String) {
        self.stringValue = stringValue
    }

    init?(intValue: Int) {
        nil
    }
}

extension Decoder {
    func refuseKeys<Known: CodingKey>(otherThan known: Known.Type, of subject: String) throws {
        let written = try container(keyedBy: WrittenKey.self)
        let stray = written.allKeys.first { Known(stringValue: $0.stringValue) == nil }
        guard let stray else { return }
        throw DecodingError.dataCorruptedError(
            forKey: stray,
            in: written,
            debugDescription: "\(stray.stringValue) is not a field of \(subject)"
        )
    }
}
