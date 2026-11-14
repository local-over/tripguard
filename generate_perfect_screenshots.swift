import AppKit
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let canvasWidth: CGFloat = 1286
let canvasHeight: CGFloat = 804

func createRetinaCanvas() -> (NSImage, CGContext) {
    let image = NSImage(size: NSSize(width: canvasWidth, height: canvasHeight))
    image.lockFocusFlipped(true)
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        fatalError("Failed to acquire CGContext")
    }
    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high
    
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.fill(CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))
    
    return (image, ctx)
}

func savePNG(image: NSImage, path: String) {
    image.unlockFocus()
    guard let tiffData = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiffData),
          let pngData = rep.representation(using: .png, properties: [:]) else {
        fatalError("Failed to convert image to PNG for path: \(path)")
    }
    let url = URL(fileURLWithPath: path)
    try! pngData.write(to: url)
    print("Saved \(path) (\(pngData.count) bytes)")
}

// MARK: - 1. Generate 1024x1024 App Icon & AppIcon.icns

func generateAppIcon() {
    let size: CGFloat = 1024
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocusFlipped(false)
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        fatalError("Failed to get icon context")
    }
    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)
    
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let iconRect = CGRect(x: 100, y: 100, width: 824, height: 824)
    let cornerRadius: CGFloat = 185
    let squirclePath = CGPath(roundedRect: iconRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
    
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -24), blur: 48, color: NSColor(red: 0.00, green: 0.18, blue: 0.45, alpha: 0.38).cgColor)
    ctx.setFillColor(NSColor(red: 0.04, green: 0.22, blue: 0.58, alpha: 1.0).cgColor)
    ctx.addPath(squirclePath)
    ctx.fillPath()
    ctx.restoreGState()
    
    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.clip()
    
    let bgColors = [
        NSColor(red: 0.00, green: 0.85, blue: 0.58, alpha: 1.0).cgColor,
        NSColor(red: 0.00, green: 0.58, blue: 0.98, alpha: 1.0).cgColor,
        NSColor(red: 0.04, green: 0.18, blue: 0.52, alpha: 1.0).cgColor
    ] as CFArray
    let bgGrad = CGGradient(colorsSpace: colorSpace, colors: bgColors, locations: [0.0, 0.48, 1.0])!
    ctx.drawLinearGradient(
        bgGrad,
        start: CGPoint(x: iconRect.minX, y: iconRect.maxY),
        end: CGPoint(x: iconRect.maxX, y: iconRect.minY),
        options: []
    )
    
    ctx.setStrokeColor(NSColor(white: 1.0, alpha: 0.10).cgColor)
    ctx.setLineWidth(3.0)
    for r: CGFloat in [220, 310, 400] {
        ctx.strokeEllipse(in: CGRect(x: 512 - r, y: 512 - r, width: r * 2, height: r * 2))
    }
    
    let sPath = CGMutablePath()
    let cx: CGFloat = 496
    let topY: CGFloat = 760
    let botY: CGFloat = 250
    let leftX: CGFloat = 290
    let rightX: CGFloat = 702
    let shoulderY: CGFloat = 655
    let waistY: CGFloat = 420
    
    sPath.move(to: CGPoint(x: cx, y: topY))
    sPath.addCurve(to: CGPoint(x: rightX, y: shoulderY),
                   control1: CGPoint(x: cx + 115, y: topY - 12),
                   control2: CGPoint(x: rightX - 15, y: shoulderY + 35))
    sPath.addCurve(to: CGPoint(x: cx, y: botY),
                   control1: CGPoint(x: rightX, y: waistY),
                   control2: CGPoint(x: cx + 105, y: botY + 55))
    sPath.addCurve(to: CGPoint(x: leftX, y: shoulderY),
                   control1: CGPoint(x: cx - 105, y: botY + 55),
                   control2: CGPoint(x: leftX, y: waistY))
    sPath.addCurve(to: CGPoint(x: cx, y: topY),
                   control1: CGPoint(x: leftX + 15, y: shoulderY + 35),
                   control2: CGPoint(x: cx - 115, y: topY - 12))
    sPath.closeSubpath()
    
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -18), blur: 36, color: NSColor(red: 0.00, green: 0.08, blue: 0.28, alpha: 0.45).cgColor)
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.addPath(sPath)
    ctx.fillPath()
    ctx.restoreGState()
    
    let checkPath = CGMutablePath()
    checkPath.move(to: CGPoint(x: cx - 82, y: 500))
    checkPath.addLine(to: CGPoint(x: cx - 18, y: 432))
    checkPath.addLine(to: CGPoint(x: cx + 98, y: 562))
    ctx.setStrokeColor(NSColor(red: 0.00, green: 0.52, blue: 0.92, alpha: 1.0).cgColor)
    ctx.setLineWidth(44)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.addPath(checkPath)
    ctx.strokePath()
    
    let waveCenter = CGPoint(x: 650, y: 645)
    ctx.setStrokeColor(NSColor(red: 0.35, green: 0.98, blue: 0.78, alpha: 0.95).cgColor)
    ctx.setLineCap(.round)
    for (idx, radius) in [CGFloat(82), CGFloat(130)].enumerated() {
        let arc = CGMutablePath()
        arc.addArc(center: waveCenter, radius: radius, startAngle: .pi * 0.08, endAngle: .pi * 0.42, clockwise: false)
        ctx.setLineWidth(idx == 0 ? 24 : 20)
        ctx.addPath(arc)
        ctx.strokePath()
    }
    
    ctx.setStrokeColor(NSColor(white: 1.0, alpha: 0.28).cgColor)
    ctx.setLineWidth(6)
    ctx.addPath(squirclePath)
    ctx.strokePath()
    ctx.restoreGState()
    
    savePNG(image: image, path: "assets/icon.png")
    try? FileManager.default.removeItem(atPath: "docs/assets/icon.png")
    try! FileManager.default.copyItem(atPath: "assets/icon.png", toPath: "docs/assets/icon.png")
    
    let iconsetDir = "AppIcon.iconset"
    try? FileManager.default.removeItem(atPath: iconsetDir)
    try! FileManager.default.createDirectory(atPath: iconsetDir, withIntermediateDirectories: true)
    
    let sizes: [(Int, String)] = [
        (16, "icon_16x16.png"),
        (32, "icon_16x16@2x.png"),
        (32, "icon_32x32.png"),
        (64, "icon_32x32@2x.png"),
        (128, "icon_128x128.png"),
        (256, "icon_128x128@2x.png"),
        (256, "icon_256x256.png"),
        (512, "icon_256x256@2x.png"),
        (512, "icon_512x512.png"),
        (1024, "icon_512x512@2x.png")
    ]
    
    guard let masterIcon = NSImage(contentsOfFile: "assets/icon.png") else { return }
    for (dim, name) in sizes {
        let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: dim,
            pixelsHigh: dim,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        )!
        rep.size = NSSize(width: dim, height: dim)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        NSGraphicsContext.current?.imageInterpolation = .high
        masterIcon.draw(in: NSRect(x: 0, y: 0, width: dim, height: dim), from: .zero, operation: .copy, fraction: 1.0)
        NSGraphicsContext.restoreGraphicsState()
        if let data = rep.representation(using: .png, properties: [:]) {
            try! data.write(to: URL(fileURLWithPath: "\(iconsetDir)/\(name)"))
        }
    }
    
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
    task.arguments = ["-c", "icns", iconsetDir, "-o", "AppIcon.icns"]
    try? task.run()
    task.waitUntilExit()
    try? FileManager.default.removeItem(atPath: iconsetDir)
}

