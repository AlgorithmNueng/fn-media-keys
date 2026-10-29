import AppKit
import ApplicationServices
import IOKit.hid
import SwiftUI

/// A menu bar app: no windows, the whole settings UI is the popover (see `MenuView`).
@main
struct Lucky65KeysApp: App {
    init() {
        Status.shared.start()
    }

    var body: some Scene {
        MenuBarExtra {
            MenuView()
        } label: {
            Image(systemName: "keyboard")
        }
        .menuBarExtraStyle(.window)
    }
}

/// What the menu shows, and the owner of the remapping: it starts the event tap once both permissions are granted and
/// stops it when one is taken away. The app never exits because a permission is missing.
final class Status: ObservableObject {
    static let shared = Status()

    /// False when run straight from `.build` (no bundle identity): no login item, and no way to relaunch.
    static let isBundled = Bundle.main.bundleIdentifier != nil

    @Published private(set) var accessibility = false
    @Published private(set) var inputMonitoring = false
    @Published private(set) var connected = false
    @Published private(set) var running = false

    func start() {
        LuckyKeys.setUp()
        // Only prompts while the user has not decided yet; later requests come from the menu's buttons.
        _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        // macOS sends no notification when a permission is granted or the keyboard is plugged in, so poll. Common modes:
        // the default mode alone stops ticking while a Picker menu is open.
        RunLoop.main.add(Timer(timeInterval: 1, repeats: true) { _ in self.refresh() }, forMode: .common)
        refresh()
    }

    func refresh() {
        let accessibility = AXIsProcessTrusted()
        let inputMonitoring = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent) == kIOHIDAccessTypeGranted
        var running = self.running
        if accessibility && inputMonitoring {
            if !running { running = LuckyKeys.open() && Remapper.start() }
        } else if running {
            Remapper.stop()
            running = false
        }
        // Published values are only assigned when they change, so the view is not redrawn every second for nothing.
        update(\.accessibility, accessibility)
        update(\.inputMonitoring, inputMonitoring)
        update(\.connected, LuckyKeys.connected)
        update(\.running, running)
    }

    /// Starts a second copy and quits this one: macOS sometimes applies Input Monitoring only to a fresh process.
    func relaunch() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, error in
            // Stay alive if the new copy did not start, so the menu bar item does not just vanish.
            guard error == nil else { return }
            DispatchQueue.main.async { NSApp.terminate(nil) }
        }
    }

    private func update<Value: Equatable>(_ keyPath: ReferenceWritableKeyPath<Status, Value>, _ value: Value) {
        if self[keyPath: keyPath] != value { self[keyPath: keyPath] = value }
    }
}
