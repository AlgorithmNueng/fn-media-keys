import AppKit

/// Posts the system-defined event a Magic Keyboard media key produces.
enum MediaEvent {
    /// data1 of an NX_SYSDEFINED aux-control event: key type << 16 | state << 8 (0xA down, 0xB up) | repeat flag.
    static func encode(_ key: MediaKey, down: Bool, isRepeat: Bool = false) -> Int {
        Int(key.rawValue) << 16 | (down ? 0xA : 0xB) << 8 | (isRepeat ? 1 : 0)
    }

    static func post(_ key: MediaKey, down: Bool, isRepeat: Bool = false) {
        NSEvent.otherEvent(
            with: .systemDefined, location: .zero,
            modifierFlags: NSEvent.ModifierFlags(rawValue: down ? 0xA00 : 0xB00),
            timestamp: 0, windowNumber: 0, context: nil,
            subtype: 8, data1: encode(key, down: down, isRepeat: isRepeat), data2: -1
        )?.cgEvent?.post(tap: .cghidEventTap)
    }
}
