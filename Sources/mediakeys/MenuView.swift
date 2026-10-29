import AppKit
import ApplicationServices
import IOKit.hid
import ServiceManagement
import SwiftUI

/// The popover of the menu bar item. It only writes UserDefaults; the event tap reads the settings on every key press.
struct MenuView: View {
    @ObservedObject private var status = Status.shared
    @AppStorage(Layout.enabledKey) private var enabled = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Lucky65 Keys").font(.headline)

            StatusRow(
                title: "Lucky65", ok: status.connected,
                text: status.connected ? "เชื่อมต่อแล้ว" : "ไม่พบ Lucky65 (ต่อสาย USB)")
            StatusRow(
                title: "Accessibility", ok: status.accessibility,
                text: status.accessibility ? "อนุญาตแล้ว" : "ยังไม่ได้อนุญาต",
                request: requestAccessibility)
            StatusRow(
                title: "Input Monitoring", ok: status.inputMonitoring,
                text: status.inputMonitoring ? "อนุญาตแล้ว" : "ยังไม่ได้อนุญาต",
                request: requestInputMonitoring)
            if status.accessibility && status.inputMonitoring && !status.running {
                relaunchHint
            }

            Toggle("เปิดใช้งาน", isOn: $enabled)

            Divider()
            ForEach(Layout.keys, id: \.index) { KeyRow(key: $0) }
            Button("คืนค่าเริ่มต้น") {
                // AppStorage shows the defaults again once the keys are gone.
                Layout.keys.forEach { UserDefaults.standard.removeObject(forKey: $0.name) }
            }

            Divider()
            if Status.isBundled { LoginItemToggle() }
            Button("ออกจากโปรแกรม") { NSApp.terminate(nil) }
        }
        .padding(12)
        .frame(width: 340)
    }

    private var relaunchHint: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("ได้รับสิทธิ์ครบแล้วแต่ยังไม่ทำงาน บางครั้ง macOS ต้องเปิดแอปใหม่ก่อน")
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if Status.isBundled {
                Button("เปิดแอปใหม่") { status.relaunch() }
            } else {
                Text("ปิดโปรแกรมแล้วรันใหม่").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    // The prompting APIs are called only from the buttons: the Accessibility one shows a dialog every time.
    private func requestAccessibility() {
        _ = AXIsProcessTrustedWithOptions([kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary)
        openSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    private func requestInputMonitoring() {
        _ = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
        openSettings("x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
    }

    private func openSettings(_ url: String) {
        if let url = URL(string: url) { NSWorkspace.shared.open(url) }
    }
}

/// A coloured dot, what it stands for, and the button that asks for the permission while it is missing.
private struct StatusRow: View {
    let title: String
    let ok: Bool
    let text: String
    var request: (() -> Void)?

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(ok ? Color.green : Color.orange).frame(width: 8, height: 8)
            Text(title)
            Text(text).foregroundStyle(.secondary)
            Spacer()
            if let request, !ok {
                Button("ขอสิทธิ์…", action: request).controlSize(.small)
            }
        }
    }
}

/// One Fn key: what is printed on it, the F-key it sends, and the action it is set to.
private struct KeyRow: View {
    let key: FnKey
    @AppStorage private var action: Action

    init(key: FnKey) {
        self.key = key
        _action = AppStorage(wrappedValue: key.defaultAction, key.name)
    }

    var body: some View {
        HStack {
            Text(key.label).frame(width: 44, alignment: .leading)
            Text(key.name).foregroundStyle(.secondary)
            Spacer()
            Picker(key.label, selection: $action) {
                ForEach(Action.allCases, id: \.self) { Text($0.title) }
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .frame(width: 190)
        }
    }
}

/// Start at login through the system's login items. The system owns the state (the user can also change it in System
/// Settings), so it is read back from `SMAppService` instead of being stored.
private struct LoginItemToggle: View {
    @State private var enabled = false
    @State private var failure: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("เปิดเมื่อเข้าสู่ระบบ", isOn: Binding(get: { enabled }, set: setLoginItem))
            if let failure { Text(failure).font(.caption).foregroundStyle(.red) }
        }
        .onAppear(perform: reload)
        // The popover's content may stay alive between openings, so onAppear alone could miss a change made in System Settings.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in reload() }
    }

    private func reload() {
        enabled = SMAppService.mainApp.status == .enabled
    }

    private func setLoginItem(_ on: Bool) {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            failure = nil
        } catch {
            failure = "ตั้งค่าไม่สำเร็จ: \(error.localizedDescription)"
        }
        reload()
    }
}
