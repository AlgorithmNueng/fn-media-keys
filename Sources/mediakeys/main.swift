import ApplicationServices
import Foundation
import IOKit.hid

setvbuf(stdout, nil, _IOLBF, 0)  // line-buffered so `| tee` shows events as they happen

// Reading the Lucky65 needs Input Monitoring; swallowing keys and posting media events needs Accessibility.
_ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
_ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)

let settings = "Allow this app under System Settings > Privacy & Security > Input Monitoring and Accessibility, then run again."
guard LuckyKeys.start() else {
    fputs("error: cannot read the Lucky65 (Input Monitoring). \(settings)\n", stderr)
    exit(1)
}
guard Remapper.start() else {
    fputs("error: cannot create the event tap (Accessibility). \(settings)\n", stderr)
    exit(1)
}

print("Lucky65 Fn row -> Magic Keyboard media keys (ctrl-c to stop)")
print("F1/F2 brightness, F7 rewind, F8 play/pause, F9 fast-forward, F10 mute, F11/F12 volume. Hold shift/ctrl/opt/cmd for the plain F-key.")
CFRunLoopRun()
