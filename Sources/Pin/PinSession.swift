import AppKit
import ScreenCaptureKit

@MainActor
final class PinSession {
    var id: CGWindowID { source.windowID }
    let title: String
    var opacity: Double {
        didSet { refreshVisibility() }
    }
    var onEnd: (() -> Void)?

    private let source: SCWindow
    private let panel: NSPanel
    private let view: MirrorView
    private let output: FrameOutput
    private let stream: SCStream
    private let configuration: SCStreamConfiguration
    private var monitor: Task<Void, Never>?
    private var captureSize: CGSize = .zero
    private var interacting = false
    private var stopped = false
    private var capturing = false

    init(window: SCWindow, filter: SCContentFilter, opacity: Double) throws {
        source = window
        title = window.title ?? window.owningApplication?.applicationName ?? "窗口"
        self.opacity = opacity
        view = MirrorView(frame: .zero)
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.contentView = view

        configuration = SCStreamConfiguration()
        let pixels = WindowGeometry.captureSize(filter.contentRect.size,
                                               scale: CGFloat(filter.pointPixelScale))
        configuration.width = Int(pixels.width)
        configuration.height = Int(pixels.height)
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        configuration.queueDepth = 3
        configuration.showsCursor = false
        configuration.capturesAudio = false
        configuration.ignoreShadowsSingleWindow = true

        output = FrameOutput(renderer: view.videoLayer.sampleBufferRenderer)
        stream = SCStream(filter: filter, configuration: configuration, delegate: output)
        try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: .main)
        output.onStop = { [weak self] in
            guard let self, !self.stopped else { return }
            self.onEnd?()
        }
        view.onClick = { [weak self] in self?.beginInteraction() }
        view.onUnpin = { [weak self] in self?.onEnd?() }
        refreshVisibility()
    }

    func start() async throws {
        try await stream.startCapture()
        // Unpin/quit can happen while the asynchronous start is pending.
        guard !stopped, !Task.isCancelled else {
            try? await stream.stopCapture()
            return
        }
        capturing = true
        await synchronize()
        guard !stopped else { return }
        panel.orderFrontRegardless()
        monitor = Task { [weak self] in
            while !Task.isCancelled {
                do { try await Task.sleep(for: .milliseconds(100)) }
                catch { return }
                guard let self else { return }
                await self.synchronize()
            }
        }
    }

    func stop() {
        guard !stopped else { return }
        stopped = true
        monitor?.cancel()
        monitor = nil
        output.onStop = nil
        view.onClick = nil
        view.onUnpin = nil
        panel.orderOut(nil)
        if capturing {
            capturing = false
            // Retain the view/output until ScreenCaptureKit finishes queued callbacks.
            Task { try? await stream.stopCapture() }
        }
    }

    func setStackRank(_ rank: Int) {
        panel.level = NSWindow.Level(rawValue: NSWindow.Level.floating.rawValue + rank)
    }

    private func synchronize() async {
        guard !stopped else { return }
        guard let windows = CGWindowListCopyWindowInfo(.optionIncludingWindow, source.windowID)
                as? [[String: Any]],
              let info = windows.first,
              let bounds = info[kCGWindowBounds as String] as? [String: CGFloat],
              let quartzFrame = CGRect(dictionaryRepresentation: bounds as CFDictionary),
              let primary = NSScreen.screens.first else {
            onEnd?()
            return
        }
        let frame = WindowGeometry.cocoaFrame(quartzFrame, primaryScreenHeight: primary.frame.maxY)
        if panel.frame != frame { panel.setFrame(frame, display: true) }
        if interacting && !frame.contains(NSEvent.mouseLocation) {
            interacting = false
            refreshVisibility()
        }
        let screen = NSScreen.screens.first { $0.frame.contains(CGPoint(x: frame.midX, y: frame.midY)) }
            ?? panel.screen ?? primary
        view.videoLayer.contentsScale = screen.backingScaleFactor
        let pixels = WindowGeometry.captureSize(frame.size, scale: screen.backingScaleFactor)
        guard pixels != captureSize else { return }
        configuration.width = Int(pixels.width)
        configuration.height = Int(pixels.height)
        do {
            try await stream.updateConfiguration(configuration)
            captureSize = pixels
        } catch {
            if !stopped { onEnd?() }
        }
    }

    private func beginInteraction() {
        interacting = true
        refreshVisibility()
        if let pid = source.owningApplication?.processID {
            NSRunningApplication(processIdentifier: pid)?.activate()
        }
    }

    private func refreshVisibility() {
        panel.ignoresMouseEvents = interacting
        panel.hasShadow = !interacting
        view.videoLayer.opacity = interacting ? 0 : Float(opacity)
    }
}
