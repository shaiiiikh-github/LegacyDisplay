import XCTest
@testable import RFBCore

final class RFBVersionTests: XCTestCase {

    func testStandardVersionParsing() {
        let v8 = RFBVersion.parse(from: "RFB 003.008\n")
        XCTAssertEqual(v8, RFBVersion.v3_8)
        XCTAssertEqual(v8?.wireData, Data("RFB 003.008\n".utf8))

        let v7 = RFBVersion.parse(from: "RFB 003.007\n")
        XCTAssertEqual(v7, RFBVersion.v3_7)

        let v3 = RFBVersion.parse(from: "RFB 003.003\n")
        XCTAssertEqual(v3, RFBVersion.v3_3)
    }

    func testRealVNCVersionParsing() {
        let v5 = RFBVersion.parse(from: "RFB 005.000\n")
        XCTAssertEqual(v5?.major, 5)
        XCTAssertEqual(v5?.minor, 0)
    }

    func testMalformedVersionParsing() {
        XCTAssertNil(RFBVersion.parse(from: "HTTP/1.1 200 OK\n"))
        XCTAssertNil(RFBVersion.parse(from: "RFB invalid\n"))
        XCTAssertNil(RFBVersion.parse(from: Data([0, 1, 2])))
    }

    func testVersionNegotiation() {
        // When server offers RFB 005.000 (RealVNC), standard client negotiates 3.8
        let negotiatedFrom5 = RFBVersion.negotiate(serverVersion: RFBVersion(major: 5, minor: 0))
        XCTAssertEqual(negotiatedFrom5, .v3_8)

        // When server offers 3.8, client negotiates 3.8
        let negotiatedFrom8 = RFBVersion.negotiate(serverVersion: .v3_8)
        XCTAssertEqual(negotiatedFrom8, .v3_8)

        // When server offers 3.7, client negotiates 3.7
        let negotiatedFrom7 = RFBVersion.negotiate(serverVersion: .v3_7)
        XCTAssertEqual(negotiatedFrom7, .v3_7)

        // When server offers 3.3, client negotiates 3.3
        let negotiatedFrom3 = RFBVersion.negotiate(serverVersion: .v3_3)
        XCTAssertEqual(negotiatedFrom3, .v3_3)
    }
}
