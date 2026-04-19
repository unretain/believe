import Foundation

nonisolated enum Base58 {
    private static let alphabet = Array("123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz")
    private static let base = UInt(alphabet.count)

    static func encode(_ bytes: [UInt8]) -> String {
        var digits: [UInt] = [0]
        for byte in bytes {
            var carry = UInt(byte)
            for j in 0..<digits.count {
                carry += digits[j] << 8
                digits[j] = carry % base
                carry /= base
            }
            while carry > 0 {
                digits.append(carry % base)
                carry /= base
            }
        }

        var result = ""
        for byte in bytes {
            if byte != 0 { break }
            result.append(alphabet[0])
        }
        for digit in digits.reversed() {
            result.append(alphabet[Int(digit)])
        }
        return result
    }

    static func decode(_ string: String) -> [UInt8]? {
        var bytes: [UInt] = [0]
        for char in string {
            guard let index = alphabet.firstIndex(of: char) else { return nil }
            var carry = UInt(index)
            for j in 0..<bytes.count {
                carry += bytes[j] * base
                bytes[j] = carry & 0xFF
                carry >>= 8
            }
            while carry > 0 {
                bytes.append(carry & 0xFF)
                carry >>= 8
            }
        }

        var result: [UInt8] = []
        for char in string {
            if char != alphabet[0] { break }
            result.append(0)
        }
        result.append(contentsOf: bytes.reversed().map { UInt8($0) })
        return result
    }
}