// MARK: - Shared Drawing Helpers

func drawShieldMenuBarIcon(ctx: CGContext, center: CGPoint, scale: CGFloat = 1.0, isDark: Bool = false, colored: Bool = false, speedText: String? = nil) {
    ctx.saveGState()
    ctx.translateBy(x: center.x, y: center.y)
    ctx.scaleBy(x: scale, y: scale)
    
    let tint: NSColor
    if colored {
        tint = NSColor(red: 0.00, green: 0.76, blue: 0.56, alpha: 1.0)
    } else {
        tint = isDark ? NSColor.white : NSColor(red: 0.10, green: 0.11, blue: 0.13, alpha: 1.0)
    }
    ctx.setFillColor(tint.cgColor)
    ctx.setStrokeColor(tint.cgColor)
    
    let shield = CGMutablePath()
    shield.move(to: CGPoint(x: -1, y: -7.0))
    shield.addCurve(to: CGPoint(x: 5.2, y: -4.2), control1: CGPoint(x: 2.2, y: -6.8), control2: CGPoint(x: 4.8, y: -5.2))
    shield.addCurve(to: CGPoint(x: -1, y: 7.0), control1: CGPoint(x: 5.2, y: 1.5), control2: CGPoint(x: 2.0, y: 5.5))
    shield.addCurve(to: CGPoint(x: -7.2, y: -4.2), control1: CGPoint(x: -4.0, y: 5.5), control2: CGPoint(x: -7.2, y: 1.5))
    shield.addCurve(to: CGPoint(x: -1, y: -7.0), control1: CGPoint(x: -6.8, y: -5.2), control2: CGPoint(x: -4.2, y: -6.8))
    shield.closeSubpath()
    ctx.addPath(shield)
    ctx.fillPath()
    
    let checkColor = isDark ? NSColor(red: 0.08, green: 0.09, blue: 0.12, alpha: 1.0) : NSColor.white
    ctx.setStrokeColor(checkColor.cgColor)
    ctx.setLineWidth(1.5)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.move(to: CGPoint(x: -3.4, y: -0.2))
    ctx.addLine(to: CGPoint(x: -1.4, y: 1.8))
    ctx.addLine(to: CGPoint(x: 2.2, y: -2.0))
    ctx.strokePath()
    
    ctx.setStrokeColor(tint.cgColor)
    ctx.setLineWidth(1.2)
    for r: CGFloat in [2.6, 4.6] {
        let arc = CGMutablePath()
        arc.addArc(center: CGPoint(x: 4.0, y: -4.0), radius: r, startAngle: -.pi * 0.42, endAngle: -.pi * 0.08, clockwise: false)
        ctx.addPath(arc)
        ctx.strokePath()
    }
    ctx.restoreGState()
    
    if let text = speedText {
        let textTint = isDark ? NSColor.white : NSColor(red: 0.10, green: 0.11, blue: 0.13, alpha: 1.0)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12 * scale, weight: .semibold),
            .foregroundColor: textTint
        ]
        (text as NSString).draw(at: CGPoint(x: center.x + 11 * scale, y: center.y - 7.5 * scale), withAttributes: attrs)
    }
}

func drawSystemIcons(ctx: CGContext, startX: CGFloat, y: CGFloat, isDark: Bool = false) {
    let tint = isDark ? NSColor.white : NSColor(red: 0.12, green: 0.13, blue: 0.15, alpha: 1.0)
    ctx.setStrokeColor(tint.cgColor)
    ctx.setFillColor(tint.cgColor)
    ctx.setLineWidth(1.6)
    ctx.setLineCap(.round)
    
    var cx = startX
    let cy = y
    for r: CGFloat in [4, 8, 12] {
        let arc = CGMutablePath()
        arc.addArc(center: CGPoint(x: cx, y: cy + 4), radius: r, startAngle: -.pi * 0.75, endAngle: -.pi * 0.25, clockwise: false)
        ctx.addPath(arc)
        ctx.strokePath()
    }
    ctx.fillEllipse(in: CGRect(x: cx - 1.5, y: cy + 2.5, width: 3, height: 3))
    
    cx += 28
    let sRadius: CGFloat = 4.5
    ctx.strokeEllipse(in: CGRect(x: cx - sRadius, y: cy - sRadius - 1, width: sRadius * 2, height: sRadius * 2))
    ctx.move(to: CGPoint(x: cx + 3.2, y: cy + 2.2))
    ctx.addLine(to: CGPoint(x: cx + 7.5, y: cy + 6.5))
    ctx.strokePath()
    
    cx += 28
    let p1 = CGPath(roundedRect: CGRect(x: cx - 7, y: cy - 5, width: 14, height: 5), cornerWidth: 2.5, cornerHeight: 2.5, transform: nil)
    ctx.addPath(p1)
    ctx.strokePath()
    ctx.fillEllipse(in: CGRect(x: cx - 5, y: cy - 4.5, width: 4, height: 4))
    
    let p2 = CGPath(roundedRect: CGRect(x: cx - 7, y: cy + 1, width: 14, height: 5), cornerWidth: 2.5, cornerHeight: 2.5, transform: nil)
    ctx.addPath(p2)
    ctx.strokePath()
    ctx.fillEllipse(in: CGRect(x: cx + 1, y: cy + 1.5, width: 4, height: 4))
    
    cx += 24
    ("Sat Nov 14  9:41 AM" as NSString).draw(at: CGPoint(x: cx, y: cy - 8), withAttributes: [
        .font: NSFont.systemFont(ofSize: 13, weight: .medium),
        .foregroundColor: tint
    ])
}

func drawLightWallpaper(ctx: CGContext, rect: CGRect) {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let colors = [
        NSColor(red: 0.05, green: 0.48, blue: 0.88, alpha: 1.0).cgColor,
        NSColor(red: 0.00, green: 0.72, blue: 0.85, alpha: 1.0).cgColor,
        NSColor(red: 0.22, green: 0.88, blue: 0.76, alpha: 1.0).cgColor
    ] as CFArray
    let grad = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 0.55, 1.0])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: rect.minX, y: rect.minY), end: CGPoint(x: rect.maxX, y: rect.maxY), options: [])
    
    ctx.saveGState()
    let wave = CGMutablePath()
    wave.move(to: CGPoint(x: rect.minX, y: rect.minY + 130))
    wave.addCurve(to: CGPoint(x: rect.maxX, y: rect.minY + 340),
                  control1: CGPoint(x: rect.minX + rect.width * 0.35, y: rect.minY + 50),
                  control2: CGPoint(x: rect.minX + rect.width * 0.70, y: rect.minY + 460))
    wave.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
    wave.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
    wave.closeSubpath()
    ctx.addPath(wave)
    ctx.clip()
    
    let wColors = [
        NSColor(red: 0.00, green: 0.32, blue: 0.78, alpha: 0.88).cgColor,
        NSColor(red: 0.00, green: 0.68, blue: 0.92, alpha: 0.72).cgColor
    ] as CFArray
    let wGrad = CGGradient(colorsSpace: colorSpace, colors: wColors, locations: [0.0, 1.0])!
    ctx.drawLinearGradient(wGrad, start: CGPoint(x: rect.minX, y: rect.minY + 110), end: CGPoint(x: rect.maxX, y: rect.maxY), options: [])
    ctx.restoreGState()
}

