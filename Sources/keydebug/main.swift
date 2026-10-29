import ApplicationServices
import Foundation
import IOKit.hid

let usage = """
usage: keydebug list  [--vid 0x0603] [--pid 0x0351] [--all]
       keydebug watch [--vid 0x0603] [--pid 0x0351] [--all]
       keydebug post <keycode> [--fn] [--cmd] [--opt] [--ctrl] [--shift]

  list    show the HID devices (and their usage pairs) macOS sees
  watch   print every key press as raw HID, then as macOS events (default)
  post    post one synthetic key press (down, then up) at the HID event tap

  list, watch:
    --vid/--pid  only this device (all of its interfaces)
    --all        every HID device, not just keyboards

  post:
    <keycode>    macOS virtual key code, decimal or 0x hex
    --fn --cmd --opt --ctrl --shift   modifier flags to set (none by default)
"""

func fail(_ message: String) -> Never {
    fputs(message + "\n", stderr)
    exit(2)
}

/// Value after a flag: decimal or 0x-prefixed hex.
func number(after args: inout [String]) -> Int {
    guard !args.isEmpty else { fail(usage) }
    let text = args.removeFirst()
    guard let value = text.hasPrefix("0x") ? Int(text.dropFirst(2), radix: 16) : Int(text) else {
        fail("not a number: \(text)\n\n\(usage)")
    }
    return value
}

/// The device flags of `list` and `watch`.
func deviceFilter(from args: inout [String]) -> DeviceFilter {
    var filter = DeviceFilter()
    while !args.isEmpty {
        switch args.removeFirst() {
        case "--vid": filter.vendorID = number(after: &args)
        case "--pid": filter.productID = number(after: &args)
        case "--all": filter.all = true
        default: fail(usage)
        }
    }
    return filter
}

setvbuf(stdout, nil, _IOLBF, 0)  // line-buffered so `| tee` shows events as they happen

var args = Array(CommandLine.arguments.dropFirst())
var command = "watch"
if let first = args.first, !first.hasPrefix("-") { command = args.removeFirst() }

switch command {
case "list":
    HIDWatcher.list(deviceFilter(from: &args))
case "post":
    let value = number(after: &args)
    guard let keyCode = CGKeyCode(exactly: value) else { fail("not a key code: \(value)\n\n\(usage)") }
    var flags: CGEventFlags = []
    while !args.isEmpty {
        switch args.removeFirst() {
        case "--fn": flags.insert(.maskSecondaryFn)
        case "--cmd": flags.insert(.maskCommand)
        case "--opt": flags.insert(.maskAlternate)
        case "--ctrl": flags.insert(.maskControl)
        case "--shift": flags.insert(.maskShift)
        default: fail(usage)
        }
    }
    if !AXIsProcessTrusted() {
        fputs("note: Accessibility is not granted to this app, so macOS silently drops the posted keys. "
            + "Allow it under System Settings > Privacy & Security > Accessibility; trying anyway.\n", stderr)
    }
    guard KeyPoster.post(keyCode: keyCode, flags: flags) else {
        fputs("error: could not create the key events.\n", stderr)
        exit(1)
    }
    let name = Names.virtualKey(Int(keyCode))
    print("posted key \(keyCode)" + (name.isEmpty ? "" : " (\(name))") + " flags \(Names.flags(flags))")
case "watch":
    let filter = deviceFilter(from: &args)
    // One Input Monitoring grant covers both the HID manager and the event tap.
    if !IOHIDRequestAccess(kIOHIDRequestTypeListenEvent) {
        fputs("note: Input Monitoring is not granted yet; macOS may be showing a prompt.\n", stderr)
    }
    guard HIDWatcher.watch(filter) else { exit(1) }
    if !EventTapWatcher.start() {
        fputs("warning: could not create the event tap, showing HID only.\n", stderr)
    }
    print("watching, press keys (ctrl-c to stop)\n")
    CFRunLoopRun()
default:
    fail(usage)
}
