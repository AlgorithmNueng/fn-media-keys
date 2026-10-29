import Foundation
import IOKit.hid

/// Which keys the Lucky65 itself just reported. A key event reaches the event tap without any device attached, so the
/// HID layer is the only way to tell the Lucky65 from the MacBook keyboard. The HID value arrives a few ms before the event.
///
/// The process only ever receives the twelve F-key usages: every other key is filtered out by IOHIDManager before the
/// callback, so this code cannot see what is typed.
enum LuckyKeys {
    static let vendorID = 0x0603
    static let productID = 0x0351

    private static let keyboardPage = 0x07
    private static let usages = Layout.keys.map(\.usage)

    // IOHIDManager stops delivering callbacks once released.
    private static var manager: IOHIDManager?
    private static var isOpen = false
    private static var lastDown: [Int: TimeInterval] = [:]

    /// Whether the manager currently sees a Lucky65 keyboard interface.
    static var connected: Bool {
        guard let manager, let devices = IOHIDManagerCopyDevices(manager) else { return false }
        return CFSetGetCount(devices) > 0
    }

    /// Creates, matches and schedules the manager, once. Needs no permission (only `open` does).
    static func setUp() {
        guard manager == nil else { return }
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        // One dictionary only: with several, IOHIDManager reports a device once per match.
        IOHIDManagerSetDeviceMatching(manager, [
            kIOHIDVendorIDKey: vendorID, kIOHIDProductIDKey: productID,
            kIOHIDPrimaryUsagePageKey: 0x01, kIOHIDPrimaryUsageKey: 0x06,  // keyboard interfaces only
        ] as CFDictionary)
        IOHIDManagerSetInputValueMatchingMultiple(
            manager, usages.map { [kIOHIDElementUsagePageKey: keyboardPage, kIOHIDElementUsageKey: $0] } as CFArray)
        IOHIDManagerRegisterInputValueCallback(manager, onValue, nil)
        // Common modes: in the default mode alone the callbacks would stop while a menu is open and keys would slip through.
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue)
        self.manager = manager
    }

    /// Returns false when macOS refuses access (no Input Monitoring permission); call again once it is granted.
    static func open() -> Bool {
        setUp()
        guard let manager else { return false }
        if !isOpen { isOpen = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess }
        return isOpen
    }

    static func recentlyPressed(usage: Int) -> Bool {
        guard let at = lastDown[usage] else { return false }
        // A quick tap can release before its key event arrives, so a short grace period beats checking "is held".
        return ProcessInfo.processInfo.systemUptime - at < 0.1
    }

    fileprivate static func record(page: Int, usage: Int, value: Int) {
        // The matching above already limits the values; checked again because seeing any other key must be impossible.
        guard page == keyboardPage, usages.contains(usage), value == 1 else { return }
        lastDown[usage] = ProcessInfo.processInfo.systemUptime
    }
}

// The F-keys arrive as elements of the boot keyboard interface: value 1 on press, 0 on release.
private let onValue: IOHIDValueCallback = { _, _, _, value in
    let element = IOHIDValueGetElement(value)
    LuckyKeys.record(
        page: Int(IOHIDElementGetUsagePage(element)), usage: Int(IOHIDElementGetUsage(element)),
        value: IOHIDValueGetIntegerValue(value))
}
