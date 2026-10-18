import AppKit

let outputDirectory = URL(
    fileURLWithPath: CommandLine.arguments[1],
    isDirectory: true
)
let sizes = [16, 32, 64, 128, 256, 512, 1024]

func scaled(_ value: CGFloat, for size: Int) -> CGFloat {
    value * CGFloat(size) / 1024
}

for size in sizes {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size,
        pixelsHigh: size,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ), let graphicsContext = NSGraphicsContext(bitmapImageRep: bitmap) else {
        fatalError("Unable to create \(size)-pixel drawing context")
    }
    bitmap.size = NSSize(width: size, height: size)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphicsContext

    let canvas = NSRect(x: 0, y: 0, width: size, height: size)
    NSColor.clear.setFill()
    canvas.fill()

    let background = NSBezierPath(
        roundedRect: canvas.insetBy(
            dx: scaled(54, for: size),
            dy: scaled(54, for: size)
        ),
        xRadius: scaled(220, for: size),
        yRadius: scaled(220, for: size)
    )
    let gradient = NSGradient(
        starting: NSColor(red: 0.53, green: 0.02, blue: 0.10, alpha: 1),
        ending: NSColor(red: 0.39, green: 0.00, blue: 0.055, alpha: 1)
    )!
    gradient.draw(in: background, angle: -55)

    NSColor.white.setFill()
    NSColor.white.setStroke()

    for (centerX, angle): (CGFloat, CGFloat) in [(352, 45), (672, -45)] {
        let bell = NSBezierPath()
        bell.appendArc(
            withCenter: .zero,
            radius: scaled(80, for: size),
            startAngle: 0,
            endAngle: 180
        )
        bell.close()
        var transform = AffineTransform()
        transform.translate(x: scaled(centerX, for: size), y: scaled(704, for: size))
        transform.rotate(byDegrees: angle)
        bell.transform(using: transform)
        bell.lineWidth = scaled(10, for: size)
        bell.lineJoinStyle = .round
        bell.fill()
        bell.stroke()
    }

    let clock = NSBezierPath(
        ovalIn: NSRect(
            x: scaled(290, for: size),
            y: scaled(278, for: size),
            width: scaled(444, for: size),
            height: scaled(444, for: size)
        )
    )
    clock.lineWidth = max(1, scaled(42, for: size))
    clock.stroke()

    let feet = NSBezierPath()
    feet.lineWidth = max(1, scaled(44, for: size))
    feet.lineCapStyle = .round
    feet.move(to: NSPoint(x: scaled(350, for: size), y: scaled(338, for: size)))
    feet.line(to: NSPoint(x: scaled(312, for: size), y: scaled(264, for: size)))
    feet.move(to: NSPoint(x: scaled(674, for: size), y: scaled(338, for: size)))
    feet.line(to: NSPoint(x: scaled(712, for: size), y: scaled(264, for: size)))
    feet.stroke()

    let hands = NSBezierPath()
    hands.lineWidth = max(1, scaled(42, for: size))
    hands.lineCapStyle = .round
    hands.lineJoinStyle = .round
    hands.move(to: NSPoint(x: scaled(512, for: size), y: scaled(626, for: size)))
    hands.line(to: NSPoint(x: scaled(512, for: size), y: scaled(500, for: size)))
    hands.line(to: NSPoint(x: scaled(612, for: size), y: scaled(500, for: size)))
    hands.stroke()

    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Unable to create \(size)-pixel icon")
    }
    try png.write(to: outputDirectory.appendingPathComponent("AppIcon-\(size).png"))
}
