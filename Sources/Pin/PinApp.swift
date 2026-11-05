import AppKit
import ScreenCaptureKit

#if !arch(arm64)
#error("Pin v0.1.4 and later require Apple silicon.")
#endif

@main @MainActor
enum PinApp {
    static func main() {
        if CommandLine.arguments.contains("--version") {
            print(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1.7")
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
final class AppController: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private let manager = WindowManagerViewController()
    private var sessions: [PinSession] = []
    private var starts: [CGWindowID: Task<Void, Never>] = [:]
    private var choosing = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem?.button?.target = self
        statusItem?.button?.action = #selector(toggleManager)
        popover.behavior = .transient
        popover.contentViewController = manager
        manager.onAdd = { [weak self] in self?.chooseWindow() }
        manager.onRemove = { [weak self] id in self?.remove(id) }
        manager.onRemoveAll = { [weak self] in self?.removeAll() }
        manager.onMove = { [weak self] id, row in self?.move(id, to: row) }
        refresh()
    }

    func applicationWillTerminate(_ notification: Notification) { removeAll() }

    @objc private func toggleManager() {
        guard let button = statusItem?.button else { return }
        if popover.isShown { popover.performClose(nil) }
        else { refresh(); popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY) }
    }

    private func refresh() {
        for (index, session) in sessions.enumerated() { session.setStackRank(sessions.count - index) }
        manager.update(sessions)
        if let url = Bundle.main.url(forResource: "MenuBarTemplate", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            image.size = NSSize(width: 18, height: 18)
            image.isTemplate = true
            statusItem?.button?.image = image
        } else {
            statusItem?.button?.image = NSImage(systemSymbolName: "pin", accessibilityDescription: "Pin")
        }
        statusItem?.button?.toolTip = "Pin · 已置顶 \(sessions.count) 个窗口"
        statusItem?.button?.setAccessibilityLabel("窗口置顶管理")
    }

    private func remove(_ id: CGWindowID) {
        starts.removeValue(forKey: id)?.cancel()
        sessions.first { $0.id == id }?.stop()
        sessions.removeAll { $0.id == id }
        refresh()
    }

    private func removeAll() {
        starts.values.forEach { $0.cancel() }
        starts.removeAll()
        sessions.forEach { $0.stop() }
        sessions.removeAll()
        refresh()
    }

    private func move(_ id: CGWindowID, to row: Int) {
        let order = WindowOrder.moving(sessions.map(\.id), id: id, to: row)
        let byID = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
        sessions = order.compactMap { byID[$0] }
        refresh()
    }

    private func chooseWindow() {
        guard !choosing else { return }
        choosing = true
        popover.performClose(nil)
        Task {
            defer { choosing = false }
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: true)
                let windows = content.windows.filter { window in
                    window.windowLayer == 0 && window.frame.width > 50 && window.frame.height > 50 &&
                    window.owningApplication?.processID != ProcessInfo.processInfo.processIdentifier &&
                    !sessions.contains(where: { session in session.id == window.windowID })
                }.sorted { ($0.owningApplication?.applicationName ?? "", $0.title ?? "") <
                           ($1.owningApplication?.applicationName ?? "", $1.title ?? "") }
                NSApp.activate()
                let alert = NSAlert()
                alert.messageText = "选择需要置顶的窗口"
                guard !windows.isEmpty else {
                    alert.informativeText = "没有可添加的窗口。已置顶窗口可在菜单栏中管理。"
                    alert.runModal()
                    return
                }
                alert.informativeText = "可多次添加窗口，每个窗口独立控制透明度和层级。"
                let choices = NSPopUpButton(frame: NSRect(x: 0, y: 0, width: 420, height: 28))
                choices.addItems(withTitles: windows.map {
                    "\($0.owningApplication?.applicationName ?? "应用") — \($0.title ?? "未命名窗口")"
                })
                alert.accessoryView = choices
                alert.addButton(withTitle: "置顶此窗口")
                alert.addButton(withTitle: "取消")
                if alert.runModal() == .alertFirstButtonReturn, windows.indices.contains(choices.indexOfSelectedItem) {
                    pin(windows[choices.indexOfSelectedItem])
                }
            } catch {
                let alert = NSAlert()
                alert.messageText = "需要屏幕录制权限"
                alert.informativeText = "请在“系统设置 → 隐私与安全性 → 屏幕录制”中允许 Pin，然后重新打开应用。\n\n\(error.localizedDescription)"
                alert.addButton(withTitle: "打开系统设置")
                alert.addButton(withTitle: "取消")
                if alert.runModal() == .alertFirstButtonReturn,
                   let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }

    private func pin(_ window: SCWindow) {
        guard !sessions.contains(where: { $0.id == window.windowID }) else { return }
        do {
            let current = try PinSession(window: window, filter: SCContentFilter(desktopIndependentWindow: window), opacity: 1)
            sessions.insert(current, at: 0)
            current.onEnd = { [weak self, weak current] in
                guard let self, let current, sessions.contains(where: { $0 === current }) else { return }
                remove(current.id)
            }
            refresh()
            starts[current.id] = Task { [weak self] in
                guard let self else { return }
                defer {
                    if sessions.contains(where: { $0 === current }) { starts[current.id] = nil }
                }
                do {
                    try await current.start()
                    guard sessions.contains(where: { $0 === current }), !Task.isCancelled else { current.stop(); return }
                    refresh()
                } catch {
                    guard sessions.contains(where: { $0 === current }), !Task.isCancelled else { return }
                    remove(current.id)
                    let alert = NSAlert()
                    alert.messageText = "无法置顶窗口"
                    alert.informativeText = error.localizedDescription
                    alert.runModal()
                }
            }
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }
}
