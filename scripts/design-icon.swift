#!/usr/bin/env swift
import AppKit

// AppKit and editable SVG exports share the same centered geometric mark.
let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let brand = root.appendingPathComponent("Resources/Brand", isDirectory: true)
let icons = root.appendingPathComponent("Resources/AppIcon.iconset", isDirectory: true)
try FileManager.default.createDirectory(at: brand, withIntermediateDirectories: true)
let pinSVG = "M 352 746 Q 352 774 380 774 L 644 774 Q 672 774 672 746 L 672 700 Q 672 680 648 680 L 608 680 L 608 535 Q 608 517 625 504 L 691 453 Q 714 435 697 412 Q 690 402 671 402 L 535 402 L 522 228 Q 521 214 512 214 Q 503 214 502 228 L 489 402 L 353 402 Q 334 402 327 412 Q 310 435 333 453 L 399 504 Q 416 517 416 535 L 416 680 L 376 680 Q 352 680 352 700 Z"
let svgDefs = "<defs><linearGradient id='bg' x1='0' y1='0' x2='1' y2='1'><stop stop-color='#367CF2'/><stop offset='1' stop-color='#3848CD'/></linearGradient></defs>"
let mark = "<g transform='translate(0 1024) scale(1 -1)'><rect x='224' y='242' width='508' height='474' rx='88' fill='white' opacity='.13' transform='rotate(-14 478 479)'/><rect x='292' y='290' width='508' height='474' rx='88' fill='white' opacity='.16' transform='rotate(10 546 527)'/><path d='\(pinSVG)' fill='white'/></g>"
let layerContents = [
    "BackLayer.svg": "<rect x='224' y='242' width='508' height='474' rx='88' fill='white' opacity='.13' transform='rotate(-14 478 479)'/>",
    "MiddleLayer.svg": "<rect x='292' y='290' width='508' height='474' rx='88' fill='white' opacity='.16' transform='rotate(10 546 527)'/>",
    "Pin.svg": "<path d='\(pinSVG)' fill='white'/>"
]
for (name, content) in layerContents {
    try "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 1024 1024'><g transform='translate(0 1024) scale(1 -1)'>\(content)</g></svg>".write(to:brand.appendingPathComponent(name),atomically:true,encoding:.utf8)
}
try "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 1024 1024'>\(svgDefs)<rect width='1024' height='1024' fill='url(#bg)'/></svg>".write(to:brand.appendingPathComponent("Background.svg"),atomically:true,encoding:.utf8)
let foreground = "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 1024 1024'>\(mark)</svg>"
try foreground.write(to: brand.appendingPathComponent("Foreground.svg"), atomically: true, encoding: .utf8)
try "<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 1024 1024'>\(svgDefs)<rect width='1024' height='1024' fill='url(#bg)'/>\(mark)</svg>".write(to: brand.appendingPathComponent("AppIcon.svg"), atomically: true, encoding: .utf8)

