import AppKit

public final class MenuBarIconGenerator {
    public static let shared = MenuBarIconGenerator()
    
    private init() {}
    
    private func createShieldPath(in rect: NSRect) -> NSBezierPath {
        let path = NSBezierPath()
        let midX = rect.midX
        let topY = rect.maxY
        let bottomY = rect.minY
        let leftX = rect.minX
        let rightX = rect.maxX
        let shoulderY = rect.minY + rect.height * 0.78
        let waistY = rect.minY + rect.height * 0.36
        
        // Start at top crest center
        path.move(to: NSPoint(x: midX, y: topY))
        // Top-right shoulder
        path.curve(
            to: NSPoint(x: rightX, y: shoulderY),
            controlPoint1: NSPoint(x: midX + rect.width * 0.28, y: topY - 0.5),
            controlPoint2: NSPoint(x: rightX - 0.5, y: shoulderY + 1.2)
        )
        // Right side curving down to bottom tip
        path.curve(
            to: NSPoint(x: midX, y: bottomY),
            controlPoint1: NSPoint(x: rightX, y: waistY),
            controlPoint2: NSPoint(x: midX + rect.width * 0.25, y: bottomY + 1.5)
        )
        // Left side curving up from bottom tip to top-left shoulder
        path.curve(
            to: NSPoint(x: leftX, y: shoulderY),
            controlPoint1: NSPoint(x: midX - rect.width * 0.25, y: bottomY + 1.5),
            controlPoint2: NSPoint(x: leftX, y: waistY)
        )
        // Back to top crest center
        path.curve(
            to: NSPoint(x: midX, y: topY),
            controlPoint1: NSPoint(x: leftX + 0.5, y: shoulderY + 1.2),
            controlPoint2: NSPoint(x: midX - rect.width * 0.28, y: topY - 0.5)
        )
        path.close()
        return path
    }
    
    public func inactiveIcon() -> NSImage {
        let size: CGFloat = 18
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        
        let strokeColor = NSColor.black
        strokeColor.setStroke()
        strokeColor.setFill()
        
        let shieldRect = NSRect(x: 2.5, y: 2.0, width: 11.5, height: 13.5)
        let shield = createShieldPath(in: shieldRect)
        shield.lineWidth = 1.35
        shield.lineJoinStyle = .round
        shield.stroke()
        
        // Internal minimal signal dot + vertical spine
        let dotRect = NSRect(x: shieldRect.midX - 1.2, y: shieldRect.midY - 1.2, width: 2.4, height: 2.4)
        NSBezierPath(ovalIn: dotRect).fill()
        
        image.unlockFocus()
        image.isTemplate = true
        return image
    }
    
    public func activeIcon(frame: Int, colored: Bool = false) -> NSImage {
        let size: CGFloat = 18
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        
        let fillColor: NSColor
        if colored {
            fillColor = NSColor(red: 0.00, green: 0.72, blue: 0.56, alpha: 1.0)
        } else {
            fillColor = NSColor.black
        }
        fillColor.setFill()
        fillColor.setStroke()
        
        let shieldRect = NSRect(x: 2.0, y: 1.8, width: 11.2, height: 13.2)
        let shield = createShieldPath(in: shieldRect)
        shield.fill()
        
        // Cutout inner checkmark / signal glyph using destinationOut
        NSGraphicsContext.current?.compositingOperation = .destinationOut
        let check = NSBezierPath()
        check.move(to: NSPoint(x: shieldRect.midX - 2.4, y: shieldRect.midY - 0.2))
        check.line(to: NSPoint(x: shieldRect.midX - 0.5, y: shieldRect.midY - 2.1))
        check.line(to: NSPoint(x: shieldRect.midX + 2.8, y: shieldRect.midY + 1.8))
        check.lineWidth = 1.5
        check.lineCapStyle = .round
        check.lineJoinStyle = .round
        NSColor.black.setStroke()
        check.stroke()
        
        NSGraphicsContext.current?.compositingOperation = .sourceOver
        if colored {
            NSColor(red: 0.00, green: 0.68, blue: 0.95, alpha: 1.0).setStroke()
        } else {
            NSColor.black.setStroke()
        }
        
        // Animated Signal Pulse Waves at Top-Right (Frames 0...3)
        let center = NSPoint(x: 11.8, y: 11.8)
        let phase = CGFloat(frame % 4) * 0.25
        
        for i in 0..<2 {
            let progress = (CGFloat(i) * 0.5 + phase).truncatingRemainder(dividingBy: 1.0)
            let radius = 2.2 + progress * 3.4
            let arc = NSBezierPath()
            arc.appendArc(withCenter: center, radius: radius, startAngle: 12, endAngle: 78)
            arc.lineWidth = 1.15
            arc.lineCapStyle = .round
            arc.stroke()
        }
        
        image.unlockFocus()
        image.isTemplate = !colored
        return image
    }
}
