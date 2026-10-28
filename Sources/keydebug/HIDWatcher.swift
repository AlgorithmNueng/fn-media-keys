import Foundation
import IOKit.hid

/// Which HID devices to look at. Default: keyboards (media keys arrive on the keyboard's own consumer report).
struct DeviceFilter {
    var vendorID: Int?
    var productID: Int?
    var all = false

    /// Matching dictionary for IOHIDManager; nil matches every HID device.
    /// Only ever one dictionary: with several, IOHIDManager reports a device once per match and every event prints twice.
    var matching: [String: Any]? {
        if vendorID != nil || productID != nil {
            var match: [String: Any] = [:]
            if let vendorID { match[kIOHIDVendorIDKey] = vendorID }
            if let productID { match[kIOHIDProductIDKey] = productID }
            return match
        }
        return all ? nil : [kIOHIDDeviceUsagePageKey: 0x01, kIOHIDDeviceUsageKey: 0x06]
    }
}

extension IOHIDDevice {
    func property(_ key: String) -> Any? { IOHIDDeviceGetProperty(self, key as CFString) }
    func int(_ key: String) -> Int { property(key) as? Int ?? 0 }

    /// One physical keyboard exposes several HID interfaces under the same name, so the registry id tells them apart.
    var label: String {
        var id: UInt64 = 0
        IORegistryEntryGetRegistryEntryID(IOHIDDeviceGetService(self), &id)
        // Some interfaces carry no product string; fall back to vendor:product.
        let name = property(kIOHIDProductKey) as? String ?? "\(Names.hex(int(kIOHIDVendorIDKey))):\(Names.hex(int(kIOHIDProductIDKey)))"
        return "\(name)#" + String(id & 0xFFFF, radix: 16)
    }
}

enum HIDWatcher {
    // IOHIDManager stops delivering callbacks once released.
    private static var manager: IOHIDManager?

    static func list(_ filter: DeviceFilter) {
        let devices = (IOHIDManagerCopyDevices(makeManager(filter)) as? Set<IOHIDDevice>) ?? []
        for device in devices.sorted(by: { $0.label < $1.label }) {
            let descriptor = (device.property(kIOHIDReportDescriptorKey) as? Data)?.count ?? 0
            let pairs = (device.property(kIOHIDDeviceUsagePairsKey) as? [[String: Int]] ?? [])
                .map { Names.hex($0[kIOHIDDeviceUsagePageKey] ?? 0) + ":" + Names.hex($0[kIOHIDDeviceUsageKey] ?? 0) }
            print("\(device.label)  \(Names.hex(device.int(kIOHIDVendorIDKey))):\(Names.hex(device.int(kIOHIDProductIDKey)))"
                + "  \(device.property(kIOHIDTransportKey) as? String ?? "?")  descriptor \(descriptor) B")
            print("    usage pairs: " + pairs.joined(separator: " "))
        }
        print("\(devices.count) device(s)")
    }

    /// Starts listening on the main run loop. Returns false when macOS refuses access.
    static func watch(_ filter: DeviceFilter) -> Bool {
        let manager = makeManager(filter)
        IOHIDManagerRegisterDeviceMatchingCallback(manager, onAttach, nil)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, onDetach, nil)
        IOHIDManagerRegisterInputValueCallback(manager, onValue, nil)
        IOHIDManagerRegisterInputReportCallback(manager, onReport, nil)
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetMain(), CFRunLoopMode.defaultMode.rawValue)

        // Shared open (no seize): the keyboard keeps working while we listen.
        let result = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        guard result == kIOReturnSuccess else {
            fputs("error: IOHIDManagerOpen failed (\(Names.hex(Int(result), width: 8))). "
                + "Allow this app under System Settings > Privacy & Security > Input Monitoring, then run again.\n", stderr)
            return false
        }
        self.manager = manager
        return true
    }

    private static func makeManager(_ filter: DeviceFilter) -> IOHIDManager {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(manager, filter.matching as CFDictionary?)
        return manager
    }
}

private let onAttach: IOHIDDeviceCallback = { _, _, _, device in
    print("+ \(device.label)  \(Names.hex(device.int(kIOHIDVendorIDKey))):\(Names.hex(device.int(kIOHIDProductIDKey)))"
        + "  primary \(Names.hex(device.int(kIOHIDPrimaryUsagePageKey))):\(Names.hex(device.int(kIOHIDPrimaryUsageKey)))")
}

private let onDetach: IOHIDDeviceCallback = { _, _, _, device in
    print("- \(device.label)")
}

private let onValue: IOHIDValueCallback = { _, _, _, value in
    let element = IOHIDValueGetElement(value)
    guard IOHIDElementGetUsage(element) != 0xFFFF_FFFF else { return }  // rollover filler
    let page = Int(IOHIDElementGetUsagePage(element))
    let usage = Int(IOHIDElementGetUsage(element))
    let raw = IOHIDValueGetIntegerValue(value)
    // For array elements (the boot keyboard's key slots) the value is not a plain down/up flag, so show it as is;
    // the RAW line beside it has the real usage bytes.
    let isArray = IOHIDElementIsArray(element)
    let state = !isArray && IOHIDElementGetLogicalMax(element) <= 1 ? (raw != 0 ? "down" : "up") : "value=\(raw)"
    Timeline.log("HID", "\(IOHIDElementGetDevice(element).label)  \(Names.hex(page)):\(Names.hex(usage)) "
        + "\(Names.usage(page: page, usage: usage))  \(state)" + (isArray ? "  [array]" : ""))
}

// Raw bytes are the ground truth: they also show vendor reports the value callback has no names for.
private let onReport: IOHIDReportCallback = { _, _, sender, _, reportID, report, length in
    guard let sender else { return }
    let device = Unmanaged<IOHIDDevice>.fromOpaque(sender).takeUnretainedValue()
    let bytes = UnsafeBufferPointer(start: report, count: length).map { String(format: "%02x", $0) }
    Timeline.log("RAW", "\(device.label)  id=\(reportID)  " + bytes.joined(separator: " "))
}
