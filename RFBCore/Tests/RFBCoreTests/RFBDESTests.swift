import XCTest
@testable import RFBCore

final class RFBDESTests: XCTestCase {

    func testByteBitReversal() {
        XCTAssertEqual(RFBDES.reverseByteBits(0x00), 0x00)
        XCTAssertEqual(RFBDES.reverseByteBits(0xFF), 0xFF)
        XCTAssertEqual(RFBDES.reverseByteBits(0x01), 0x80)
        XCTAssertEqual(RFBDES.reverseByteBits(0x80), 0x01)
        XCTAssertEqual(RFBDES.reverseByteBits(0xAA), 0x55) // 10101010 -> 01010101
        XCTAssertEqual(RFBDES.reverseByteBits(0x55), 0xAA)
    }

    func testVNCKeyDerivation() {
        let key = RFBDES.deriveVNCKey(from: "test")
        XCTAssertEqual(key.count, 8)
        // 't' is 0x74 (01110100) -> reversed is 00101110 (0x2E)
        XCTAssertEqual(key[0], 0x2E)
        // null padded for remaining 4 bytes
        XCTAssertEqual(key[4], 0x00)
        XCTAssertEqual(key[5], 0x00)
        XCTAssertEqual(key[6], 0x00)
        XCTAssertEqual(key[7], 0x00)
    }

    func testDESBlockEncryptionKnownVector() {
        // Standard FIPS 46-3 test vector:
        // Key: 133457799BBCDFF1
        // Plaintext: 0123456789ABCDEF
        // Expected Ciphertext: 85E813540F0AB405
        let key: [UInt8] = [0x13, 0x34, 0x57, 0x79, 0x9B, 0xBC, 0xDF, 0xF1]
        let plaintext: [UInt8] = [0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF]
        let expectedCiphertext: [UInt8] = [0x85, 0xE8, 0x13, 0x54, 0x0F, 0x0A, 0xB4, 0x05]

        let ciphertext = RFBDES.encryptBlock(plaintext, key: key)
        XCTAssertEqual(ciphertext, expectedCiphertext)
    }

    func testVNCAuthChallengeResponseGeneration() {
        let challenge = Data(repeating: 0x42, count: 16)
        let response = RFBDES.computeVNCAuthResponse(challenge: challenge, password: "password123")
        XCTAssertNotNil(response)
        XCTAssertEqual(response?.count, 16)
    }
}
