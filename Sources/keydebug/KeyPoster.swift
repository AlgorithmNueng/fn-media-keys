import CoreGraphics

/// Posts a synthetic key press, to find out which keys macOS acts on when they come from user space.
enum KeyPoster {
    /// Key-down then key-up at the HID event tap. Returns false when the events cannot be created.
    static func post(keyCode: CGKeyCode, flags: CGEventFlags) -> Bool {
        let events = [true, false].compactMap { CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: $0) }
        guard events.count == 2 else { return false }
        for event in events {
            event.flags = flags  // always set, even empty: a nil source would inherit the modifiers held right now
            event.post(tap: .cghidEventTap)
        }
        return true
    }
}
