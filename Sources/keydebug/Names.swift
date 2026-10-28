import CoreGraphics

/// Human-readable names for the numbers the debugger prints. Unknown values map to "".
enum Names {
    static func hex(_ value: Int, width: Int = 4) -> String {
        "0x" + String(format: "%0\(width)X", value)
    }

    /// HID usage (page 0x07 keyboard, page 0x0C consumer).
    static func usage(page: Int, usage: Int) -> String {
        switch page {
        case 0x07: return keyboard(usage)
        case 0x0C: return consumer[usage] ?? ""
        default: return ""
        }
    }

    /// NX_KEYTYPE_* code carried by a system-defined media-key event.
    static func mediaKey(_ code: Int) -> String {
        mediaKeys[code] ?? "KEYTYPE_\(code)"
    }

    /// macOS virtual key code (kVK_*).
    static func virtualKey(_ code: Int) -> String {
        virtualKeys[code] ?? ""
    }

    static func flags(_ flags: CGEventFlags) -> String {
        let names: [(CGEventFlags, String)] = [
            (.maskShift, "shift"), (.maskControl, "ctrl"), (.maskAlternate, "opt"),
            (.maskCommand, "cmd"), (.maskSecondaryFn, "fn"), (.maskAlphaShift, "caps"),
        ]
        let joined = names.filter { flags.contains($0.0) }.map(\.1).joined(separator: "+")
        return joined.isEmpty ? "-" : joined
    }

    private static func keyboard(_ usage: Int) -> String {
        switch usage {
        case 0x04...0x1D: return String(UnicodeScalar(UInt8(0x41 + usage - 0x04)))
        case 0x1E...0x26: return String(usage - 0x1E + 1)
        case 0x27: return "0"
        case 0x3A...0x45: return "F\(usage - 0x3A + 1)"
        case 0x68...0x73: return "F\(usage - 0x68 + 13)"
        case 0xE0...0xE7: return ["LCtrl", "LShift", "LAlt", "LGui", "RCtrl", "RShift", "RAlt", "RGui"][usage - 0xE0]
        default: return keyboardKeys[usage] ?? ""
        }
    }

    private static let keyboardKeys: [Int: String] = [
        0x28: "Return", 0x29: "Escape", 0x2A: "Backspace", 0x2B: "Tab", 0x2C: "Space",
        0x39: "CapsLock", 0x46: "PrintScreen", 0x47: "ScrollLock", 0x48: "Pause",
        0x49: "Insert", 0x4A: "Home", 0x4B: "PageUp", 0x4C: "Delete", 0x4D: "End", 0x4E: "PageDown",
        0x4F: "Right", 0x50: "Left", 0x51: "Down", 0x52: "Up",
    ]

    private static let consumer: [Int: String] = [
        0x30: "Power", 0x6F: "BrightnessUp", 0x70: "BrightnessDown",
        0xB0: "Play", 0xB1: "Pause", 0xB3: "FastForward", 0xB4: "Rewind",
        0xB5: "ScanNext", 0xB6: "ScanPrevious", 0xB7: "Stop", 0xB8: "Eject", 0xCD: "PlayPause",
        0xE2: "Mute", 0xE9: "VolumeUp", 0xEA: "VolumeDown",
        0x183: "ConsumerControl", 0x18A: "Mail", 0x192: "Calculator", 0x194: "FileBrowser",
        0x221: "Search", 0x223: "Home", 0x224: "Back", 0x225: "Forward", 0x227: "Refresh",
    ]

    // IOKit ev_keymap.h NX_KEYTYPE_*
    private static let mediaKeys: [Int: String] = [
        0: "SOUND_UP", 1: "SOUND_DOWN", 2: "BRIGHTNESS_UP", 3: "BRIGHTNESS_DOWN", 4: "CAPS_LOCK",
        5: "HELP", 6: "POWER", 7: "MUTE", 10: "NUM_LOCK", 13: "LAUNCH_PANEL", 14: "EJECT",
        15: "VIDMIRROR", 16: "PLAY", 17: "NEXT", 18: "PREVIOUS", 19: "FAST", 20: "REWIND",
        21: "ILLUMINATION_UP", 22: "ILLUMINATION_DOWN", 23: "ILLUMINATION_TOGGLE",
    ]

    // Carbon HIToolbox kVK_* (ANSI), the ones a laptop-style layout is likely to hit.
    private static let virtualKeys: [Int: String] = [
        0x12: "1", 0x13: "2", 0x14: "3", 0x15: "4", 0x17: "5", 0x16: "6", 0x1A: "7", 0x1C: "8", 0x19: "9", 0x1D: "0",
        0x7A: "F1", 0x78: "F2", 0x63: "F3", 0x76: "F4", 0x60: "F5", 0x61: "F6",
        0x62: "F7", 0x64: "F8", 0x65: "F9", 0x6D: "F10", 0x67: "F11", 0x6F: "F12",
        0x24: "Return", 0x30: "Tab", 0x31: "Space", 0x33: "Delete", 0x35: "Escape", 0x75: "ForwardDelete",
        0x73: "Home", 0x77: "End", 0x74: "PageUp", 0x79: "PageDown",
        0x7B: "Left", 0x7C: "Right", 0x7D: "Down", 0x7E: "Up",
        0x3F: "fn", 0x38: "Shift", 0x3B: "Control", 0x3A: "Option", 0x37: "Command",
    ]
}
