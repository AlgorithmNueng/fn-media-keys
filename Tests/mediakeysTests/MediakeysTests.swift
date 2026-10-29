import XCTest

@testable import mediakeys

final class MediakeysTests: XCTestCase {
    private let suite = "mediakeysTests"
    private lazy var defaults = UserDefaults(suiteName: suite)!

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
    }

    func testEncodeMatchesWhatMagicKeyboardSends() {
        // play/pause (NX_KEYTYPE_PLAY = 16): down 0xA00, up 0xB00 below the key type
        XCTAssertEqual(MediaEvent.encode(.play, down: true), 0x10_0A00)
        XCTAssertEqual(MediaEvent.encode(.play, down: false), 0x10_0B00)
        XCTAssertEqual(MediaEvent.encode(.soundUp, down: true, isRepeat: true), 0x0A01)
    }

    func testOnlyVolumeAndBrightnessRepeat() {
        XCTAssertTrue(MediaKey.soundDown.repeats)
        XCTAssertTrue(MediaKey.brightnessUp.repeats)
        XCTAssertFalse(MediaKey.play.repeats)
        XCTAssertFalse(MediaKey.mute.repeats)

        XCTAssertTrue(Action.volumeUp.repeats)
        XCTAssertTrue(Action.brightnessDown.repeats)
        XCTAssertFalse(Action.playPause.repeats)
        XCTAssertFalse(Action.fKey.repeats)
    }

    // MARK: Action

    func testActionRawValuesArePersisted() {
        // Stored in UserDefaults: renaming one would silently reset the user's setting.
        XCTAssertEqual(
            Action.allCases.map(\.rawValue),
            [
                "fKey", "brightnessDown", "brightnessUp", "missionControl", "launchpad", "spotlight", "dictation", "doNotDisturb",
                "rewind", "playPause", "fastForward", "mute", "volumeDown", "volumeUp",
            ])
    }

    func testActionsPostTheirMediaKey() {
        XCTAssertNil(Action.fKey.media)
        XCTAssertEqual(Action.brightnessDown.media, .brightnessDown)
        XCTAssertEqual(Action.brightnessUp.media, .brightnessUp)
        XCTAssertEqual(Action.rewind.media, .rewind)
        XCTAssertEqual(Action.playPause.media, .play)
        XCTAssertEqual(Action.fastForward.media, .fast)
        XCTAssertEqual(Action.mute.media, .mute)
        XCTAssertEqual(Action.volumeDown.media, .soundDown)
        XCTAssertEqual(Action.volumeUp.media, .soundUp)
    }

    func testSystemActionsPostTheKeyCodesOfTheAppleRow() {
        // what the MacBook's F3-F6 and the Magic Keyboard's F3-F4 send, from the captures
        XCTAssertEqual(Action.missionControl.systemKeyCode, 160)
        XCTAssertEqual(Action.launchpad.systemKeyCode, 131)
        XCTAssertEqual(Action.spotlight.systemKeyCode, 177)
        XCTAssertEqual(Action.dictation.systemKeyCode, 176)
        XCTAssertEqual(Action.doNotDisturb.systemKeyCode, 178)

        let system: [Action] = [.missionControl, .launchpad, .spotlight, .dictation, .doNotDisturb]
        for action in Action.allCases where !system.contains(action) { XCTAssertNil(action.systemKeyCode, action.rawValue) }
        for action in system {
            XCTAssertNil(action.media, action.rawValue)
            XCTAssertFalse(action.repeats, action.rawValue)
            // the posted event must not be one the tap acts on, or it would loop back into the app
            XCTAssertNil(Layout.indexByKeyCode[Int(action.systemKeyCode!)], action.rawValue)
        }
    }

    func testEveryActionHasATitle() {
        XCTAssertEqual(Action.fKey.title, "F-key ปกติ (ไม่แปลง)")
        XCTAssertEqual(Action.missionControl.title, "Mission Control")
        XCTAssertEqual(Action.launchpad.title, "Launchpad")
        XCTAssertEqual(Action.spotlight.title, "Spotlight")
        XCTAssertEqual(Action.dictation.title, "ป้อนตามคำบอก")
        XCTAssertEqual(Action.doNotDisturb.title, "ห้ามรบกวน")
        XCTAssertEqual(Action.playPause.title, "เล่น/หยุด")
        XCTAssertEqual(Set(Action.allCases.map(\.title)).count, Action.allCases.count)
    }

    // MARK: Layout

    func testFnKeysFollowTheLucky65Row() {
        // key codes of F1...F12 in order, from the captures
        XCTAssertEqual(Layout.keys.map(\.keyCode), [122, 120, 99, 118, 96, 97, 98, 100, 101, 109, 103, 111])
        XCTAssertEqual(Layout.keys.map(\.usage), Array(0x3A...0x45))
        XCTAssertEqual(Layout.keys.map(\.name), (1...12).map { "F\($0)" })
        XCTAssertEqual(Layout.keys.map(\.index), Array(0..<12))
        XCTAssertEqual(
            Layout.keys.map(\.label),
            ["Fn+1", "Fn+2", "Fn+3", "Fn+4", "Fn+5", "Fn+6", "Fn+7", "Fn+8", "Fn+9", "Fn+0", "Fn+-", "Fn+="])
    }

    func testIndexByKeyCode() {
        XCTAssertEqual(Layout.indexByKeyCode[122], 0)  // F1
        XCTAssertEqual(Layout.indexByKeyCode[100], 7)  // F8
        XCTAssertEqual(Layout.indexByKeyCode[111], 11)  // F12
        XCTAssertNil(Layout.indexByKeyCode[0])  // A
    }

    func testDefaults() {
        XCTAssertEqual(Layout.keys[7].defaultAction, .playPause)  // F8
        XCTAssertEqual(Layout.keys[11].defaultAction, .fKey)  // F12 stays F12
        for index in 2...5 { XCTAssertEqual(Layout.keys[index].defaultAction, .fKey, "F\(index + 1)") }
        XCTAssertEqual(
            Layout.keys.map(\.defaultAction),
            [.brightnessDown, .brightnessUp, .fKey, .fKey, .fKey, .fKey, .rewind, .playPause, .fastForward, .mute, .volumeDown, .fKey])
    }

    func testMissingSettingGivesTheDefault() {
        for key in Layout.keys { XCTAssertEqual(Layout.action(at: key.index, in: defaults), key.defaultAction, key.name) }
    }

    func testStoredSettingWins() {
        defaults.set("volumeUp", forKey: "F8")
        defaults.set("fKey", forKey: "F1")
        XCTAssertEqual(Layout.action(at: 7, in: defaults), .volumeUp)
        XCTAssertEqual(Layout.action(at: 0, in: defaults), .fKey)
        XCTAssertEqual(Layout.action(at: 1, in: defaults), .brightnessUp)  // untouched
    }

    func testUnknownStoredSettingGivesTheDefault() {
        defaults.set("garbage", forKey: "F8")
        defaults.set(42, forKey: "F9")
        XCTAssertEqual(Layout.action(at: 7, in: defaults), .playPause)
        XCTAssertEqual(Layout.action(at: 8, in: defaults), .fastForward)
    }

    func testEnabledSwitch() {
        XCTAssertTrue(Layout.isEnabled(in: defaults))  // missing means on
        defaults.set(false, forKey: "enabled")
        XCTAssertFalse(Layout.isEnabled(in: defaults))
        defaults.set(true, forKey: "enabled")
        XCTAssertTrue(Layout.isEnabled(in: defaults))
    }

    // MARK: Keyboards

    func testKeyboardIDIsFourLowercaseHexDigitsEach() {
        XCTAssertEqual(Keyboards.id(vendorID: 0x0603, productID: 0x0351), "0603:0351")
        XCTAssertEqual(Keyboards.id(vendorID: 0x4C, productID: 0x267), "004c:0267")
        XCTAssertEqual(Keyboards.id(vendorID: 0xABCD, productID: 0xEF01), "abcd:ef01")
        XCTAssertEqual(Keyboard(vendorID: 0x0603, productID: 0x0351, name: "lucky65").id, Keyboards.defaultChoice)
    }

    func testParse() {
        XCTAssertEqual(Keyboards.parse("0603:0351"), ["0603:0351"])
        XCTAssertEqual(Keyboards.parse("0603:0351,004c:0267"), ["0603:0351", "004c:0267"])
        XCTAssertEqual(Keyboards.parse(""), [])
    }

    func testParseDropsDuplicatesAndNormalises() {
        XCTAssertEqual(Keyboards.parse("0603:0351,0603:0351"), ["0603:0351"])
        XCTAssertEqual(Keyboards.parse(" 004C:0267 , 0603:0351\n"), ["004c:0267", "0603:0351"])  // typed by hand
    }

    func testParseIgnoresInvalidEntries() {
        let invalid = [
            "garbage", "603:351", "0603:035", "0603:03510", "0603-0351", "0603:0351:0001", "0603", ":", "g603:0351",
            "+603:0351", "-603:0351", "0x03:0x0351", "０６０３:０３５１", "🙂🙂🙂🙂:🙂🙂🙂🙂", "0603 : 0351", "\0",
        ]
        for entry in invalid { XCTAssertEqual(Keyboards.parse(entry), [], entry) }
        XCTAssertEqual(Keyboards.parse(",,,"), [])
        // a valid entry survives the invalid ones around it
        XCTAssertEqual(Keyboards.parse("garbage,0603:0351,,603:351"), ["0603:0351"])
    }

    func testFormatIsSortedWithoutDuplicates() {
        XCTAssertEqual(Keyboards.format(["0603:0351", "004c:0267"]), "004c:0267,0603:0351")
        XCTAssertEqual(Keyboards.format(["0603:0351"]), "0603:0351")
        XCTAssertEqual(Keyboards.format([]), "")
        XCTAssertEqual(Keyboards.format(Keyboards.parse("0603:0351,004C:0267,0603:0351,junk")), "004c:0267,0603:0351")
    }

    func testMissingChoiceGivesTheLucky65() {
        XCTAssertEqual(Keyboards.chosen(in: defaults), ["0603:0351"])
        XCTAssertEqual(Keyboards.defaultChoice, "0603:0351")
        XCTAssertEqual(Keyboards.choiceKey, "keyboards")
    }

    func testEmptyChoiceMeansNoKeyboard() {
        defaults.set("", forKey: Keyboards.choiceKey)
        XCTAssertEqual(Keyboards.chosen(in: defaults), [])
    }

    func testStoredChoiceWins() {
        defaults.set("004c:0267", forKey: Keyboards.choiceKey)
        XCTAssertEqual(Keyboards.chosen(in: defaults), ["004c:0267"])  // the Lucky65 is no longer chosen
        defaults.set("0603:0351,004c:0267", forKey: Keyboards.choiceKey)
        XCTAssertEqual(Keyboards.chosen(in: defaults), ["0603:0351", "004c:0267"])
    }

    func testUnusableStoredChoiceDoesNotCrash() {
        defaults.set("garbage", forKey: Keyboards.choiceKey)
        XCTAssertEqual(Keyboards.chosen(in: defaults), [])
        // not a string: back to the default
        defaults.set(true, forKey: Keyboards.choiceKey)
        XCTAssertEqual(Keyboards.chosen(in: defaults), ["0603:0351"])
        defaults.set(["004c:0267"], forKey: Keyboards.choiceKey)
        XCTAssertEqual(Keyboards.chosen(in: defaults), ["0603:0351"])
    }

    // MARK: Remapper.decide

    private func decide(
        down: Bool = true, isRepeat: Bool = false, held: Action? = nil, setting: Action = .playPause,
        fromChosenKeyboard: Bool = true, hasModifier: Bool = false
    ) -> Remapper.Decision {
        Remapper.decide(
            isDown: down, isRepeat: isRepeat, held: held, setting: setting, fromChosenKeyboard: fromChosenKeyboard,
            hasModifier: hasModifier)
    }

    func testPressFromAChosenKeyboardPerformsTheSetting() {
        XCTAssertEqual(decide(setting: .playPause), .down(.playPause))
        XCTAssertEqual(decide(setting: .volumeUp), .down(.volumeUp))
    }

    func testPlainFKeySettingPasses() {
        XCTAssertEqual(decide(setting: .fKey), .pass)  // F12
    }

    func testKeyFromAKeyboardThatIsNotChosenPasses() {
        XCTAssertEqual(decide(fromChosenKeyboard: false), .pass)  // for example the MacBook keyboard
    }

    func testModifierPasses() {
        XCTAssertEqual(decide(hasModifier: true), .pass)
    }

    func testRepeatPostsOnlyForVolumeAndBrightness() {
        XCTAssertEqual(decide(isRepeat: true, held: .volumeDown), .repeatDown(.volumeDown))
        XCTAssertEqual(decide(isRepeat: true, held: .brightnessUp), .repeatDown(.brightnessUp))
        XCTAssertEqual(decide(isRepeat: true, held: .playPause), .swallow)
        XCTAssertEqual(decide(isRepeat: true, held: .mute), .swallow)
        XCTAssertEqual(decide(isRepeat: true, held: .spotlight), .swallow)
    }

    func testRepeatOfAKeyThatIsNotHeldPasses() {
        XCTAssertEqual(decide(isRepeat: true, held: nil), .pass)
        // the HID report is long gone by the time a repeat arrives, and the setting does not matter
        XCTAssertEqual(decide(isRepeat: true, held: nil, setting: .volumeUp, fromChosenKeyboard: false), .pass)
    }

    func testRepeatFollowsTheHeldActionNotTheSetting() {
        XCTAssertEqual(
            decide(isRepeat: true, held: .volumeUp, setting: .fKey, fromChosenKeyboard: false, hasModifier: true),
            .repeatDown(.volumeUp))
    }

    func testKeyUpEndsTheHeldActionEvenIfTheSettingChanged() {
        XCTAssertEqual(decide(down: false, held: .playPause, setting: .volumeUp), .up(.playPause))
        XCTAssertEqual(decide(down: false, held: .volumeUp, setting: .fKey, fromChosenKeyboard: false), .up(.volumeUp))
    }

    func testKeyUpOfAKeyThatIsNotHeldPasses() {
        XCTAssertEqual(decide(down: false, held: nil), .pass)
    }
}
