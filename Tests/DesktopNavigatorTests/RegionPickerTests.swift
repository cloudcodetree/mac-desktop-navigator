import XCTest
@testable import DesktopNavigator

final class RegionPickerGeometryTests: XCTestCase {
    typealias G = RegionPicker.Geometry

    func testSelectionIsNormalizedRegardlessOfDragDirection() {
        let expected = CGRect(x: 10, y: 10, width: 40, height: 20)
        XCTAssertEqual(G.selection(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 50, y: 30)), expected)
        XCTAssertEqual(G.selection(from: CGPoint(x: 50, y: 30), to: CGPoint(x: 10, y: 10)), expected)
        XCTAssertEqual(G.selection(from: CGPoint(x: 50, y: 10), to: CGPoint(x: 10, y: 30)), expected)
    }

    func testSelectionIsSnappedToWholePoints() {
        let r = G.selection(from: CGPoint(x: 10.4, y: 10.6), to: CGPoint(x: 50.2, y: 30.7))
        XCTAssertEqual(r, CGRect(x: 10, y: 10, width: 41, height: 21))
    }

    func testClickWithoutDragIsTooSmall() {
        XCTAssertTrue(G.isTooSmall(CGRect(x: 0, y: 0, width: 3, height: 3)))
        XCTAssertTrue(G.isTooSmall(CGRect(x: 0, y: 0, width: 100, height: 2)))
        XCTAssertFalse(G.isTooSmall(CGRect(x: 0, y: 0, width: 4, height: 4)))
    }

    func testCaptureRectFlipsCocoaToCoreGraphicsUsingPrimaryScreenHeight() {
        // Cocoa: origin bottom-left. A 200x100 rect whose top edge is 80pt below the top of a 1080pt screen.
        let cocoa = CGRect(x: 100, y: 900, width: 200, height: 100)
        XCTAssertEqual(G.captureRect(cocoa: cocoa, primaryScreenHeight: 1080), CGRect(x: 100, y: 80, width: 200, height: 100))
    }

    func testCaptureRectOnSecondaryDisplayStillFlipsAgainstPrimaryHeight() {
        // A display to the left and lower than the primary: negative x, y below the primary's bottom.
        let cocoa = CGRect(x: -500, y: -200, width: 50, height: 50)
        XCTAssertEqual(G.captureRect(cocoa: cocoa, primaryScreenHeight: 1080), CGRect(x: -500, y: 1230, width: 50, height: 50))
    }
}