func drawDarkWallpaper(ctx: CGContext, rect: CGRect) {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let colors = [
        NSColor(red: 0.03, green: 0.06, blue: 0.14, alpha: 1.0).cgColor,
        NSColor(red: 0.04, green: 0.14, blue: 0.28, alpha: 1.0).cgColor,
        NSColor(red: 0.02, green: 0.28, blue: 0.38, alpha: 1.0).cgColor
    ] as CFArray
    let grad = CGGradient(colorsSpace: colorSpace, colors: colors, locations: [0.0, 0.5, 1.0])!
    ctx.drawLinearGradient(grad, start: CGPoint(x: rect.minX, y: rect.minY), end: CGPoint(x: rect.maxX, y: rect.maxY), options: [])
}

func drawBezelAndScreen(ctx: CGContext, screenRect: CGRect, isDark: Bool = false) {
    ctx.saveGState()
    let outerRect = screenRect.insetBy(dx: -18, dy: -18).offsetBy(dx: 0, dy: -4)
    let outerPath = CGPath(roundedRect: outerRect, cornerWidth: 32, cornerHeight: 32, transform: nil)
    
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 16), blur: 36, color: NSColor(white: 0, alpha: 0.18).cgColor)
    ctx.setFillColor(NSColor(red: 0.12, green: 0.13, blue: 0.15, alpha: 1.0).cgColor)
    ctx.addPath(outerPath)
    ctx.fillPath()
    ctx.restoreGState()
    
    let bezelPath = CGPath(roundedRect: screenRect.insetBy(dx: -3, dy: -3), cornerWidth: 20, cornerHeight: 20, transform: nil)
    ctx.setFillColor(NSColor(red: 0.08, green: 0.08, blue: 0.09, alpha: 1.0).cgColor)
    ctx.addPath(bezelPath)
    ctx.fillPath()
    
    let screenClip = CGPath(roundedRect: screenRect, cornerWidth: 16, cornerHeight: 16, transform: nil)
    ctx.addPath(screenClip)
    ctx.clip()
    
    if isDark {
        drawDarkWallpaper(ctx: ctx, rect: screenRect)
    } else {
        drawLightWallpaper(ctx: ctx, rect: screenRect)
    }
    
    let menuBarRect = CGRect(x: screenRect.origin.x, y: screenRect.origin.y, width: screenRect.width, height: 36)
    ctx.setFillColor((isDark ? NSColor(red: 0.06, green: 0.08, blue: 0.12, alpha: 0.78) : NSColor(white: 1.0, alpha: 0.32)).cgColor)
    ctx.fill(menuBarRect)
    ctx.restoreGState()
}

// MARK: - Simple Menu Bar Popover Renderer

