import AppKit

@MainActor
private final class IconButton: NSButton {
    var invoke: (() -> Void)?
    init(_ symbol: String, help: String, action: @escaping () -> Void) {
        super.init(frame: .zero)
        image = NSImage(systemSymbolName: symbol, accessibilityDescription: help)
        imagePosition = .imageOnly
        imageScaling = .scaleProportionallyDown
        isBordered = false
        contentTintColor = .secondaryLabelColor
        toolTip = help
        setAccessibilityLabel(help)
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
        controlSize = .small
        toolTip = "调整此窗口的不透明度"
        setAccessibilityLabel("窗口不透明度")
        self.changed = changed
        target = self
        action = #selector(run)
    }
    required init?(coder: NSCoder) { nil }
    @objc private func run() { changed?(doubleValue) }
}

@MainActor
private final class WindowTableView: NSTableView {
    var idForRow: ((Int) -> CGWindowID?)?
    var onRemove: ((CGWindowID) -> Void)?
    override func menu(for event: NSEvent) -> NSMenu? {
        let row = row(at: convert(event.locationInWindow, from: nil))
        guard row >= 0, let id = idForRow?(row) else { return nil }
        let menu = NSMenu()
        let item = menu.addItem(withTitle: "取消置顶", action: #selector(removeRow(_:)), keyEquivalent: "")
        item.image = NSImage(systemSymbolName: "xmark", accessibilityDescription: nil)
        item.representedObject = id
        item.target = self
        return menu
    }
    override func rightMouseDown(with event: NSEvent) {
        guard let menu = menu(for: event) else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }
    @objc private func removeRow(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? CGWindowID else { return }
        onRemove?(id)
    }
}

@MainActor
final class WindowManagerViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate {
    var onAdd: (() -> Void)?
    var onRemove: ((CGWindowID) -> Void)?
    var onRemoveAll: (() -> Void)?
    var onMove: ((CGWindowID, Int) -> Void)?
    private var sessions: [PinSession] = []
    private let table = WindowTableView()
    private let scroll = NSScrollView()
    private let heading = NSTextField(labelWithString: "置顶窗口")
    private let emptyLabel = NSTextField(labelWithString: "点 + 添加窗口")
    private let dragType = NSPasteboard.PasteboardType("io.github.cut-hand.Pin.window")

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 360, height: 236))
        let add = IconButton("plus", help: "添加置顶窗口") { [weak self] in self?.onAdd?() }
        add.frame = NSRect(x: 250, y: 198, width: 28, height: 28)
        add.autoresizingMask = [.minYMargin]
        view.addSubview(add)
        heading.font = .systemFont(ofSize: 13, weight: .semibold)
        heading.frame = NSRect(x: 14, y: 201, width: 222, height: 22)
        heading.autoresizingMask = [.minYMargin]
        view.addSubview(heading)
        let clear = IconButton("pin.slash", help: "取消全部窗口的置顶") { [weak self] in self?.onRemoveAll?() }
        clear.frame = NSRect(x: 284, y: 198, width: 28, height: 28)
        clear.autoresizingMask = [.minYMargin]
        view.addSubview(clear)

        table.addTableColumn(NSTableColumn(identifier: NSUserInterfaceItemIdentifier("window")))
        table.headerView = nil
        table.rowHeight = 64
        table.intercellSpacing = NSSize(width: 0, height: 4)
        table.backgroundColor = .clear
        table.selectionHighlightStyle = .none
        table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        table.delegate = self
        table.dataSource = self
        table.registerForDraggedTypes([dragType])
        table.setDraggingSourceOperationMask(.move, forLocal: true)
        table.setAccessibilityLabel("置顶窗口列表，上下拖动调整层级")
        table.idForRow = { [weak self] row in
            guard let self, sessions.indices.contains(row) else { return nil }
            return sessions[row].id
        }
        table.onRemove = { [weak self] id in self?.onRemove?(id) }
        scroll.documentView = table
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.scrollerStyle = .overlay
        scroll.drawsBackground = false
        scroll.frame = NSRect(x: 10, y: 10, width: 340, height: 174)
        scroll.autoresizingMask = [.width, .height]
        view.addSubview(scroll)
        emptyLabel.alignment = .center
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.frame = NSRect(x: 50, y: 107, width: 260, height: 22)
        emptyLabel.autoresizingMask = [.minYMargin, .maxYMargin]
        view.addSubview(emptyLabel)

        let quit = IconButton("power", help: "退出 Pin") { NSApp.terminate(nil) }
        quit.frame = NSRect(x: 318, y: 198, width: 28, height: 28)
        quit.autoresizingMask = [.minYMargin]
        view.addSubview(quit)
    }

    func update(_ sessions: [PinSession]) {
        loadViewIfNeeded()
        self.sessions = sessions
        heading.stringValue = "置顶窗口 · \(sessions.count)"
        emptyLabel.isHidden = !sessions.isEmpty
        preferredContentSize = NSSize(width: 360, height: 62 + min(340, max(68, sessions.count * 68)))
        table.reloadData()
    }

    func numberOfRows(in tableView: NSTableView) -> Int { sessions.count }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let session = sessions[row]
        let width = tableColumn?.width ?? 340
        let cell = NSTableCellView(frame: NSRect(x: 0, y: 0, width: width, height: 64))
        let grip = NSImageView(frame: NSRect(x: 4, y: 35, width: 16, height: 18))
        grip.image = NSImage(systemSymbolName: "line.3.horizontal", accessibilityDescription: "拖动调整层级")
        grip.contentTintColor = .tertiaryLabelColor
        grip.toolTip = "上下拖动此行调整层级，上方优先"
        cell.addSubview(grip)
        let title = NSTextField(labelWithString: session.title)
        title.font = .systemFont(ofSize: 12, weight: .medium)
        title.lineBreakMode = .byTruncatingTail
        title.frame = NSRect(x: 28, y: 33, width: max(100, width - 66), height: 22)
        title.toolTip = session.title
        cell.addSubview(title)
        let remove = IconButton("xmark", help: "取消此窗口的置顶") { [weak self] in self?.onRemove?(session.id) }
        remove.frame = NSRect(x: width - 30, y: 31, width: 26, height: 26)
        cell.addSubview(remove)
        let opacityIcon = NSImageView(frame: NSRect(x: 28, y: 10, width: 14, height: 16))
        opacityIcon.image = NSImage(systemSymbolName: "circle.lefthalf.filled", accessibilityDescription: "不透明度")
        opacityIcon.contentTintColor = .secondaryLabelColor
        opacityIcon.toolTip = "窗口不透明度"
        cell.addSubview(opacityIcon)
        let label = NSTextField(labelWithString: "\(Int(session.opacity * 100))%")
        label.font = .monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        label.textColor = .secondaryLabelColor
        label.alignment = .right
        label.frame = NSRect(x: width - 46, y: 8, width: 40, height: 18)
        label.toolTip = "当前窗口的不透明度"
        cell.addSubview(label)
        let slider = OpacitySlider(value: session.opacity) { [weak session, weak label] value in
            session?.opacity = WindowGeometry.opacity(value)
            label?.stringValue = "\(Int(value * 100))%"
        }
        slider.frame = NSRect(x: 50, y: 7, width: max(100, width - 106), height: 22)
        cell.addSubview(slider)
        let separator = NSBox(frame: NSRect(x: 28, y: 0, width: width - 34, height: 1))
        separator.boxType = .separator
        cell.addSubview(separator)
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
