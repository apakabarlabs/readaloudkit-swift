import Foundation

/// A served document that is not UTF-8 text, with or without a byte order mark.
///
/// Every port refuses such a document with this error, before reading any JSON.
public struct NotUTF8: Error, Equatable, CustomStringConvertible {
    public var description: String { "the document is not UTF-8" }
}

enum ServedText {
    private static let byteOrderMark: [UInt8] = [0xEF, 0xBB, 0xBF]
    private static let quotationMark = UInt8(ascii: "\"")
    private static let reverseSolidus = UInt8(ascii: "\\")
    private static let firstPrintable: UInt8 = 0x20
    private static let highSurrogates: ClosedRange<UInt32> = 0xD800...0xDBFF
    private static let lowSurrogates: ClosedRange<UInt32> = 0xDC00...0xDFFF

    static func utf8(_ data: Data) throws -> Data {
        let marked = data.starts(with: byteOrderMark)
        let text = Data(marked ? data.dropFirst(byteOrderMark.count) : data[...])
        let nulNoJSONTextHolds: UInt8 = 0
        guard !text.contains(nulNoJSONTextHolds), String(data: text, encoding: .utf8) != nil
        else { throw NotUTF8() }
        try refuseWhatJSONForbids(in: [UInt8](text))
        return text
    }

    private static func refuseWhatJSONForbids(in bytes: [UInt8]) throws {
        if bytes.starts(with: byteOrderMark) {
            throw malformed("a second byte order mark opens the document")
        }
        var index = 0
        var inString = false
        while index < bytes.count {
            let byte = bytes[index]
            if !inString {
                inString = byte == quotationMark
            } else if byte == quotationMark {
                inString = false
            } else if byte == reverseSolidus {
                index = try endOfEscape(in: bytes, at: index)
                continue
            } else if byte < firstPrintable {
                throw malformed("a control character is written raw inside a string")
            }
            index += 1
        }
    }

    private static func endOfEscape(in bytes: [UInt8], at index: Int) throws -> Int {
        guard let unit = codeUnit(in: bytes, at: index) else { return index + 2 }
        if lowSurrogates.contains(unit) {
            throw malformed("a lone low surrogate is escaped inside a string")
        }
        guard highSurrogates.contains(unit) else { return index + 6 }
        guard let low = codeUnit(in: bytes, at: index + 6), lowSurrogates.contains(low) else {
            throw malformed("a lone high surrogate is escaped inside a string")
        }
        return index + 12
    }

    private static func codeUnit(in bytes: [UInt8], at index: Int) -> UInt32? {
        let escape = index + 6
        guard escape <= bytes.count, bytes[index] == reverseSolidus,
            bytes[index + 1] == UInt8(ascii: "u")
        else { return nil }
        guard let digits = String(bytes: bytes[(index + 2)..<escape], encoding: .ascii) else {
            return nil
        }
        return UInt32(digits, radix: 16)
    }

    private static func malformed(_ description: String) -> DecodingError {
        DecodingError.dataCorrupted(
            DecodingError.Context(codingPath: [], debugDescription: description)
        )
    }
}
