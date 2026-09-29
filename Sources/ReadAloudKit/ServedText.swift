import Foundation

/// A served document that is not UTF-8 text, with or without a byte order mark.
///
/// Every port refuses such a document with this error, before reading any JSON.
public struct NotUTF8: Error, Equatable, CustomStringConvertible {
    public var description: String { "the document is not UTF-8" }
}

enum ServedText {
    private static let byteOrderMark: [UInt8] = [0xEF, 0xBB, 0xBF]

    static func utf8(_ data: Data) throws -> Data {
        let marked = data.starts(with: byteOrderMark)
        let text = marked ? data.dropFirst(byteOrderMark.count) : data[...]
        let nulNoJSONTextHolds: UInt8 = 0
        guard !text.contains(nulNoJSONTextHolds), String(data: Data(text), encoding: .utf8) != nil
        else { throw NotUTF8() }
        return Data(text)
    }
}
