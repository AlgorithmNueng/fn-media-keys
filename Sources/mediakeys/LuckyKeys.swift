import Foundation
import IOKit.hid

/// Which keys the Lucky65 itself just reported. A key event reaches the event tap without any device attached, so the
/// HID layer is the only way to tell the Lucky65 from the MacBook keyboard. The HID report arrives a few ms before the event.
enum LuckyKeys {
    static let vendorID = 0x0603
    static let productID = 0x0351

    // IOHIDManager stops delivering callbacks once released.
    private static var manager: IOHIDManager?
    private static var lastDown: [Int: TimeInterval] = [:]

    /// Returns false when macOS refuses access (no Input Monitoring permission).
    static func start() -> Bool {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(manager, [kIOHIDVendorIDKey: vendorID, kIOHIDProductIDKey: productID] as CFDictionary)
        IOHIDManagerRegisterInputReportCallback(manager, onReport, nil)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)
        guard IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone)) == kIOReturnSuccess else { return false }
        self.manager = manager
        return true
    }

    /// Keyboard usages in a boot-protocol report: modifier byte, reserved byte, then up to six pressed usages.
    static func usages(in report: [UInt8]) -> [Int] {
        guard report.count == 8 else { return [] }
        return report.dropFirst(2).filter { $0 != 0 }.map(Int.init)
    }

    static func recentlyPressed(usage: Int) -> Bool {
        guard let at = lastDown[usage] else { return false }
        // A quick tap can release before its key event arrives, so a short grace period beats checking "is held".
        return ProcessInfo.processInfo.systemUptime - at < 0.1
    }

    fileprivate static func record(_ report: [UInt8]) {
        let now = ProcessInfo.processInfo.systemUptime
        for usage in usages(in: report) { lastDown[usage] = now }
    }
}

// Report id 0 is the unnumbered boot keyboard interface, the one the F-keys arrived on in the captures.
private let onReport: IOHIDReportCallback = { _, _, _, _, reportID, report, length in
    guard reportID == 0 else { return }
    LuckyKeys.record(Array(UnsafeBufferPointer(start: report, count: length)))
}
