import AppKit
import Testing

@MainActor
struct AppIconTests {
    @Test(arguments: [16, 32, 64, 128, 256, 512, 1024])
    func iconAssetsHaveExpectedSizeTransparencyAndColors(size: Int) throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let url = repositoryRoot.appendingPathComponent(
            "AlertMe/Assets.xcassets/AppIcon.appiconset/AppIcon-\(size).png"
        )
        let bitmap = try #require(NSBitmapImageRep(data: Data(contentsOf: url)))
        #expect(bitmap.pixelsWide == size)
        #expect(bitmap.pixelsHigh == size)
        #expect(bitmap.hasAlpha)
        let corner = try #require(bitmap.colorAt(x: 0, y: 0))
        #expect(corner.alphaComponent == 0)

        let background = try #require(
            bitmap.colorAt(x: size / 2, y: size / 8)?.usingColorSpace(.sRGB)
        )
        #expect(background.alphaComponent > 0.99)
        #expect(background.redComponent > background.greenComponent * 3)
        #expect(background.redComponent > background.blueComponent * 2)

        if size >= 64 {
            let hands = try #require(
                bitmap.colorAt(x: size / 2, y: size / 2)?.usingColorSpace(.sRGB)
            )
            #expect(hands.redComponent > 0.95)
            #expect(hands.greenComponent > 0.95)
            #expect(hands.blueComponent > 0.95)
        }
    }

    @Test
    func appBundleContainsItsConfiguredIcon() throws {
        let name = try #require(Bundle.main.object(forInfoDictionaryKey: "CFBundleIconFile") as? String)
        let url = try #require(Bundle.main.url(
            forResource: (name as NSString).deletingPathExtension,
            withExtension: "icns"
        ))
        let icon = try #require(NSImage(contentsOf: url))
        #expect(icon.isValid)
    }
}
