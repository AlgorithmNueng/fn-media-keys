import CoreGraphics
import XCTest

@testable import keydebug

final class NamesTests: XCTestCase {
    func testKeyboardUsages() {
        XCTAssertEqual(Names.usage(page: 0x07, usage: 0x04), "A")
        XCTAssertEqual(Names.usage(page: 0x07, usage: 0x22), "5")
        XCTAssertEqual(Names.usage(page: 0x07, usage: 0x3E), "F5")
        XCTAssertEqual(Names.usage(page: 0x07, usage: 0x68), "F13")
        XCTAssertEqual(Names.usage(page: 0x07, usage: 0xE3), "LGui")
    }

    func testConsumerUsages() {
        XCTAssertEqual(Names.usage(page: 0x0C, usage: 0xCD), "PlayPause")
        XCTAssertEqual(Names.usage(page: 0x0C, usage: 0xE9), "VolumeUp")
    }

    func testUnknownUsageIsEmpty() {
        XCTAssertEqual(Names.usage(page: 0xFF01, usage: 0x30), "")
        XCTAssertEqual(Names.usage(page: 0x0C, usage: 0x999), "")
    }

    func testMediaKeys() {
        XCTAssertEqual(Names.mediaKey(16), "PLAY")
        XCTAssertEqual(Names.mediaKey(99), "KEYTYPE_99")
    }

    func testVirtualKeys() {
        XCTAssertEqual(Names.virtualKey(0x60), "F5")
        XCTAssertEqual(Names.virtualKey(0x3F), "fn")
    }

    func testFlags() {
        XCTAssertEqual(Names.flags([]), "-")
        XCTAssertEqual(Names.flags([.maskSecondaryFn, .maskShift]), "shift+fn")
    }
}
