/// NX_KEYTYPE_* codes of the media keys a Magic Keyboard sends (IOKit ev_keymap.h).
enum MediaKey: Int32 {
    case soundUp = 0, soundDown = 1, brightnessUp = 2, brightnessDown = 3, mute = 7
    case play = 16, fast = 19, rewind = 20

    /// A held volume or brightness key keeps repeating; a held play key must not toggle again.
    var repeats: Bool {
        [.soundUp, .soundDown, .brightnessUp, .brightnessDown].contains(self)
    }
}

enum Layout {
    /// The Magic Keyboard function row, by macOS key code. `usage` is the HID keyboard usage the Lucky65 sends for the
    /// same key (F1 = 0x3A ... F12 = 0x45). F3-F6 (Mission Control, Spotlight, Dictation, Do Not Disturb) are not mapped
    /// yet and pass through as plain F-keys.
    static let keys: [Int: (usage: Int, media: MediaKey)] = [
        122: (0x3A, .brightnessDown),  // F1
        120: (0x3B, .brightnessUp),    // F2
        98: (0x40, .rewind),           // F7
        100: (0x41, .play),            // F8
        101: (0x42, .fast),            // F9
        109: (0x43, .mute),            // F10
        103: (0x44, .soundDown),       // F11
        111: (0x45, .soundUp),         // F12
    ]
}
