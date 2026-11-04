import CoreGraphics
import Testing
@testable import Pin

@Test func windowCoordinatesAcrossDisplays() {
    let source = CGRect(x: 120, y: 100, width: 800, height: 600)
    #expect(WindowGeometry.cocoaFrame(source, primaryScreenHeight: 1080)
            == CGRect(x: 120, y: 380, width: 800, height: 600))
    // A display above the primary has negative Quartz Y and positive Cocoa Y.
    let above = CGRect(x: -800, y: -900, width: 600, height: 400)
    #expect(WindowGeometry.cocoaFrame(above, primaryScreenHeight: 1080)
            == CGRect(x: -800, y: 1580, width: 600, height: 400))
    let below = CGRect(x: 0, y: 1200, width: 600, height: 400)
    #expect(WindowGeometry.cocoaFrame(below, primaryScreenHeight: 1080).minY == -520)
}

@Test func captureDimensionsFollowDisplayScale() {
    let size = CGSize(width: 500.25, height: 300.25)
    #expect(WindowGeometry.captureSize(size, scale: 1) == CGSize(width: 501, height: 301))
    #expect(WindowGeometry.captureSize(size, scale: 2) == CGSize(width: 1001, height: 601))
    #expect(WindowGeometry.captureSize(.zero, scale: 2) == CGSize(width: 1, height: 1))
}

@Test(arguments: [(-1.0, 0.1), (0.05, 0.1), (0.5, 0.5), (2.0, 1.0)])
func opacityStaysUsable(input: Double, expected: Double) {
    #expect(WindowGeometry.opacity(input) == expected)
}
