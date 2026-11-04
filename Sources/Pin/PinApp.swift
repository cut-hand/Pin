import AppKit
import ScreenCaptureKit

#if !arch(arm64)
#error("Pin v0.1.4 and later require Apple silicon.")
#endif

// The Objective-C picker filter has no Sendable conformance. After selection we
// treat it as immutable and use it only on MainActor, never editing its properties.
private struct PickerSelection: @unchecked Sendable {
    let filter: SCContentFilter
}

@main
@MainActor
enum PinApp {
    static func main() {
        if CommandLine.arguments.contains("--version") {
            print(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.4")
            return
        }
        let app = NSApplication.shared
        let controller = AppController()
        app.delegate = controller
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(controller) { app.run() }
    }
}

@MainActor
final class AppController: NSObject, NSApplicationDelegate, NSMenuDelegate, SCContentSharingPickerObserver {
    private var statusItem: NSStatusItem?
    private var session: PinSession?
    private var selection: Task<Void, Never>?
    private var opacity = WindowGeometry.opacity(UserDefaults.standard.object(forKey: "opacity") as? Double ?? 1)

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "pin", accessibilityDescription: "Pin")
        let menu = NSMenu()
        menu.delegate = self
        statusItem?.menu = menu

        let picker = SCContentSharingPicker.shared
        var config = SCContentSharingPickerConfiguration()
        config.allowedPickerModes = .singleWindow
        config.excludedBundleIDs = [Bundle.main.bundleIdentifier ?? "io.github.cut-hand.Pin"]
        config.allowsChangingSelectedContent = false
        picker.defaultConfiguration = config
        picker.maximumStreamCount = 1
        picker.add(self)
        picker.isActive = true
    }

    func applicationWillTerminate(_ notification: Notification) {
        unpin()
        SCContentSharingPicker.shared.isActive = false
        SCContentSharingPicker.shared.remove(self)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        if let session {
            let title = menu.addItem(withTitle: session.title, action: nil, keyEquivalent: "")
            title.isEnabled = false
            add("取消置顶", action: #selector(unpin), to: menu, key: "u")
            menu.addItem(.separator())
            let label = menu.addItem(withTitle: "透明度", action: nil, keyEquivalent: "")
            label.isEnabled = false
            let container = NSView(frame: NSRect(x: 0, y: 0, width: 204, height: 30))
            let slider = NSSlider(value: opacity, minValue: 0.1, maxValue: 1,
                                  target: self, action: #selector(changeOpacity(_:)))
            slider.frame = NSRect(x: 12, y: 4, width: 180, height: 22)
            slider.isContinuous = true
            container.addSubview(slider)
            let item = NSMenuItem()
            item.view = container
            menu.addItem(item)
        } else {
            add("选择窗口置顶…", action: #selector(chooseWindow), to: menu, key: "p")
        }
        menu.addItem(.separator())
        add("检查更新…", action: #selector(openReleases), to: menu)
        let quit = menu.addItem(withTitle: "退出 Pin", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        quit.target = NSApp
    }

    private func add(_ title: String, action: Selector, to menu: NSMenu, key: String = "") {
        let item = menu.addItem(withTitle: title, action: action, keyEquivalent: key)
        item.target = self
    }

    @objc private func chooseWindow() {
        NSApp.activate()
        SCContentSharingPicker.shared.present(using: .window)
    }

    @objc private func unpin() {
        selection?.cancel()
        selection = nil
        session?.stop()
        session = nil
        statusItem?.button?.image = NSImage(systemSymbolName: "pin", accessibilityDescription: "Pin")
    }

    @objc private func changeOpacity(_ slider: NSSlider) {
        opacity = WindowGeometry.opacity(slider.doubleValue)
        UserDefaults.standard.set(opacity, forKey: "opacity")
        session?.opacity = opacity
    }

    @objc private func openReleases() {
        if let url = URL(string: "https://github.com/cut-hand/Pin/releases") { NSWorkspace.shared.open(url) }
    }

    private func pin(_ filter: SCContentFilter) {
        guard let window = filter.includedWindows.first else { return }
        unpin()
        selection = Task { [weak self] in
            guard let self else { return }
            do {
                let current = try PinSession(window: window, filter: filter, opacity: opacity)
                session = current
                current.onEnd = { [weak self, weak current] in
                    guard let self, let current, self.session === current else { return }
                    self.unpin()
                }
                try await current.start()
                guard session === current, !Task.isCancelled else { current.stop(); return }
                statusItem?.button?.image = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: "已置顶")
            } catch {
                guard !Task.isCancelled else { return }
                unpin()
                showError(error)
            }
        }
    }

    private func showError(_ error: any Error) {
        let alert = NSAlert()
        alert.messageText = "无法置顶窗口"
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }

    nonisolated func contentSharingPicker(_ picker: SCContentSharingPicker, didUpdateWith filter: SCContentFilter,
                                         for stream: SCStream?) {
        let selection = PickerSelection(filter: filter)
        Task { @MainActor [weak self] in self?.pin(selection.filter) }
    }

    nonisolated func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {}

    nonisolated func contentSharingPickerStartDidFailWithError(_ error: any Error) {
        Task { @MainActor [weak self] in self?.showError(error) }
    }
}
