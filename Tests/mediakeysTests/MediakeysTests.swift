import XCTest

@testable import mediakeys

final class MediakeysTests: XCTestCase {
    func testEncodeMatchesWhatMagicKeyboardSends() {
        // play/pause (NX_KEYTYPE_PLAY = 16): down 0xA00, up 0xB00 below the key type
        XCTAssertEqual(MediaEvent.encode(.play, down: true), 0x10_0A00)
        XCTAssertEqual(MediaEvent.encode(.play, down: false), 0x10_0B00)
        XCTAssertEqual(MediaEvent.encode(.soundUp, down: true, isRepeat: true), 0x0A01)
    }

    func testLayoutFollowsTheMagicKeyboardRow() {
        XCTAssertEqual(Layout.keys[100]?.media, .play)  // F8
        XCTAssertEqual(Layout.keys[100]?.usage, 0x41)
        XCTAssertEqual(Layout.keys[111]?.media, .soundUp)  // F12
        XCTAssertNil(Layout.keys[96])  // F5 (dictation) is not mapped yet
    }

    func testEveryMappedKeyUsesItsFunctionKeyUsage() {
        // key codes of F1...F12 in order, from the captures
        let keyCodes = [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111]
        for (index, code) in keyCodes.enumerated() {
            if let entry = Layout.keys[code] { XCTAssertEqual(entry.usage, 0x3A + index, "F\(index + 1)") }
        }
    }

    func testOnlyVolumeAndBrightnessRepeat() {
        XCTAssertTrue(MediaKey.soundDown.repeats)
        XCTAssertTrue(MediaKey.brightnessUp.repeats)
        XCTAssertFalse(MediaKey.play.repeats)
        XCTAssertFalse(MediaKey.mute.repeats)
    }

    func testUsagesInBootReport() {
        XCTAssertEqual(LuckyKeys.usages(in: [0, 0, 0x41, 0, 0, 0, 0, 0]), [0x41])
        XCTAssertEqual(LuckyKeys.usages(in: [0x08, 0, 0x2B, 0x41, 0, 0, 0, 0]), [0x2B, 0x41])  // modifier byte is skipped
        XCTAssertEqual(LuckyKeys.usages(in: [0, 0, 0, 0, 0, 0, 0, 0]), [])
        XCTAssertEqual(LuckyKeys.usages(in: [0, 0, 0x41]), [])  // not a boot report
    }
}
