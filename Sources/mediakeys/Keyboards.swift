import Foundation
import IOKit.hid

/// A keyboard as the user sees it. One physical keyboard exposes several HID interfaces; they all give the same one.
struct Keyboard: Hashable, Identifiable {
    let vendorID: Int
    let productID: Int
    let name: String

    /// "vvvv:pppp", also what the settings store.
    var id: String { Keyboards.id(vendorID: vendorID, productID: productID) }
}

/// Which keys the chosen keyboards just reported. A key event reaches the event tap without any device attached, so the
/// HID layer is the only way to tell a chosen keyboard from the MacBook keyboard. The HID value arrives a few ms before the event.
///
/// The process only ever receives the twelve F-key usages: every other key is filtered out by IOHIDManager before the
/// callback, so this code cannot see what is typed. Of those, only the presses of chosen keyboards are recorded.
enum Keyboards {
    /// UserDefaults key of the choice: the ids of the chosen keyboards in one comma-separated string.
    static let choiceKey = "keyboards"
    /// Used while the choice has never been saved: the Lucky65 V1 (wired).
    static let defaultChoice = "0603:0351"

    private static let keyboardPage = 0x07
    private static let usages = Layout.keys.map(\.usage)

    // IOHIDManager stops delivering callbacks once released.
    private static var manager: IOHIDManager?
    private static var isOpen = false
    private static var lastDown: [Int: TimeInterval] = [:]

    // MARK: Choice

    /// "vvvv:pppp": both IDs as four lowercase hex digits.
    static func id(vendorID: Int, productID: Int) -> String {
        String(format: "%04lx:%04lx", vendorID, productID)
    }

    /// The keyboard ids in a stored choice. Anything that is not a well-formed id is dropped (never trust stored data).
    static func parse(_ stored: String) -> Set<String> {
        let ids = stored.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        return Set(ids.filter(isID))
    }

    /// The stored form of a choice: sorted and without duplicates.
    static func format(_ ids: Set<String>) -> String {
        ids.sorted().joined(separator: ",")
    }

    /// The chosen keyboards. Never saved (or not a string) means the default; an empty string means none.
    static func chosen(in defaults: UserDefaults = .standard) -> Set<String> {
        parse(defaults.object(forKey: choiceKey) as? String ?? defaultChoice)
    }

    private static func isID(_ id: String) -> Bool {
        let parts = id.split(separator: ":", omittingEmptySubsequences: false)
        return parts.count == 2 && parts.allSatisfy { $0.count == 4 && $0.allSatisfy { $0.isASCII && $0.isHexDigit } }
    }

    // MARK: HID

    /// The keyboards macOS lists right now, one per vendor and product, sorted by name. The manager only has to exist:
    /// listing devices needs no permission (reading their input, `open`, does).
    static var connected: [Keyboard] {
        guard let manager, let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else { return [] }
        return Dictionary(grouping: devices, by: \.keyboardID).map { id, interfaces in
            // Not every interface carries a product name; the smallest one keeps the name from changing between polls.
            Keyboard(
                vendorID: interfaces[0].int(kIOHIDVendorIDKey), productID: interfaces[0].int(kIOHIDProductIDKey),
                name: interfaces.compactMap(\.productName).min() ?? id)
        }
        .sorted { ($0.name.lowercased(), $0.id) < ($1.name.lowercased(), $1.id) }
    }

    /// Creates, matches and schedules the manager, once. Needs no permission (only `open` does).
    static func setUp() {
        guard manager == nil else { return }
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        // One dictionary only: with several, IOHIDManager reports a device once per match.
        IOHIDManagerSetDeviceMatching(manager, [
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

    fileprivate static func record(page: Int, usage: Int, value: Int, device: IOHIDDevice) {
        // The matching above already limits the values; checked again because seeing any other key must be impossible.
        guard page == keyboardPage, usages.contains(usage), value == 1 else { return }
        // Read here, on an F-key press only, so a change of the choice applies to the next press.
        guard chosen().contains(device.keyboardID) else { return }
        lastDown[usage] = ProcessInfo.processInfo.systemUptime
    }
}

private extension IOHIDDevice {
    func int(_ key: String) -> Int { IOHIDDeviceGetProperty(self, key as CFString) as? Int ?? 0 }

    /// Nil when the interface has no (or an empty) product string.
    var productName: String? {
        (IOHIDDeviceGetProperty(self, kIOHIDProductKey as CFString) as? String).flatMap { $0.isEmpty ? nil : $0 }
    }

    var keyboardID: String { Keyboards.id(vendorID: int(kIOHIDVendorIDKey), productID: int(kIOHIDProductIDKey)) }
}

// The F-keys arrive as elements of the boot keyboard interface: value 1 on press, 0 on release.
private let onValue: IOHIDValueCallback = { _, _, _, value in
    let element = IOHIDValueGetElement(value)
    Keyboards.record(
        page: Int(IOHIDElementGetUsagePage(element)), usage: Int(IOHIDElementGetUsage(element)),
        value: IOHIDValueGetIntegerValue(value), device: IOHIDElementGetDevice(element))
}
