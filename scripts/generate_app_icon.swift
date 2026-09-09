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
        starting: NSColor(red: 0.08, green: 0.34, blue: 0.91, alpha: 1),
        ending: NSColor(red: 0.10, green: 0.78, blue: 0.86, alpha: 1)
    )!
    gradient.draw(in: background, angle: -55)

    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.24)
    shadow.shadowBlurRadius = scaled(28, for: size)
    shadow.shadowOffset = NSSize(width: 0, height: scaled(-14, for: size))
    shadow.set()

    let leftBell = NSBezierPath(
        roundedRect: NSRect(
            x: scaled(190, for: size),
            y: scaled(700, for: size),
            width: scaled(220, for: size),
            height: scaled(150, for: size)
        ),
        xRadius: scaled(75, for: size),
        yRadius: scaled(75, for: size)
    )

    let rightBell = NSBezierPath(
        roundedRect: NSRect(
            x: scaled(614, for: size),
            y: scaled(700, for: size),
            width: scaled(220, for: size),
            height: scaled(150, for: size)
        ),
        xRadius: scaled(75, for: size),
        yRadius: scaled(75, for: size)
    )

    let coral = NSColor(red: 1.0, green: 0.35, blue: 0.22, alpha: 1)
    coral.setFill()
    leftBell.fill()
    rightBell.fill()

    let clockBody = NSBezierPath(
        ovalIn: NSRect(
            x: scaled(180, for: size),
            y: scaled(170, for: size),
            width: scaled(664, for: size),
            height: scaled(664, for: size)
        )
    )
    coral.setFill()
    clockBody.fill()
    NSGraphicsContext.restoreGraphicsState()

    let face = NSBezierPath(
        ovalIn: NSRect(
            x: scaled(252, for: size),
            y: scaled(242, for: size),
            width: scaled(520, for: size),
            height: scaled(520, for: size)
        )
    )
    NSColor(red: 1.0, green: 0.96, blue: 0.82, alpha: 1).setFill()
    face.fill()

    let feet = NSBezierPath()
    feet.lineWidth = scaled(58, for: size)
    feet.lineCapStyle = .round
    feet.move(to: NSPoint(x: scaled(330, for: size), y: scaled(230, for: size)))
    feet.line(to: NSPoint(x: scaled(250, for: size), y: scaled(125, for: size)))
    feet.move(to: NSPoint(x: scaled(694, for: size), y: scaled(230, for: size)))
    feet.line(to: NSPoint(x: scaled(774, for: size), y: scaled(125, for: size)))
    coral.setStroke()
    feet.stroke()

    let topButton = NSBezierPath(
        roundedRect: NSRect(
            x: scaled(448, for: size),
            y: scaled(814, for: size),
            width: scaled(128, for: size),
            height: scaled(48, for: size)
        ),
        xRadius: scaled(24, for: size),
        yRadius: scaled(24, for: size)
    )
    NSColor(red: 1.0, green: 0.76, blue: 0.15, alpha: 1).setFill()
    topButton.fill()

    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    let attributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(
            ofSize: scaled(360, for: size),
            weight: .heavy
        ),
        .foregroundColor: NSColor(red: 0.04, green: 0.23, blue: 0.55, alpha: 1),
        .paragraphStyle: paragraph
    ]
    NSString(string: "A").draw(
        in: NSRect(
            x: scaled(252, for: size),
            y: scaled(300, for: size),
            width: scaled(520, for: size),
            height: scaled(410, for: size)
        ),
        withAttributes: attributes
    )

    NSGraphicsContext.restoreGraphicsState()

    guard let png = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Unable to create \(size)-pixel icon")
    }
    try png.write(to: outputDirectory.appendingPathComponent("AppIcon-\(size).png"))
}
