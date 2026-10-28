import AppKit

/// Swallows the mapped F-keys when they come from the Lucky65 and posts the Magic Keyboard media key instead.
enum Remapper {
    fileprivate static var tap: CFMachPort?
    // Key codes whose key-down we swallowed, until their key-up: the up must be swallowed too, and the HID report has
    // long been released by then.
    fileprivate static var held: Set<Int> = []

    /// Returns false when the tap cannot be created (no Accessibility / Input Monitoring permission).
    static func start() -> Bool {
        let mask: CGEventMask = 1 << CGEventType.keyDown.rawValue | 1 << CGEventType.keyUp.rawValue
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: mask, callback: onEvent, userInfo: nil)
        else { return false }
        self.tap = tap
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0), .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }
}

private func onEvent(_: CGEventTapProxy, type: CGEventType, event: CGEvent, _: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    let pass = Unmanaged.passUnretained(event)
    // macOS turns a tap off when its callback is slow; without this the keys would silently stop being mapped.
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = Remapper.tap { CGEvent.tapEnable(tap: tap, enable: true) }
        return pass
    }

    let code = Int(event.getIntegerValueField(.keyboardEventKeycode))
    guard let (usage, media) = Layout.keys[code] else { return pass }

    switch type {
    case .keyDown:
        if Remapper.held.contains(code) {
            if event.getIntegerValueField(.keyboardEventAutorepeat) != 0, media.repeats {
                MediaEvent.post(media, down: true, isRepeat: true)
            }
            return nil
        }
        // Any real modifier means the user wants the plain F-key (the escape hatch to get F8 itself).
        let modifiers: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskCommand]
        guard LuckyKeys.recentlyPressed(usage: usage), event.flags.isDisjoint(with: modifiers) else { return pass }
        Remapper.held.insert(code)
        MediaEvent.post(media, down: true)
        print("F\(usage - 0x3A + 1) -> \(media)")
        return nil
    case .keyUp:
        guard Remapper.held.remove(code) != nil else { return pass }
        MediaEvent.post(media, down: false)
        return nil
    default:
        return pass
    }
}
