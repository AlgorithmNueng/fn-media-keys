import AppKit

/// Swallows the F-keys that are set to an action when they come from the Lucky65, and performs the action instead.
enum Remapper {
    enum Decision: Equatable {
        case pass  // let the event through
        case swallow  // drop it, nothing to do
        case down(Action), repeatDown(Action), up(Action)  // drop it and perform the action
    }

    fileprivate static var tap: CFMachPort?
    fileprivate static var source: CFRunLoopSource?
    // The action each swallowed key-down started, by key code, until its key-up: the up must be swallowed too (the HID
    // value has long been released by then) and must end the same action even if the setting changed in between.
    fileprivate static var held: [Int: Action] = [:]

    /// What to do with a key event. `held` is the action of the key's own earlier key-down, `setting` what the key is set to now.
    static func decide(
        isDown: Bool, isRepeat: Bool, held: Action?, setting: Action, fromLucky65: Bool, hasModifier: Bool
    ) -> Decision {
        guard isDown else { return held.map { .up($0) } ?? .pass }
        if isRepeat {
            guard let held else { return .pass }
            return held.repeats ? .repeatDown(held) : .swallow
        }
        // Any real modifier means the user wants the plain F-key (the escape hatch to get F8 itself).
        return setting == .fKey || !fromLucky65 || hasModifier ? .pass : .down(setting)
    }

    /// Returns false when the tap cannot be created (no Accessibility / Input Monitoring permission). Does nothing when already running.
    static func start() -> Bool {
        guard tap == nil else { return true }
        let mask: CGEventMask = 1 << CGEventType.keyDown.rawValue | 1 << CGEventType.keyUp.rawValue
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap,
            eventsOfInterest: mask, callback: onEvent, userInfo: nil)
        else { return false }
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        self.tap = tap
        self.source = source
        return true
    }

    static func stop() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        CFMachPortInvalidate(tap)
        self.tap = nil
        source = nil
        held = [:]
    }
}

private let modifiers: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskCommand]

private func onEvent(_: CGEventTapProxy, type: CGEventType, event: CGEvent, _: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    let pass = Unmanaged.passUnretained(event)
    // macOS turns a tap off when its callback is slow; without this the keys would silently stop being mapped.
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let tap = Remapper.tap { CGEvent.tapEnable(tap: tap, enable: true) }
        return pass
    }

    let code = Int(event.getIntegerValueField(.keyboardEventKeycode))
    guard let index = Layout.indexByKeyCode[code] else { return pass }

    let decision = Remapper.decide(
        isDown: type == .keyDown,
        isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0,
        held: Remapper.held[code],
        setting: Layout.isEnabled() ? Layout.action(at: index) : .fKey,
        fromLucky65: LuckyKeys.recentlyPressed(usage: Layout.keys[index].usage),
        hasModifier: !event.flags.isDisjoint(with: modifiers))

    switch decision {
    case .pass:
        // Also forgets a key whose key-up was missed, so it cannot stay swallowed.
        Remapper.held[code] = nil
        return pass
    case .swallow:
        return nil
    case .down(let action):
        Remapper.held[code] = action
        action.perform(down: true, isRepeat: false)
        return nil
    case .repeatDown(let action):
        action.perform(down: true, isRepeat: true)
        return nil
    case .up(let action):
        Remapper.held[code] = nil
        action.perform(down: false, isRepeat: false)
        return nil
    }
}
