import Foundation
import IOKit.hid

let usage = """
usage: keydebug [list|watch] [--vid 0x0603] [--pid 0x0351] [--all]

  list    show the HID devices (and their usage pairs) macOS sees
  watch   print every key press as raw HID, then as macOS events (default)

  --vid/--pid  only this device (all of its interfaces)
  --all        every HID device, not just keyboards
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

setvbuf(stdout, nil, _IOLBF, 0)  // line-buffered so `| tee` shows events as they happen

var args = Array(CommandLine.arguments.dropFirst())
var command = "watch"
if let first = args.first, !first.hasPrefix("-") { command = args.removeFirst() }
var filter = DeviceFilter()
while !args.isEmpty {
    switch args.removeFirst() {
    case "--vid": filter.vendorID = number(after: &args)
    case "--pid": filter.productID = number(after: &args)
    case "--all": filter.all = true
    default: fail(usage)
    }
}

switch command {
case "list":
    HIDWatcher.list(filter)
case "watch":
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