func drawSimpleMenuPopover(ctx: CGContext, rect: CGRect) {
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 14), blur: 32, color: NSColor(white: 0, alpha: 0.24).cgColor)
    let popPath = CGPath(roundedRect: rect, cornerWidth: 14, cornerHeight: 14, transform: nil)
    ctx.setFillColor(NSColor(red: 0.98, green: 0.98, blue: 0.99, alpha: 0.96).cgColor)
    ctx.addPath(popPath)
    ctx.fillPath()
    ctx.setShadow(offset: .zero, blur: 0, color: nil)
    
    let textColor = NSColor(red: 0.10, green: 0.11, blue: 0.13, alpha: 1.0)
    let secondaryColor = NSColor(white: 0.45, alpha: 1.0)
    let emeraldColor = NSColor(red: 0.00, green: 0.76, blue: 0.54, alpha: 1.0)
    let cyanColor = NSColor(red: 0.00, green: 0.52, blue: 0.95, alpha: 1.0)
    
    var curY = rect.origin.y + 14
    let leftX = rect.origin.x + 15
    let rightX = rect.maxX - 15
    
    // Header
    ("TripGuard" as NSString).draw(at: CGPoint(x: leftX, y: curY), withAttributes: [
        .font: NSFont.systemFont(ofSize: 15, weight: .bold),
        .foregroundColor: textColor
    ])
    ctx.setFillColor(emeraldColor.cgColor)
    ctx.fillEllipse(in: CGRect(x: leftX, y: curY + 21, width: 6, height: 6))
    ("Shield Active • Wi-Fi (en0)" as NSString).draw(at: CGPoint(x: leftX + 10, y: curY + 17), withAttributes: [
        .font: NSFont.systemFont(ofSize: 10.5, weight: .medium),
        .foregroundColor: emeraldColor
    ])
    
    let swRect = CGRect(x: rightX - 36, y: curY + 4, width: 36, height: 20)
    ctx.setFillColor(cyanColor.cgColor)
    ctx.addPath(CGPath(roundedRect: swRect, cornerWidth: 10, cornerHeight: 10, transform: nil))
    ctx.fillPath()
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.fillEllipse(in: CGRect(x: swRect.maxX - 18, y: swRect.minY + 2, width: 16, height: 16))
    
    curY += 38
    ctx.setStrokeColor(NSColor(white: 0, alpha: 0.08).cgColor)
    ctx.setLineWidth(0.5)
    ctx.move(to: CGPoint(x: leftX - 4, y: curY))
    ctx.addLine(to: CGPoint(x: rightX + 4, y: curY))
    ctx.strokePath()
    curY += 10
    
    // Session Usage Big Readout
    ("SESSION USAGE" as NSString).draw(at: CGPoint(x: leftX, y: curY), withAttributes: [
        .font: NSFont.systemFont(ofSize: 9.5, weight: .bold),
        .foregroundColor: secondaryColor
    ])
    ("142.4 MB" as NSString).draw(at: CGPoint(x: leftX, y: curY + 13), withAttributes: [
        .font: NSFont.monospacedDigitSystemFont(ofSize: 21, weight: .bold),
        .foregroundColor: textColor
    ])
    ("↓ 420 KB/s" as NSString).draw(at: CGPoint(x: rightX - 64, y: curY + 4), withAttributes: [
        .font: NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .semibold),
        .foregroundColor: cyanColor
    ])
    ("↑ 38 KB/s" as NSString).draw(at: CGPoint(x: rightX - 58, y: curY + 19), withAttributes: [
        .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular),
        .foregroundColor: secondaryColor
    ])
    curY += 44
    
    ctx.move(to: CGPoint(x: leftX - 4, y: curY))
    ctx.addLine(to: CGPoint(x: rightX + 4, y: curY))
    ctx.strokePath()
    curY += 8
    
    // Simple App Rows
    let apps: [(String, String, Bool, NSColor)] = [
        ("Google Chrome", "84.2 MB", true, NSColor(red: 0.15, green: 0.55, blue: 0.98, alpha: 1.0)),
        ("Slack", "26.8 MB", true, NSColor(red: 0.55, green: 0.22, blue: 0.78, alpha: 1.0)),
        ("WhatsApp", "19.4 MB", true, NSColor(red: 0.12, green: 0.78, blue: 0.42, alpha: 1.0)),
        ("Dropbox", "8.1 MB", false, NSColor(red: 0.00, green: 0.42, blue: 0.92, alpha: 1.0)),
        ("Photos", "3.9 MB", false, NSColor(red: 0.95, green: 0.45, blue: 0.20, alpha: 1.0)),
        ("Steam", "0 B", false, NSColor(red: 0.22, green: 0.28, blue: 0.38, alpha: 1.0))
    ]
    
    for app in apps {
        let iconRect = CGRect(x: leftX, y: curY + 2, width: 20, height: 20)
        ctx.setFillColor(app.3.withAlphaComponent(app.2 ? 1.0 : 0.45).cgColor)
        ctx.addPath(CGPath(roundedRect: iconRect, cornerWidth: 5, cornerHeight: 5, transform: nil))
        ctx.fillPath()
        (String(app.0.prefix(1)) as NSString).draw(at: CGPoint(x: iconRect.minX + 6, y: iconRect.minY + 3), withAttributes: [
            .font: NSFont.systemFont(ofSize: 10.5, weight: .bold),
            .foregroundColor: NSColor.white
        ])
        (app.0 as NSString).draw(at: CGPoint(x: leftX + 26, y: curY + 4), withAttributes: [
            .font: NSFont.systemFont(ofSize: 11.5, weight: .medium),
            .foregroundColor: app.2 ? textColor : secondaryColor
        ])
        (app.1 as NSString).draw(at: CGPoint(x: rightX - 75, y: curY + 5), withAttributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .medium),
            .foregroundColor: app.2 ? secondaryColor : NSColor.red.withAlphaComponent(0.8)
        ])
        
        let tRect = CGRect(x: rightX - 28, y: curY + 4, width: 28, height: 15)
        ctx.setFillColor((app.2 ? emeraldColor : NSColor(white: 0, alpha: 0.15)).cgColor)
        ctx.addPath(CGPath(roundedRect: tRect, cornerWidth: 7.5, cornerHeight: 7.5, transform: nil))
        ctx.fillPath()
        ctx.setFillColor(NSColor.white.cgColor)
        let kx = app.2 ? tRect.maxX - 13.5 : tRect.minX + 1.5
        ctx.fillEllipse(in: CGRect(x: kx, y: tRect.minY + 1.5, width: 12, height: 12))
        curY += 26
    }
    
    curY += 6
    // Prominent "Open TripGuard & History..." CTA Button
    let btnRect = CGRect(x: leftX, y: curY, width: rightX - leftX, height: 30)
    ctx.setFillColor(cyanColor.cgColor)
    ctx.addPath(CGPath(roundedRect: btnRect, cornerWidth: 7, cornerHeight: 7, transform: nil))
    ctx.fillPath()
    ("Open TripGuard & History..." as NSString).draw(at: CGPoint(x: leftX + 14, y: curY + 7), withAttributes: [
        .font: NSFont.systemFont(ofSize: 11.5, weight: .semibold),
        .foregroundColor: NSColor.white
    ])
    ("↗" as NSString).draw(at: CGPoint(x: rightX - 20, y: curY + 7), withAttributes: [
        .font: NSFont.systemFont(ofSize: 11.5, weight: .bold),
        .foregroundColor: NSColor.white
    ])
    
    curY += 36
    ("Reset Session" as NSString).draw(at: CGPoint(x: leftX, y: curY), withAttributes: [
        .font: NSFont.systemFont(ofSize: 10.5),
        .foregroundColor: secondaryColor
    ])
    ("Settings  •  Quit" as NSString).draw(at: CGPoint(x: rightX - 80, y: curY), withAttributes: [
        .font: NSFont.systemFont(ofSize: 10.5),
        .foregroundColor: secondaryColor
    ])
    ctx.restoreGState()
}

// MARK: - Full Native App Window Renderer (Overview & Applications Tabs)

