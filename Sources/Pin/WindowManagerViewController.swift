import AppKit

@MainActor
private final class ActionButton: NSButton {
    var invoke: (() -> Void)?
    init(_ title: String, action: @escaping () -> Void) {
        super.init(frame: .zero)
        self.title = title
        bezelStyle = .rounded
        invoke = action
        target = self
        self.action = #selector(run)
    }
    required init?(coder: NSCoder) { nil }
    @objc private func run() { invoke?() }
}

@MainActor
private final class OpacitySlider: NSSlider {
    var changed: ((Double) -> Void)?
    init(value: Double, changed: @escaping (Double) -> Void) {
        super.init(frame: .zero)
        minValue = 0.1
        maxValue = 1
        doubleValue = value
        isContinuous = true
        self.changed = changed
        target = self
        action = #selector(run)
    }
    required init?(coder: NSCoder) { nil }
    @objc private func run() { changed?(doubleValue) }
}

@MainActor
final class WindowManagerViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    var onAdd: (() -> Void)?
    var onRemove: ((CGWindowID) -> Void)?
    var onRemoveAll: (() -> Void)?
    var onMove: ((CGWindowID, Int) -> Void)?
    private var sessions: [PinSession] = []
    private let table = NSTableView()
    private let scroll = NSScrollView()
    private let dragType = NSPasteboard.PasteboardType("io.github.cut-hand.Pin.window")

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 440, height: 240))
        let heading = NSTextField(labelWithString: "窗口置顶 · 拖动排序，上方层级更高")
        heading.font = .systemFont(ofSize: 13, weight: .semibold)
        heading.frame = NSRect(x: 16, y: 200, width: 408, height: 22)
        heading.autoresizingMask = [.minYMargin]
        view.addSubview(heading)
        table.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("window")))
        table.headerView = nil
        table.rowHeight = 82
        table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        table.delegate = self
        table.dataSource = self
        table.registerForDraggedTypes([dragType])
        table.setDraggingSourceOperationMask(.move, forLocal: true)
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.frame = NSRect(x: 8, y: 84, width: 424, height: 110)
        scroll.autoresizingMask = [.width, .height]
        view.addSubview(scroll)
        let add = ActionButton("添加窗口…") { [weak self] in self?.onAdd?() }
        add.frame = NSRect(x: 12, y: 46, width: 130, height: 30)
        view.addSubview(add)
        let clear = ActionButton("全部取消置顶") { [weak self] in self?.onRemoveAll?() }
        clear.frame = NSRect(x: 150, y: 46, width: 150, height: 30)
        view.addSubview(clear)
        let updates = ActionButton("检查更新…") {
            if let url = URL(string: "https://github.com/cut-hand/Pin/releases") { NSWorkspace.shared.open(url) }
        }
        updates.frame = NSRect(x: 12, y: 10, width: 130, height: 30)
        view.addSubview(updates)
        let quit = ActionButton("退出 Pin") { NSApp.terminate(nil) }
        quit.frame = NSRect(x: 310, y: 10, width: 115, height: 30)
        view.addSubview(quit)
    }

    func update(_ sessions: [PinSession]) {
        loadViewIfNeeded()
        self.sessions = sessions
        preferredContentSize = NSSize(width: 440, height: 130 + min(410, max(82, sessions.count * 84)))
        table.reloadData()
    }

    func numberOfRows(in tableView: NSTableView) -> Int { sessions.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let session = sessions[row]
        let width = tableColumn?.width ?? 400
        let cell = NSTableCellView(frame: NSRect(x: 0, y: 0, width: width, height: 82))
        let title = NSTextField(labelWithString: "≡  \(session.title)")
        title.lineBreakMode = .byTruncatingTail
        title.frame = NSRect(x: 8, y: 49, width: max(100, width - 128), height: 22)
        title.toolTip = session.title
        cell.addSubview(title)
        let remove = ActionButton("取消置顶") { [weak self] in self?.onRemove?(session.id) }
        remove.frame = NSRect(x: width - 112, y: 45, width: 104, height: 30)
        cell.addSubview(remove)
        let label = NSTextField(labelWithString: "不透明度 \(Int(session.opacity * 100))%")
        label.font = .systemFont(ofSize: 11)
        label.frame = NSRect(x: 8, y: 14, width: 106, height: 18)
        cell.addSubview(label)
        let slider = OpacitySlider(value: session.opacity) { [weak session, weak label] value in
            session?.opacity = WindowGeometry.opacity(value)
            label?.stringValue = "不透明度 \(Int(value * 100))%"
        }
        slider.frame = NSRect(x: 118, y: 10, width: max(120, width - 134), height: 24)
        cell.addSubview(slider)
        return cell
    }

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> (any NSPasteboardWriting)? {
        let item = NSPasteboardItem()
        item.setString(String(sessions[row].id), forType: dragType)
        return item
    }

    func tableView(_ tableView: NSTableView, validateDrop info: any NSDraggingInfo,
                   proposedRow row: Int, proposedDropOperation operation: NSTableView.DropOperation) -> NSDragOperation {
        guard info.draggingSource as? NSTableView === table,
              info.draggingPasteboard.string(forType: dragType) != nil else { return [] }
        tableView.setDropRow(row, dropOperation: .above)
        return .move
    }

    func tableView(_ tableView: NSTableView, acceptDrop info: any NSDraggingInfo,
                   row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        guard info.draggingSource as? NSTableView === table,
              let text = info.draggingPasteboard.string(forType: dragType), let id = UInt32(text),
              sessions.contains(where: { $0.id == id }), (0...sessions.count).contains(row) else { return false }
        onMove?(id, row)
        return true
    }
}