func pin() -> NSBezierPath {
    let p = NSBezierPath()
    p.move(to: NSPoint(x:352,y:746))
    // Rounded, filled silhouette; no borrowed system symbol or fine text.
    p.curve(to:NSPoint(x:380,y:774),controlPoint1:NSPoint(x:352,y:766),controlPoint2:NSPoint(x:360,y:774))
    p.line(to:NSPoint(x:644,y:774));p.curve(to:NSPoint(x:672,y:746),controlPoint1:NSPoint(x:664,y:774),controlPoint2:NSPoint(x:672,y:766))
    p.line(to:NSPoint(x:672,y:700));p.curve(to:NSPoint(x:648,y:680),controlPoint1:NSPoint(x:672,y:685),controlPoint2:NSPoint(x:663,y:680))
    p.line(to:NSPoint(x:608,y:680));p.line(to:NSPoint(x:608,y:535))
    p.curve(to:NSPoint(x:625,y:504),controlPoint1:NSPoint(x:608,y:519),controlPoint2:NSPoint(x:615,y:512))
    p.line(to:NSPoint(x:691,y:453));p.curve(to:NSPoint(x:671,y:402),controlPoint1:NSPoint(x:727,y:425),controlPoint2:NSPoint(x:705,y:402))
    p.line(to:NSPoint(x:535,y:402));p.line(to:NSPoint(x:522,y:228))
    p.curve(to:NSPoint(x:502,y:228),controlPoint1:NSPoint(x:521,y:209),controlPoint2:NSPoint(x:503,y:209))
    p.line(to:NSPoint(x:489,y:402));p.line(to:NSPoint(x:353,y:402))
    p.curve(to:NSPoint(x:333,y:453),controlPoint1:NSPoint(x:319,y:402),controlPoint2:NSPoint(x:297,y:425))
    p.line(to:NSPoint(x:399,y:504));p.curve(to:NSPoint(x:416,y:535),controlPoint1:NSPoint(x:409,y:512),controlPoint2:NSPoint(x:416,y:519))
    p.line(to:NSPoint(x:416,y:680));p.line(to:NSPoint(x:376,y:680))
    p.curve(to:NSPoint(x:352,y:700),controlPoint1:NSPoint(x:361,y:680),controlPoint2:NSPoint(x:352,y:685))
    p.close();return p
}

func writePNG(_ size: Int, to url: URL, legacy: Bool = false, monochrome: Bool = false) throws {
    let rep = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:size,pixelsHigh:size,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
    let ctx = NSGraphicsContext(bitmapImageRep: rep)!
    NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current = ctx
    ctx.cgContext.scaleBy(x:CGFloat(size)/1024,y:CGFloat(size)/1024)
    if monochrome {
        ctx.cgContext.translateBy(x:512,y:512)
        ctx.cgContext.scaleBy(x:1.5,y:1.5)
        ctx.cgContext.translateBy(x:-512,y:-494)
        NSColor.black.setFill();pin().fill()
    } else {
        if legacy {
            // Legacy ICNS fallback keeps the macOS 15 icon footprint; vector layers remain unmasked.
            ctx.cgContext.translateBy(x:72,y:72)
            ctx.cgContext.scaleBy(x:0.86,y:0.86)
            NSBezierPath(roundedRect:NSRect(x:0,y:0,width:1024,height:1024),xRadius:224,yRadius:224).addClip()
        }
        NSGradient(starting:NSColor(srgbRed:0.212,green:0.486,blue:0.949,alpha:1),ending:NSColor(srgbRed:0.220,green:0.282,blue:0.804,alpha:1))!.draw(in:NSRect(x:0,y:0,width:1024,height:1024),angle:-60)
        for (x,y,a,r) in [(224.0,242.0,0.13,-14.0),(292.0,290.0,0.16,10.0)] {
            NSGraphicsContext.saveGraphicsState()
            ctx.cgContext.translateBy(x:x+254,y:y+237)
            ctx.cgContext.rotate(by:r * .pi / 180)
            NSColor.white.withAlphaComponent(a).setFill()
            NSBezierPath(roundedRect:NSRect(x:-254,y:-237,width:508,height:474),xRadius:88,yRadius:88).fill()
            NSGraphicsContext.restoreGraphicsState()
        }
        NSColor.white.setFill();pin().fill()
    }
    NSGraphicsContext.restoreGraphicsState()
    try rep.representation(using:.png,properties:[:])!.write(to:url)
}
try writePNG(1024,to:brand.appendingPathComponent("AppIcon-1024.png"))
try writePNG(512,to:brand.appendingPathComponent("AppIcon-preview.png"),legacy:true)
try writePNG(36,to:brand.appendingPathComponent("MenuBarTemplate.png"),monochrome:true)
for size in [16,32,128,256,512] {
    try writePNG(size,to:icons.appendingPathComponent("icon_\(size)x\(size).png"),legacy:true)
    try writePNG(size*2,to:icons.appendingPathComponent("icon_\(size)x\(size)@2x.png"),legacy:true)
}
print("Generated layered SVG artwork, a 1024px unmasked PNG, ICNS fallback sizes, and menu-bar template")