func drawFullAppWindow(ctx: CGContext, rect: CGRect, showApplicationsTab: Bool = false) {
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 20), blur: 44, color: NSColor(white: 0, alpha: 0.35).cgColor)
    let winPath = CGPath(roundedRect: rect, cornerWidth: 14, cornerHeight: 14, transform: nil)
    ctx.setFillColor(NSColor(red: 0.10, green: 0.12, blue: 0.16, alpha: 1.0).cgColor)
    ctx.addPath(winPath)
    ctx.fillPath()
    ctx.setShadow(offset: .zero, blur: 0, color: nil)
    
    ctx.addPath(winPath)
    ctx.clip()
    
    let cyanColor = NSColor(red: 0.00, green: 0.56, blue: 0.96, alpha: 1.0)
    let emeraldColor = NSColor(red: 0.00, green: 0.78, blue: 0.55, alpha: 1.0)
    let textColor = NSColor.white
    let secColor = NSColor(white: 0.62, alpha: 1.0)
    
    // Sidebar (left 150px)
    let sideW: CGFloat = 155
    ctx.setFillColor(NSColor(red: 0.08, green: 0.09, blue: 0.13, alpha: 1.0).cgColor)
    ctx.fill(CGRect(x: rect.minX, y: rect.minY, width: sideW, height: rect.height))
    
    // Traffic light window dots
    let dotColors = [NSColor.systemRed, NSColor.systemYellow, NSColor.systemGreen]
    for (i, col) in dotColors.enumerated() {
        ctx.setFillColor(col.cgColor)
        ctx.fillEllipse(in: CGRect(x: rect.minX + 14 + CGFloat(i) * 16, y: rect.minY + 14, width: 10, height: 10))
    }
    
    ("TripGuard" as NSString).draw(at: CGPoint(x: rect.minX + 16, y: rect.minY + 38), withAttributes: [
        .font: NSFont.systemFont(ofSize: 13.5, weight: .bold),
        .foregroundColor: textColor
    ])
    ("● Shield Active" as NSString).draw(at: CGPoint(x: rect.minX + 16, y: rect.minY + 56), withAttributes: [
        .font: NSFont.systemFont(ofSize: 10, weight: .semibold),
        .foregroundColor: emeraldColor
    ])
    
    let navItems = ["Overview & History", "Applications", "Limits & Profiles", "Settings"]
    for (i, item) in navItems.enumerated() {
        let isSel = (!showApplicationsTab && i == 0) || (showApplicationsTab && i == 1)
        let ny = rect.minY + 90 + CGFloat(i) * 30
        if isSel {
            let nr = CGRect(x: rect.minX + 10, y: ny - 4, width: sideW - 20, height: 24)
            ctx.setFillColor(cyanColor.cgColor)
            ctx.addPath(CGPath(roundedRect: nr, cornerWidth: 6, cornerHeight: 6, transform: nil))
            ctx.fillPath()
        }
        (item as NSString).draw(at: CGPoint(x: rect.minX + 18, y: ny), withAttributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: isSel ? .bold : .medium),
            .foregroundColor: isSel ? NSColor.white : secColor
        ])
    }
    
    // Main Content Area
    let mainX = rect.minX + sideW + 18
    let mainRight = rect.maxX - 18
    var my = rect.minY + 16
    
    // Top Toolbar with Time Filters
    ((showApplicationsTab ? "Applications" : "Overview & History") as NSString).draw(at: CGPoint(x: mainX, y: my), withAttributes: [
        .font: NSFont.systemFont(ofSize: 15, weight: .bold),
        .foregroundColor: textColor
    ])
    
    let ranges = ["Session", "Today", "7 Days", "30 Days", "Monthly"]
    var rx = mainRight - 265
    for (idx, r) in ranges.enumerated() {
        let sel = (idx == 3) // 30 Days highlighted
        let rr = CGRect(x: rx, y: my - 2, width: 50, height: 20)
        ctx.setFillColor((sel ? cyanColor : NSColor(white: 1.0, alpha: 0.07)).cgColor)
        ctx.addPath(CGPath(roundedRect: rr, cornerWidth: 5, cornerHeight: 5, transform: nil))
        ctx.fillPath()
        (r as NSString).draw(at: CGPoint(x: rx + 6, y: my + 1), withAttributes: [
            .font: NSFont.systemFont(ofSize: 9.5, weight: sel ? .bold : .medium),
            .foregroundColor: sel ? NSColor.white : secColor
        ])
        rx += 53
    }
    
    my += 34
    
    if !showApplicationsTab {
        // 4 Summary Cards
        let cards = [
            ("30 Days Total", "18.42 GB", cyanColor),
            ("Downloaded", "15.80 GB", emeraldColor),
            ("Uploaded", "2.62 GB", NSColor.systemPurple),
            ("Blocked", "1,420", NSColor.systemRed)
        ]
        let cw = (mainRight - mainX - 30) / 4
        for (i, c) in cards.enumerated() {
            let cx = mainX + CGFloat(i) * (cw + 10)
            let cr = CGRect(x: cx, y: my, width: cw, height: 58)
            ctx.setFillColor(NSColor(white: 1.0, alpha: 0.05).cgColor)
            ctx.addPath(CGPath(roundedRect: cr, cornerWidth: 9, cornerHeight: 9, transform: nil))
            ctx.fillPath()
            (c.0 as NSString).draw(at: CGPoint(x: cx + 10, y: my + 8), withAttributes: [
                .font: NSFont.systemFont(ofSize: 9.5, weight: .semibold),
                .foregroundColor: secColor
            ])
            (c.1 as NSString).draw(at: CGPoint(x: cx + 10, y: my + 26), withAttributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 15, weight: .bold),
                .foregroundColor: c.2
            ])
        }
        my += 72
        
        // Bar Chart Box
        let chartRect = CGRect(x: mainX, y: my, width: mainRight - mainX, height: 145)
        ctx.setFillColor(NSColor(white: 1.0, alpha: 0.04).cgColor)
        ctx.addPath(CGPath(roundedRect: chartRect, cornerWidth: 10, cornerHeight: 10, transform: nil))
        ctx.fillPath()
        
        ("Data Usage Timeline (Last 30 Days — Daily Breakdown)" as NSString).draw(at: CGPoint(x: mainX + 12, y: my + 10), withAttributes: [
            .font: NSFont.systemFont(ofSize: 11, weight: .bold),
            .foregroundColor: textColor
        ])
        
        let heights: [CGFloat] = [0.35, 0.52, 0.44, 0.78, 0.62, 0.30, 0.48, 0.85, 0.70, 0.55, 0.40, 0.92, 0.66, 0.50, 0.74, 0.88, 0.60, 0.45, 0.82, 0.95]
        let barCount = heights.count
        let availW = chartRect.width - 28
        let bw = (availW - CGFloat(barCount - 1) * 6) / CGFloat(barCount)
        for (i, h) in heights.enumerated() {
            let bx = mainX + 14 + CGFloat(i) * (bw + 6)
            let maxH: CGFloat = 92
            let bh = maxH * h
            let by = chartRect.maxY - 16 - bh
            ctx.setFillColor(cyanColor.cgColor)
            ctx.addPath(CGPath(roundedRect: CGRect(x: bx, y: by, width: bw, height: bh), cornerWidth: 3, cornerHeight: 3, transform: nil))
            ctx.fillPath()
        }
        my += 158
        
        // Top Consumers list
        ("Top Applications (Last 30 Days)" as NSString).draw(at: CGPoint(x: mainX, y: my), withAttributes: [
            .font: NSFont.systemFont(ofSize: 11.5, weight: .bold),
            .foregroundColor: textColor
        ])
        my += 20
        let topApps: [(String, String, CGFloat, Bool)] = [
            ("Google Chrome", "9.84 GB", 0.88, true),
            ("Slack", "3.42 GB", 0.48, true),
            ("WhatsApp", "2.18 GB", 0.34, true),
            ("Dropbox (Blocked)", "1.12 GB", 0.20, false)
        ]
        for app in topApps {
            (app.0 as NSString).draw(at: CGPoint(x: mainX, y: my), withAttributes: [
                .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: textColor
            ])
            (app.1 as NSString).draw(at: CGPoint(x: mainRight - 65, y: my), withAttributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .bold),
                .foregroundColor: textColor
            ])
            let barW = (mainRight - mainX - 190) * app.2
            let br = CGRect(x: mainX + 115, y: my + 4, width: barW, height: 7)
            ctx.setFillColor((app.3 ? cyanColor : NSColor.systemRed).cgColor)
            ctx.addPath(CGPath(roundedRect: br, cornerWidth: 3.5, cornerHeight: 3.5, transform: nil))
            ctx.fillPath()
            my += 22
        }
    } else {
        // Filter pills row
        let filters = ["All Apps", "Allowed", "Blocked", "Active Now"]
        var fx = mainX
        for (i, f) in filters.enumerated() {
            let sel = (i == 0)
            let fr = CGRect(x: fx, y: my, width: 68, height: 22)
            ctx.setFillColor((sel ? cyanColor : NSColor(white: 1.0, alpha: 0.06)).cgColor)
            ctx.addPath(CGPath(roundedRect: fr, cornerWidth: 5, cornerHeight: 5, transform: nil))
            ctx.fillPath()
            (f as NSString).draw(at: CGPoint(x: fx + 10, y: my + 4), withAttributes: [
                .font: NSFont.systemFont(ofSize: 10, weight: sel ? .bold : .medium),
                .foregroundColor: sel ? NSColor.white : secColor
            ])
            fx += 74
        }
        my += 32
        
        // Table rows
        let rows: [(String, String, String, String, Bool)] = [
            ("Google Chrome", "↓ 420 KB/s", "8.40 GB", "9.84 GB", true),
            ("Slack", "↓ 38 KB/s", "2.90 GB", "3.42 GB", true),
            ("WhatsApp", "Idle", "1.80 GB", "2.18 GB", true),
            ("Dropbox", "Blocked (18)", "0.95 GB", "1.12 GB", false),
            ("Photos (iCloud)", "Blocked (11)", "0.40 GB", "0.92 GB", false),
            ("Steam Client", "Blocked (9)", "0.52 GB", "0.54 GB", false),
            ("Spotify", "Allowed", "0.38 GB", "0.40 GB", true)
        ]
        for r in rows {
            let rr = CGRect(x: mainX, y: my, width: mainRight - mainX, height: 32)
            ctx.setFillColor(NSColor(white: 1.0, alpha: 0.04).cgColor)
            ctx.addPath(CGPath(roundedRect: rr, cornerWidth: 7, cornerHeight: 7, transform: nil))
            ctx.fillPath()
            
            (r.0 as NSString).draw(at: CGPoint(x: mainX + 12, y: my + 8), withAttributes: [
                .font: NSFont.systemFont(ofSize: 11.5, weight: .semibold),
                .foregroundColor: r.4 ? textColor : secColor
            ])
            (r.1 as NSString).draw(at: CGPoint(x: mainX + 165, y: my + 9), withAttributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium),
                .foregroundColor: r.4 ? cyanColor : NSColor.systemRed
            ])
            (r.2 as NSString).draw(at: CGPoint(x: mainX + 275, y: my + 9), withAttributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 10.5, weight: .regular),
                .foregroundColor: secColor
            ])
            (r.3 as NSString).draw(at: CGPoint(x: mainRight - 105, y: my + 8), withAttributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .bold),
                .foregroundColor: textColor
            ])
            
            let tRect = CGRect(x: mainRight - 38, y: my + 8, width: 28, height: 15)
            ctx.setFillColor((r.4 ? emeraldColor : NSColor(white: 1.0, alpha: 0.16)).cgColor)
            ctx.addPath(CGPath(roundedRect: tRect, cornerWidth: 7.5, cornerHeight: 7.5, transform: nil))
            ctx.fillPath()
            ctx.setFillColor(NSColor.white.cgColor)
            let kx = r.4 ? tRect.maxX - 13.5 : tRect.minX + 1.5
            ctx.fillEllipse(in: CGRect(x: kx, y: tRect.minY + 1.5, width: 12, height: 12))
            
            my += 38
        }
    }
    
    ctx.restoreGState()
}

