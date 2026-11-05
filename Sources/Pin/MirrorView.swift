import AppKit
import AVFoundation
import ScreenCaptureKit

@MainActor
final class MirrorView: NSView {
    let videoLayer = AVSampleBufferDisplayLayer()
    var onClick: (() -> Void)?
    var onUnpin: (() -> Void)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        videoLayer.videoGravity = .resize
        layer?.addSublayer(videoLayer)
    }

    required init?(coder: NSCoder) { nil }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        videoLayer.frame = bounds
        CATransaction.commit()
    }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control) { rightMouseDown(with: event) }
        else { onClick?() }
    }

    override func rightMouseDown(with event: NSEvent) {
        guard let menu = menu(for: event) else { return }
        NSMenu.popUpContextMenu(menu, with: event, for: self)
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func menu(for event: NSEvent) -> NSMenu? {
        let menu = NSMenu()
        let item = menu.addItem(withTitle: "取消置顶", action: #selector(unpin), keyEquivalent: "")
        item.target = self
        return menu
    }

    @objc private func unpin() { onUnpin?() }
}

// Screen buffers are delivered synchronously on DispatchQueue.main (see PinSession).
// They never cross an actor boundary or accumulate in unstructured Tasks.
@MainActor
final class FrameOutput: NSObject, @preconcurrency SCStreamOutput, SCStreamDelegate {
    let renderer: AVSampleBufferVideoRenderer
    var onStop: (() -> Void)?

    init(renderer: AVSampleBufferVideoRenderer) { self.renderer = renderer }

    func stream(_ stream: SCStream, didOutputSampleBuffer buffer: CMSampleBuffer,
                of type: SCStreamOutputType) {
        guard type == .screen, buffer.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(buffer, createIfNecessary: false)
                as? [[SCStreamFrameInfo: Any]],
              attachments.first?[.status] as? Int == SCFrameStatus.complete.rawValue else { return }
        if renderer.status == .failed { renderer.flush() }
        if renderer.isReadyForMoreMediaData { renderer.enqueue(buffer) }
    }

    nonisolated func stream(_ stream: SCStream, didStopWithError error: any Error) {
        Task { @MainActor [weak self] in self?.onStop?() }
    }
}
