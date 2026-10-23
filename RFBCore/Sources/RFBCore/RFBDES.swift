import Foundation

/// Pure Swift implementation of DES (Data Encryption Standard, FIPS 46-3)
/// and RFC 6143 VNC Authentication challenge-response derivation.
public struct RFBDES {

    /// Reverses the bits of a single byte (bit 0 becomes bit 7, bit 1 becomes bit 6, etc.).
    /// Required by RFC 6143 Section 7.2.2 for VNC password key derivation.
    public static func reverseByteBits(_ byte: UInt8) -> UInt8 {
        var b = byte
        b = ((b & 0xF0) >> 4) | ((b & 0x0F) << 4)
        b = ((b & 0xCC) >> 2) | ((b & 0x33) << 2)
        b = ((b & 0xAA) >> 1) | ((b & 0x55) << 1)
        return b
    }

    /// Derives an 8-byte DES key from a VNC password string (truncated or null-padded to 8 bytes, with bits reversed).
    public static func deriveVNCKey(from password: String) -> [UInt8] {
        var key = [UInt8](repeating: 0, count: 8)
        let utf8Bytes = Array(password.utf8)
        let copyLen = min(utf8Bytes.count, 8)
        for i in 0..<copyLen {
            key[i] = reverseByteBits(utf8Bytes[i])
        }
        return key
    }

    /// Computes the 16-byte VNC authentication response for a 16-byte server challenge and password.
    public static func computeVNCAuthResponse(challenge: Data, password: String) -> Data? {
        guard challenge.count == 16 else { return nil }
        let key = deriveVNCKey(from: password)
        
        let block1 = Array(challenge[0..<8])
        let block2 = Array(challenge[8..<16])
        
        let encrypted1 = encryptBlock(block1, key: key)
        let encrypted2 = encryptBlock(block2, key: key)
        
        return Data(encrypted1 + encrypted2)
    }

    // MARK: - DES Tables and Permutations (FIPS 46-3)

    private static let IP: [UInt8] = [
        58, 50, 42, 34, 26, 18, 10, 2,
        60, 52, 44, 36, 28, 20, 12, 4,
        62, 54, 46, 38, 30, 22, 14, 6,
        64, 56, 48, 40, 32, 24, 16, 8,
        57, 49, 41, 33, 25, 17,  9, 1,
        59, 51, 43, 35, 27, 19, 11, 3,
        61, 53, 45, 37, 29, 21, 13, 5,
        63, 55, 47, 39, 31, 23, 15, 7
    ]

    private static let FP: [UInt8] = [
        40, 8, 48, 16, 56, 24, 64, 32,
        39, 7, 47, 15, 55, 23, 63, 31,
        38, 6, 46, 14, 54, 22, 62, 30,
        37, 5, 45, 13, 53, 21, 61, 29,
        36, 4, 44, 12, 52, 20, 60, 28,
        35, 3, 43, 11, 51, 19, 59, 27,
        34, 2, 42, 10, 50, 18, 58, 26,
        33, 1, 41,  9, 49, 17, 57, 25
    ]

    private static let PC1: [UInt8] = [
        57, 49, 41, 33, 25, 17,  9,
         1, 58, 50, 42, 34, 26, 18,
        10,  2, 59, 51, 43, 35, 27,
        19, 11,  3, 60, 52, 44, 36,
        63, 55, 47, 39, 31, 23, 15,
         7, 62, 54, 46, 38, 30, 22,
        14,  6, 61, 53, 45, 37, 29,
        21, 13,  5, 28, 20, 12,  4
    ]

    private static let PC2: [UInt8] = [
        14, 17, 11, 24,  1,  5,
         3, 28, 15,  6, 21, 10,
        23, 19, 12,  4, 26,  8,
        16,  7, 27, 20, 13,  2,
        41, 52, 31, 37, 47, 55,
        30, 40, 51, 45, 33, 48,
        44, 49, 39, 56, 34, 53,
        46, 42, 50, 36, 29, 32
    ]

    private static let keyShifts: [Int] = [1, 1, 2, 2, 2, 2, 2, 2, 1, 2, 2, 2, 2, 2, 2, 1]

    private static let E: [UInt8] = [
        32,  1,  2,  3,  4,  5,
         4,  5,  6,  7,  8,  9,
         8,  9, 10, 11, 12, 13,
        12, 13, 14, 15, 16, 17,
        16, 17, 18, 19, 20, 21,
        20, 21, 22, 23, 24, 25,
        24, 25, 26, 27, 28, 29,
        28, 29, 30, 31, 32,  1
    ]

    private static let P: [UInt8] = [
        16,  7, 20, 21,
        29, 12, 28, 17,
         1, 15, 23, 26,
         5, 18, 31, 10,
         2,  8, 24, 14,
        32, 27,  3,  9,
        19, 13, 30,  6,
        22, 11,  4, 25
    ]