// MARK: - 5 Slide Generators

func generateScreenshot1() {
    let (image, ctx) = createRetinaCanvas()
    let screenRect = CGRect(x: -70, y: 65, width: 640, height: 750)
    drawBezelAndScreen(ctx: ctx, screenRect: screenRect, isDark: false)
    
    drawShieldMenuBarIcon(ctx: ctx, center: CGPoint(x: 82, y: 83), scale: 1.1, isDark: false, colored: true, speedText: "142.4 MB")
    drawSystemIcons(ctx: ctx, startX: 195, y: 83, isDark: false)
    
    let popRect = CGRect(x: 45, y: 116, width: 278, height: 356)
    drawSimpleMenuPopover(ctx: ctx, rect: popRect)
    
    let rightX: CGFloat = 635
    ("Clean Menu Bar Utility" as NSString).draw(at: CGPoint(x: rightX, y: 170), withAttributes: [
        .font: NSFont.systemFont(ofSize: 22, weight: .bold),
        .foregroundColor: NSColor(red: 0.00, green: 0.68, blue: 0.48, alpha: 1.0)
    ])
    
    let titleStyle = NSMutableParagraphStyle()
    titleStyle.lineSpacing = 4
    ("Simple Session\nSwitchboard" as NSString).draw(at: CGPoint(x: rightX, y: 215), withAttributes: [
        .font: NSFont.systemFont(ofSize: 64, weight: .heavy),
        .foregroundColor: NSColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0),
        .paragraphStyle: titleStyle
    ])
    
    let subStyle = NSMutableParagraphStyle()
    subStyle.lineSpacing = 6
    ("See your active session usage at a glance and toggle\ninternet access per app with zero clutter." as NSString).draw(at: CGPoint(x: rightX, y: 400), withAttributes: [
        .font: NSFont.systemFont(ofSize: 18, weight: .regular),
        .foregroundColor: NSColor(red: 0.35, green: 0.38, blue: 0.44, alpha: 1.0),
        .paragraphStyle: subStyle
    ])
    
    let badgeRect = CGRect(x: rightX, y: 495, width: 205, height: 48)
    ctx.setFillColor(NSColor(red: 0.08, green: 0.09, blue: 0.11, alpha: 1.0).cgColor)
    ctx.addPath(CGPath(roundedRect: badgeRect, cornerWidth: 24, cornerHeight: 24, transform: nil))
    ctx.fillPath()
    drawShieldMenuBarIcon(ctx: ctx, center: CGPoint(x: rightX + 28, y: 519), scale: 1.0, isDark: true, colored: true)
    ("Free on GitHub" as NSString).draw(at: CGPoint(x: rightX + 52, y: 509), withAttributes: [
        .font: NSFont.systemFont(ofSize: 14, weight: .semibold),
        .foregroundColor: NSColor.white
    ])
    
    savePNG(image: image, path: "assets/screenshot-1.png")
    try? FileManager.default.removeItem(atPath: "docs/assets/screenshot-1.png")
    try! FileManager.default.copyItem(atPath: "assets/screenshot-1.png", toPath: "docs/assets/screenshot-1.png")
}

func generateScreenshot2() {
    let (image, ctx) = createRetinaCanvas()
    
    let leftX: CGFloat = 65
    ("Full Desktop App" as NSString).draw(at: CGPoint(x: leftX, y: 170), withAttributes: [
        .font: NSFont.systemFont(ofSize: 22, weight: .bold),
        .foregroundColor: NSColor(red: 0.00, green: 0.48, blue: 1.0, alpha: 1.0)
    ])
    
    let titleStyle = NSMutableParagraphStyle()
    titleStyle.lineSpacing = 4
    ("Usage History\n& Timeline" as NSString).draw(at: CGPoint(x: leftX, y: 215), withAttributes: [
        .font: NSFont.systemFont(ofSize: 58, weight: .heavy),
        .foregroundColor: NSColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0),
        .paragraphStyle: titleStyle
    ])
    
    let subStyle = NSMutableParagraphStyle()
    subStyle.lineSpacing = 6
    ("Open the full TripGuard app to explore\ndaily, weekly, and monthly bandwidth\nhistory across all your apps." as NSString).draw(at: CGPoint(x: leftX, y: 390), withAttributes: [
        .font: NSFont.systemFont(ofSize: 17, weight: .regular),
        .foregroundColor: NSColor(red: 0.35, green: 0.38, blue: 0.44, alpha: 1.0),
        .paragraphStyle: subStyle
    ])
    
    let winRect = CGRect(x: 500, y: 115, width: 735, height: 560)
    drawFullAppWindow(ctx: ctx, rect: winRect, showApplicationsTab: false)
    
    savePNG(image: image, path: "assets/screenshot-2.png")
    try? FileManager.default.removeItem(atPath: "docs/assets/screenshot-2.png")
    try! FileManager.default.copyItem(atPath: "assets/screenshot-2.png", toPath: "docs/assets/screenshot-2.png")
}

