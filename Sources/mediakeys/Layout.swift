import CoreGraphics
import Foundation

/// NX_KEYTYPE_* codes of the media keys a Magic Keyboard sends (IOKit ev_keymap.h).
enum MediaKey: Int32 {
    case soundUp = 0, soundDown = 1, brightnessUp = 2, brightnessDown = 3, mute = 7
    case play = 16, fast = 19, rewind = 20

    /// A held volume or brightness key keeps repeating; a held play key must not toggle again.
    var repeats: Bool {
        [.soundUp, .soundDown, .brightnessUp, .brightnessDown].contains(self)
    }
}

/// What an Fn key does. The raw value is what UserDefaults stores, so never rename a case.
/// A new action is a case and its `title` here, plus what it does in `perform` (Actions.swift).
enum Action: String, CaseIterable {
    case fKey, brightnessDown, brightnessUp, spotlight, dictation, doNotDisturb
    case rewind, playPause, fastForward, mute, volumeDown, volumeUp

    /// Shown in the settings UI.
    var title: String {
        switch self {
        case .fKey: "F-key ปกติ (ไม่แปลง)"
        case .brightnessDown: "ลดความสว่างจอ"
        case .brightnessUp: "เพิ่มความสว่างจอ"
        case .spotlight: "Spotlight"
        case .dictation: "ป้อนตามคำบอก"
        case .doNotDisturb: "ห้ามรบกวน"
        case .rewind: "เพลงก่อนหน้า"
        case .playPause: "เล่น/หยุด"
        case .fastForward: "เพลงถัดไป"
        case .mute: "ปิดเสียง"
        case .volumeDown: "ลดเสียง"
        case .volumeUp: "เพิ่มเสียง"
        }
    }

    /// The Magic Keyboard media key this action posts; nil for actions that are not a media key.
    var media: MediaKey? {
        switch self {
        case .brightnessDown: .brightnessDown
        case .brightnessUp: .brightnessUp
        case .rewind: .rewind
        case .playPause: .play
        case .fastForward: .fast
        case .mute: .mute
        case .volumeDown: .soundDown
        case .volumeUp: .soundUp
        default: nil
        }
    }

    /// The key code this action posts; nil for the other actions. They are what the MacBook's F4-F6 (Spotlight, Dictation,
    /// Do Not Disturb) produce in special-key mode: key down and key up with the fn flag.
    var systemKeyCode: CGKeyCode? {
        switch self {
        case .spotlight: 177
        case .dictation: 176
        case .doNotDisturb: 178
        default: nil
        }
    }

    var repeats: Bool { media?.repeats ?? false }
}

/// One of the Lucky65's twelve Fn keys, which send plain F1 ... F12.
struct FnKey {
    let index: Int
    /// macOS key code of the F-key.
    let keyCode: Int
    /// What is printed on the Lucky65 key.
    let label: String
    let defaultAction: Action

    /// HID keyboard usage the Lucky65 sends (F1 = 0x3A ... F12 = 0x45).
    var usage: Int { 0x3A + index }
    /// "F1" ... "F12", also the UserDefaults key of the setting.
    var name: String { "F\(index + 1)" }
}

/// The settings live in UserDefaults and are read on every key press, so whatever writes them (a settings UI, `defaults write`)
/// takes effect at once and nothing has to be notified.
enum Layout {
    static let enabledKey = "enabled"

    /// F1 ... F12 in order.
    static let keys: [FnKey] = {
        let rows: [(keyCode: Int, label: String, action: Action)] = [
            (122, "Fn+1", .brightnessDown),
            (120, "Fn+2", .brightnessUp),
            (99, "Fn+3", .fKey),
            (118, "Fn+4", .fKey),
            (96, "Fn+5", .fKey),
            (97, "Fn+6", .fKey),
            (98, "Fn+7", .rewind),
            (100, "Fn+8", .playPause),
            (101, "Fn+9", .fastForward),
            (109, "Fn+0", .mute),
            (103, "Fn+-", .volumeDown),
            (111, "Fn+=", .fKey),  // stays F12 for the browser dev tools
        ]
        return rows.enumerated().map { FnKey(index: $0, keyCode: $1.keyCode, label: $1.label, defaultAction: $1.action) }
    }()

    /// Index into `keys` by macOS key code; nil for every other key.
    static let indexByKeyCode = Dictionary(uniqueKeysWithValues: keys.map { ($0.keyCode, $0.index) })

    /// The saved action of a key. A missing or unknown value (never trust stored data) gives the default.
    static func action(at index: Int, in defaults: UserDefaults = .standard) -> Action {
        let key = keys[index]
        return defaults.string(forKey: key.name).flatMap(Action.init(rawValue:)) ?? key.defaultAction
    }

    /// The master switch: off means every key stays a plain F-key. Missing means on.
    static func isEnabled(in defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: enabledKey) as? Bool ?? true
    }
}
