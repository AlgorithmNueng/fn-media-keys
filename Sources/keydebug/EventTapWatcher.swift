import AppKit
import CoreGraphics

/// What macOS makes of the key presses, after the HID layer: key codes, flags and media-key events.
enum EventTapWatcher {
    private static let systemDefined: CGEventMask = 1 << 14  // NX_SYSDEFINED has no CGEventType case

    /// Returns false when the tap cannot be created (no Input Monitoring permission).
    static func start() -> Bool {
        let keyEvents: [CGEventType] = [.keyDown, .keyUp, .flagsChanged]
        let mask = keyEvents.reduce(systemDefined) { $0 | (1 << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
            eventsOfInterest: mask, callback: onEvent, userInfo: nil)
        else { return false }
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0), .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }
}

private func onEvent(_: CGEventTapProxy, type: CGEventType, event: CGEvent, _: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    switch type {
    case .keyDown, .keyUp, .flagsChanged:
        // Auto-repeat would flood the log while a key is held.
        guard event.getIntegerValueField(.keyboardEventAutorepeat) == 0 else { break }
        let code = Int(event.getIntegerValueField(.keyboardEventKeycode))
        Timeline.log("EVT", "\(type == .keyDown ? "keyDown" : type == .keyUp ? "keyUp" : "flagsChanged")  "
            + "keyCode=\(code) \(Names.virtualKey(code))  flags=\(Names.flags(event.flags))")
    default:
        // NX_SYSDEFINED: subtype 8 is a media key; data1 = keyType << 16 | state << 8 | repeat.
        guard let system = NSEvent(cgEvent: event), system.type == .systemDefined else { break }
        let subtype = Int(system.subtype.rawValue)
        guard subtype == 8 else {
            Timeline.log("EVT", "systemDefined  subtype=\(subtype) data1=\(Names.hex(system.data1, width: 8))")
            break
        }
        let keyType = (system.data1 & 0xFFFF_0000) >> 16
        let state = (system.data1 & 0xFF00) >> 8 == 0xA ? "down" : "up"
        Timeline.log("EVT", "systemDefined  \(Names.mediaKey(keyType)) (keyType \(keyType))  \(state)"
            + (system.data1 & 1 == 1 ? "  repeat" : ""))
    }
    return Unmanaged.passUnretained(event)
}