func generateScreenshot3() {
    let (image, ctx) = createRetinaCanvas()
    
    let winRect = CGRect(x: 45, y: 115, width: 735, height: 560)
    drawFullAppWindow(ctx: ctx, rect: winRect, showApplicationsTab: true)
    
    let rightX: CGFloat = 815
    ("Smart Filters & Sorting" as NSString).draw(at: CGPoint(x: rightX, y: 170), withAttributes: [
        .font: NSFont.systemFont(ofSize: 22, weight: .bold),
        .foregroundColor: NSColor(red: 0.00, green: 0.48, blue: 1.0, alpha: 1.0)
    ])
    
    let titleStyle = NSMutableParagraphStyle()
    titleStyle.lineSpacing = 4
    ("Every App\nDetailed" as NSString).draw(at: CGPoint(x: rightX, y: 215), withAttributes: [
        .font: NSFont.systemFont(ofSize: 58, weight: .heavy),
        .foregroundColor: NSColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0),
        .paragraphStyle: titleStyle
    ])
    
    let subStyle = NSMutableParagraphStyle()
    subStyle.lineSpacing = 6
    ("Filter by Allowed, Blocked, or Active\napps across Session, 7 Days, 30 Days,\nor 12 Months." as NSString).draw(at: CGPoint(x: rightX, y: 390), withAttributes: [
        .font: NSFont.systemFont(ofSize: 17, weight: .regular),
        .foregroundColor: NSColor(red: 0.35, green: 0.38, blue: 0.44, alpha: 1.0),
        .paragraphStyle: subStyle
    ])
    
    savePNG(image: image, path: "assets/screenshot-3.png")
    try? FileManager.default.removeItem(atPath: "docs/assets/screenshot-3.png")
    try! FileManager.default.copyItem(atPath: "assets/screenshot-3.png", toPath: "docs/assets/screenshot-3.png")
}

func generateScreenshot4() {
    let (image, ctx) = createRetinaCanvas()
    
    let screenRect = CGRect(x: -70, y: 65, width: 640, height: 750)
    drawBezelAndScreen(ctx: ctx, screenRect: screenRect, isDark: false)
    
    drawShieldMenuBarIcon(ctx: ctx, center: CGPoint(x: 82, y: 83), scale: 1.1, isDark: false, colored: true, speedText: "↓ 1.4 MB/s")
    drawSystemIcons(ctx: ctx, startX: 195, y: 83, isDark: false)
    
    let lensCenter = CGPoint(x: 205, y: 185)
    let lensRadius: CGFloat = 140
    let lensRect = CGRect(x: lensCenter.x - lensRadius, y: lensCenter.y - lensRadius, width: lensRadius * 2, height: lensRadius * 2)
    
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: 18), blur: 32, color: NSColor(white: 0, alpha: 0.30).cgColor)
    ctx.setFillColor(NSColor.white.cgColor)
    ctx.fillEllipse(in: lensRect)
    ctx.restoreGState()
    
    ctx.saveGState()
    ctx.addEllipse(in: lensRect.insetBy(dx: 7, dy: 7))
    ctx.clip()
    
    let zoomWPRect = CGRect(x: lensCenter.x - 220, y: lensCenter.y - 220, width: 440, height: 440)
    drawLightWallpaper(ctx: ctx, rect: zoomWPRect)
    
    let zMenuBarRect = CGRect(x: zoomWPRect.minX, y: lensCenter.y - 50, width: 440, height: 82)
    ctx.setFillColor(NSColor(white: 1.0, alpha: 0.42).cgColor)
    ctx.fill(zMenuBarRect)
    
    drawShieldMenuBarIcon(ctx: ctx, center: CGPoint(x: lensCenter.x - 75, y: lensCenter.y - 8), scale: 2.3, isDark: false, colored: true, speedText: "↓ 1.4 MB/s")
    ctx.restoreGState()
    
    ctx.saveGState()
    ctx.setStrokeColor(NSColor.white.cgColor)
    ctx.setLineWidth(7)
    ctx.strokeEllipse(in: lensRect.insetBy(dx: 3.5, dy: 3.5))
    ctx.setStrokeColor(NSColor(white: 0, alpha: 0.10).cgColor)
    ctx.setLineWidth(1)
    ctx.strokeEllipse(in: lensRect)
    ctx.restoreGState()
    
    let rightX: CGFloat = 635
    ("Menu Bar Speedometer" as NSString).draw(at: CGPoint(x: rightX, y: 170), withAttributes: [
        .font: NSFont.systemFont(ofSize: 22, weight: .bold),
        .foregroundColor: NSColor(red: 0.00, green: 0.68, blue: 0.48, alpha: 1.0)
    ])
    
    let titleStyle = NSMutableParagraphStyle()
    titleStyle.lineSpacing = 4
    ("Live Traffic\nAt a Glance" as NSString).draw(at: CGPoint(x: rightX, y: 215), withAttributes: [
        .font: NSFont.systemFont(ofSize: 64, weight: .heavy),
        .foregroundColor: NSColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0),
        .paragraphStyle: titleStyle
    ])
    
    let subStyle = NSMutableParagraphStyle()
    subStyle.lineSpacing = 6
    ("Monitor real-time download speeds and session usage\ndirectly in your macOS menu bar with zero Dock clutter." as NSString).draw(at: CGPoint(x: rightX, y: 400), withAttributes: [
        .font: NSFont.systemFont(ofSize: 18, weight: .regular),
        .foregroundColor: NSColor(red: 0.35, green: 0.38, blue: 0.44, alpha: 1.0),
        .paragraphStyle: subStyle
    ])
    
    savePNG(image: image, path: "assets/screenshot-4.png")
    try? FileManager.default.removeItem(atPath: "docs/assets/screenshot-4.png")
    try! FileManager.default.copyItem(atPath: "assets/screenshot-4.png", toPath: "docs/assets/screenshot-4.png")
}

