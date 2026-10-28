import Foundation

/// One line per event with seconds since the first one; a blank line separates key presses (>400 ms apart).
enum Timeline {
    private static var first: TimeInterval?
    private static var last: TimeInterval = 0

    static func log(_ tag: String, _ text: String) {
        let now = ProcessInfo.processInfo.systemUptime
        let start = first ?? now
        if first != nil, now - last > 0.4 { print() }
        first = start
        last = now
        print(String(format: "%7.3f  ", now - start) + tag.padding(toLength: 4, withPad: " ", startingAt: 0) + " " + text)
    }
}