    private static let SBoxes: [[[UInt8]]] = [
        // S1
        [
            [14,  4, 13,  1,  2, 15, 11,  8,  3, 10,  6, 12,  5,  9,  0,  7],
            [ 0, 15,  7,  4, 14,  2, 13,  1, 10,  6, 12, 11,  9,  5,  3,  8],
            [ 4,  1, 14,  8, 13,  6,  2, 11, 15, 12,  9,  7,  3, 10,  5,  0],
            [15, 12,  8,  2,  4,  9,  1,  7,  5, 11,  3, 14, 10,  0,  6, 13]
        ],
        // S2
        [
            [15,  1,  8, 14,  6, 11,  3,  4,  9,  7,  2, 13, 12,  0,  5, 10],
            [ 3, 13,  4,  7, 15,  2,  8, 14, 12,  0,  1, 10,  6,  9, 11,  5],
            [ 0, 14,  7, 11, 10,  4, 13,  1,  5,  8, 12,  6,  9,  3,  2, 15],
            [13,  8, 10,  1,  3, 15,  4,  2, 11,  6,  7, 12,  0,  5, 14,  9]
        ],
        // S3
        [
            [10,  0,  9, 14,  6,  3, 15,  5,  1, 13, 12,  7, 11,  4,  2,  8],
            [13,  7,  0,  9,  3,  4,  6, 10,  2,  8,  5, 14, 12, 11, 15,  1],
            [13,  6,  4,  9,  8, 15,  3,  0, 11,  1,  2, 12,  5, 10, 14,  7],
            [ 1, 10, 13,  0,  6,  9,  8,  7,  4, 15, 14,  3, 11,  5,  2, 12]
        ],
        // S4
        [
            [ 7, 13, 14,  3,  0,  6,  9, 10,  1,  2,  8,  5, 11, 12,  4, 15],
            [13,  8, 11,  5,  6, 15,  0,  3,  4,  7,  2, 12,  1, 10, 14,  9],
            [10,  6,  9,  0, 12, 11,  7, 13, 15,  1,  3, 14,  5,  2,  8,  4],
            [ 3, 15,  0,  6, 10,  1, 13,  8,  9,  4,  5, 11, 12,  7,  2, 14]
        ],
        // S5
        [
            [ 2, 12,  4,  1,  7, 10, 11,  6,  8,  5,  3, 15, 13,  0, 14,  9],
            [14, 11,  2, 12,  4,  7, 13,  1,  5,  0, 15, 10,  3,  9,  8,  6],
            [ 4,  2,  1, 11, 10, 13,  7,  8, 15,  9, 12,  5,  6,  3,  0, 14],
            [11,  8, 12,  7,  1, 14,  2, 13,  6, 15,  0,  9, 10,  4,  5,  3]
        ],
        // S6
        [
            [12,  1, 10, 15,  9,  2,  6,  8,  0, 13,  3,  4, 14,  7,  5, 11],
            [10, 15,  4,  2,  7, 12,  9,  5,  6,  1, 13, 14,  0, 11,  3,  8],
            [ 9, 14, 15,  5,  2,  8, 12,  3,  7,  0,  4, 10,  1, 13, 11,  6],
            [ 4,  3,  2, 12,  9,  5, 15, 10, 11, 14,  1,  7,  6,  0,  8, 13]
        ],
        // S7
        [
            [ 4, 11,  2, 14, 15,  0,  8, 13,  3, 12,  9,  7,  5, 10,  6,  1],
            [13,  0, 11,  7,  4,  9,  1, 10, 14,  3,  5, 12,  2, 15,  8,  6],
            [ 1,  4, 11, 13, 12,  3,  7, 14, 10, 15,  6,  8,  0,  5,  9,  2],
            [ 6, 11, 13,  8,  1,  4, 10,  7,  9,  5,  0, 15, 14,  2,  3, 12]
        ],
        // S8
        [
            [13,  2,  8,  4,  6, 15, 11,  1, 10,  9,  3, 14,  5,  0, 12,  7],
            [ 1, 15, 13,  8, 10,  3,  7,  4, 12,  5,  6, 11,  0, 14,  9,  2],
            [ 7, 11,  4,  1,  9, 12, 14,  2,  0,  6, 10, 13, 15,  3,  5,  8],
            [ 2,  1, 14,  7,  4, 10,  8, 13, 15, 12,  9,  0,  3,  5,  6, 11]
        ]
    ]

    private static func permute(_ src: [UInt8], table: [UInt8]) -> [UInt8] {
        var result = [UInt8](repeating: 0, count: (table.count + 7) / 8)
        for (i, bitIndex) in table.enumerated() {
            let srcByte = Int(bitIndex - 1) / 8
            let srcBit = 7 - (Int(bitIndex - 1) % 8)
            let bit = (src[srcByte] >> srcBit) & 1
            let dstByte = i / 8
            let dstBit = 7 - (i % 8)
            result[dstByte] |= (bit << dstBit)
        }
        return result
    }