func generateScreenshot5() {
    let (image, ctx) = createRetinaCanvas()
    
    let leftX: CGFloat = 80
    ("100% Open Source" as NSString).draw(at: CGPoint(x: leftX, y: 140), withAttributes: [
        .font: NSFont.systemFont(ofSize: 22, weight: .bold),
        .foregroundColor: NSColor(red: 0.00, green: 0.68, blue: 0.48, alpha: 1.0)
    ])
    
    let titleStyle = NSMutableParagraphStyle()
    titleStyle.lineSpacing = 4
    ("Zero\nSubscriptions" as NSString).draw(at: CGPoint(x: leftX, y: 185), withAttributes: [
        .font: NSFont.systemFont(ofSize: 64, weight: .heavy),
        .foregroundColor: NSColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0),
        .paragraphStyle: titleStyle
    ])
    
    let subStyle = NSMutableParagraphStyle()
    subStyle.lineSpacing = 6
    ("TripGuard is 100% free and open-source forever.\nCreated by Hassan Elkady — no annual fees, no\naccount lock-in, and zero telemetry." as NSString).draw(at: CGPoint(x: leftX, y: 365), withAttributes: [
        .font: NSFont.systemFont(ofSize: 18, weight: .regular),
        .foregroundColor: NSColor(red: 0.35, green: 0.38, blue: 0.44, alpha: 1.0),
        .paragraphStyle: subStyle
    ])
    
    let compBox = CGRect(x: leftX, y: 475, width: 460, height: 112)
    ctx.setFillColor(NSColor(red: 0.96, green: 0.97, blue: 0.98, alpha: 1.0).cgColor)
    ctx.addPath(CGPath(roundedRect: compBox, cornerWidth: 14, cornerHeight: 14, transform: nil))
    ctx.fillPath()
    ctx.setStrokeColor(NSColor(white: 0, alpha: 0.08).cgColor)
    ctx.setLineWidth(1)
    ctx.addPath(CGPath(roundedRect: compBox, cornerWidth: 14, cornerHeight: 14, transform: nil))
    ctx.strokePath()
    
    ("TripMode 3 Commercial Subscription:" as NSString).draw(at: CGPoint(x: leftX + 18, y: 492), withAttributes: [
        .font: NSFont.systemFont(ofSize: 14, weight: .regular),
        .foregroundColor: NSColor(white: 0.4, alpha: 1.0)
    ])
    ("$18.00 / yr" as NSString).draw(at: CGPoint(x: compBox.maxX - 96, y: 492), withAttributes: [
        .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
        .foregroundColor: NSColor(red: 0.85, green: 0.20, blue: 0.20, alpha: 1.0),
        .strikethroughStyle: NSUnderlineStyle.single.rawValue
    ])
    
    ctx.move(to: CGPoint(x: leftX + 18, y: 528))
    ctx.addLine(to: CGPoint(x: compBox.maxX - 18, y: 528))
    ctx.strokePath()
    
    ("TripGuard by Hassan Elkady:" as NSString).draw(at: CGPoint(x: leftX + 18, y: 548), withAttributes: [
        .font: NSFont.systemFont(ofSize: 14, weight: .bold),
        .foregroundColor: NSColor(red: 0.1, green: 0.1, blue: 0.12, alpha: 1.0)
    ])
    ("$0.00 Free" as NSString).draw(at: CGPoint(x: compBox.maxX - 96, y: 548), withAttributes: [
        .font: NSFont.systemFont(ofSize: 15, weight: .bold),
        .foregroundColor: NSColor(red: 0.00, green: 0.65, blue: 0.38, alpha: 1.0)
    ])
    
    ("local-over.github.io/tripguard" as NSString).draw(at: CGPoint(x: leftX, y: 640), withAttributes: [
        .font: NSFont.systemFont(ofSize: 16, weight: .bold),
        .foregroundColor: NSColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0)
    ])
    
    ctx.saveGState()
    let sweepPath = CGMutablePath()
    sweepPath.move(to: CGPoint(x: 590, y: 0))
    sweepPath.addLine(to: CGPoint(x: canvasWidth, y: 0))
    sweepPath.addLine(to: CGPoint(x: canvasWidth, y: canvasHeight))
    sweepPath.addLine(to: CGPoint(x: 750, y: canvasHeight))
    sweepPath.closeSubpath()
    ctx.addPath(sweepPath)
    ctx.clip()
    drawLightWallpaper(ctx: ctx, rect: CGRect(x: 560, y: 0, width: canvasWidth - 560, height: canvasHeight))
    ctx.restoreGState()
    
    let iconSize: CGFloat = 290
    let iconRect = CGRect(x: 820, y: 235, width: iconSize, height: iconSize)
    if let iconImage = NSImage(contentsOfFile: "assets/icon.png"),
       let cgIcon = iconImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: 26), blur: 44, color: NSColor(red: 0.00, green: 0.20, blue: 0.55, alpha: 0.42).cgColor)
        ctx.translateBy(x: iconRect.minX, y: iconRect.maxY)
        ctx.scaleBy(x: 1.0, y: -1.0)
        ctx.draw(cgIcon, in: CGRect(x: 0, y: 0, width: iconSize, height: iconSize))
        ctx.restoreGState()
    }
    
    savePNG(image: image, path: "assets/screenshot-5.png")
    try? FileManager.default.removeItem(atPath: "docs/assets/screenshot-5.png")
    try! FileManager.default.copyItem(atPath: "assets/screenshot-5.png", toPath: "docs/assets/screenshot-5.png")
}

func generateSliderGIF() {
    let gifURL = URL(fileURLWithPath: "assets/slider.gif")
    let targetWidth = 960
    let targetHeight = 600
    
    guard let dest = CGImageDestinationCreateWithURL(gifURL as CFURL, UTType.gif.identifier as CFString, 5, nil) else {
        return
    }
    
    let gifProps = [
        kCGImagePropertyGIFDictionary as String: [
            kCGImagePropertyGIFLoopCount as String: 0
        ]
    ] as CFDictionary
    CGImageDestinationSetProperties(dest, gifProps)
    
    let frameProps = [
        kCGImagePropertyGIFDictionary as String: [
            kCGImagePropertyGIFDelayTime as String: 3.2
        ]
    ] as CFDictionary
    
    for i in 1...5 {
        guard let img = NSImage(contentsOfFile: "assets/screenshot-\(i).png") else { continue }
        let resized = NSImage(size: NSSize(width: targetWidth, height: targetHeight))
        resized.lockFocus()
        img.draw(in: NSRect(x: 0, y: 0, width: targetWidth, height: targetHeight),
                 from: NSRect(origin: .zero, size: img.size),
                 operation: .copy,
                 fraction: 1.0)
        resized.unlockFocus()
        
        if let cgImg = resized.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            CGImageDestinationAddImage(dest, cgImg, frameProps)
        }
    }
    
    if CGImageDestinationFinalize(dest) {
        try? FileManager.default.removeItem(atPath: "docs/assets/slider.gif")
        try? FileManager.default.copyItem(atPath: "assets/slider.gif", toPath: "docs/assets/slider.gif")
    }
}

try? FileManager.default.createDirectory(atPath: "assets", withIntermediateDirectories: true)
try? FileManager.default.createDirectory(atPath: "docs/assets", withIntermediateDirectories: true)

generateAppIcon()
generateScreenshot1()
generateScreenshot2()
generateScreenshot3()
generateScreenshot4()
generateScreenshot5()
generateSliderGIF()
print("All TripGuard icons, Retina screenshots, and slider GIF generated!")
