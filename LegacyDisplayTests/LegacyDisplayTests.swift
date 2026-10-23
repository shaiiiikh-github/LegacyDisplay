import XCTest
@testable import LegacyDisplay

final class LegacyDisplayTests: XCTestCase {

    var viewController: ViewController!

    override func setUpWithError() throws {
        try super.setUpWithError()
        viewController = ViewController()
        viewController.loadViewIfNeeded()
    }

    override func tearDownWithError() throws {
        viewController = nil
        try super.tearDownWithError()
    }

    func testViewControllerLoads() throws {
        XCTAssertNotNil(viewController.view, "ViewController view should be loaded")
    }

    func testTitleLabelConfiguration() throws {
        XCTAssertEqual(viewController.titleLabel.text, "LegacyDisplay")
    }

    func testStatusLabelConfiguration() throws {
        XCTAssertEqual(viewController.statusLabel.text, "Native Swift/UIKit Initialized")
    }

    func testDisplayCardContent() throws {
        XCTAssertEqual(viewController.cardContentLabel.text, "Display Target Ready")
    }
}
