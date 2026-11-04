import CoreGraphics

enum WindowGeometry {
    static func cocoaFrame(_ quartzFrame: CGRect, primaryScreenHeight: CGFloat) -> CGRect {
        CGRect(x: quartzFrame.minX, y: primaryScreenHeight - quartzFrame.maxY,
               width: quartzFrame.width, height: quartzFrame.height)
    }

    static func captureSize(_ size: CGSize, scale: CGFloat) -> CGSize {
        CGSize(width: max(1, ceil(size.width * scale)),
               height: max(1, ceil(size.height * scale)))
    }

    static func opacity(_ value: Double) -> Double { min(1, max(0.1, value)) }
}
