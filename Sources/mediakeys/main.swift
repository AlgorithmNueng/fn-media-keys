import ApplicationServices
import Foundation
import IOKit.hid

setvbuf(stdout, nil, _IOLBF, 0)  // line-buffered so `| tee` shows output as it happens

// Reading the Lucky65 needs Input Monitoring; swallowing keys and posting media events needs Accessibility.
_ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
_ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)

let settings = "Allow this app under System Settings > Privacy & Security > Input Monitoring and Accessibility, then run again."
LuckyKeys.setUp()
guard LuckyKeys.open() else {
    fputs("error: cannot read the Lucky65 (Input Monitoring). \(settings)\n", stderr)
    exit(1)
}
guard Remapper.start() else {
    fputs("error: cannot create the event tap (Accessibility). \(settings)\n", stderr)
    exit(1)
}

print("Lucky65 Fn row (ctrl-c to stop). Hold shift/ctrl/opt/cmd for the plain F-key.")
for key in Layout.keys {
    print("\(key.label) (\(key.name)): \(Layout.action(at: key.index).title)")
}
CFRunLoopRun()