    private static func generateSubkeys(_ key: [UInt8]) -> [[UInt8]] {
        let pc1Key = permute(key, table: PC1)
        var c = [UInt8](repeating: 0, count: 4)
        var d = [UInt8](repeating: 0, count: 4)
        
        // 56 bits: C is bits 0..27 (3.5 bytes), D is bits 28..55 (3.5 bytes)
        for i in 0..<28 {
            let bit = (pc1Key[i / 8] >> (7 - (i % 8))) & 1
            c[i / 8] |= (bit << (7 - (i % 8)))
        }
        for i in 28..<56 {
            let bit = (pc1Key[i / 8] >> (7 - (i % 8))) & 1
            let dIndex = i - 28
            d[dIndex / 8] |= (bit << (7 - (dIndex % 8)))
        }

        var cBits: UInt32 = (UInt32(c[0]) << 20) | (UInt32(c[1]) << 12) | (UInt32(c[2]) << 4) | (UInt32(c[3]) >> 4)
        var dBits: UInt32 = (UInt32(d[0]) << 20) | (UInt32(d[1]) << 12) | (UInt32(d[2]) << 4) | (UInt32(d[3]) >> 4)

        var subkeys: [[UInt8]] = []

        for shift in keyShifts {
            cBits = ((cBits << shift) | (cBits >> (28 - shift))) & 0x0FFFFFFF
            dBits = ((dBits << shift) | (dBits >> (28 - shift))) & 0x0FFFFFFF

            var combined = [UInt8](repeating: 0, count: 7)
            for i in 0..<28 {
                let bit = UInt8((cBits >> (27 - i)) & 1)
                combined[i / 8] |= (bit << (7 - (i % 8)))
            }
            for i in 0..<28 {
                let bit = UInt8((dBits >> (27 - i)) & 1)
                let combinedIdx = 28 + i
                combined[combinedIdx / 8] |= (bit << (7 - (combinedIdx % 8)))
            }

            let subkey = permute(combined, table: PC2)
            subkeys.append(subkey)
        }

        return subkeys
    }

    /// Encrypts an 8-byte block using single DES ECB.
    public static func encryptBlock(_ block: [UInt8], key: [UInt8]) -> [UInt8] {
        guard block.count == 8, key.count == 8 else { return block }
        
        let subkeys = generateSubkeys(key)
        let ipBlock = permute(block, table: IP)
        
        var left: UInt32 = (UInt32(ipBlock[0]) << 24) | (UInt32(ipBlock[1]) << 16) | (UInt32(ipBlock[2]) << 8) | UInt32(ipBlock[3])
        var right: UInt32 = (UInt32(ipBlock[4]) << 24) | (UInt32(ipBlock[5]) << 16) | (UInt32(ipBlock[6]) << 8) | UInt32(ipBlock[7])

        for round in 0..<16 {
            let subkey = subkeys[round]
            let rightBytes: [UInt8] = [
                UInt8((right >> 24) & 0xFF),
                UInt8((right >> 16) & 0xFF),
                UInt8((right >> 8) & 0xFF),
                UInt8(right & 0xFF)
            ]
            let expanded = permute(rightBytes, table: E)
            
            var xored = [UInt8](repeating: 0, count: 6)
            for i in 0..<6 {
                xored[i] = expanded[i] ^ subkey[i]
            }

            var sboxOutput: UInt32 = 0
            for s in 0..<8 {
                let bitOffset = s * 6
                var sixBits: UInt8 = 0
                for b in 0..<6 {
                    let bitIdx = bitOffset + b
                    let bitVal = (xored[bitIdx / 8] >> (7 - (bitIdx % 8))) & 1
                    sixBits = (sixBits << 1) | bitVal
                }
                let row = Int(((sixBits & 0x20) >> 4) | (sixBits & 0x01))
                let col = Int((sixBits & 0x1E) >> 1)
                let val = UInt32(SBoxes[s][row][col])
                sboxOutput = (sboxOutput << 4) | val
            }

            let sboxBytes: [UInt8] = [
                UInt8((sboxOutput >> 24) & 0xFF),
                UInt8((sboxOutput >> 16) & 0xFF),
                UInt8((sboxOutput >> 8) & 0xFF),
                UInt8(sboxOutput & 0xFF)
            ]
            let permuted = permute(sboxBytes, table: P)
            let fVal: UInt32 = (UInt32(permuted[0]) << 24) | (UInt32(permuted[1]) << 16) | (UInt32(permuted[2]) << 8) | UInt32(permuted[3])

            let newRight = left ^ fVal
            left = right
            right = newRight
        }

        let preOutput: [UInt8] = [
            UInt8((right >> 24) & 0xFF),
            UInt8((right >> 16) & 0xFF),
            UInt8((right >> 8) & 0xFF),
            UInt8(right & 0xFF),
            UInt8((left >> 24) & 0xFF),
            UInt8((left >> 16) & 0xFF),
            UInt8((left >> 8) & 0xFF),
            UInt8(left & 0xFF)
        ]

        return permute(preOutput, table: FP)
    }
}
