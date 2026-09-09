import AppKit
import Testing
@testable import AlertMe

@MainActor
struct AlertPanelTests {
    @Test
    func panelCannotBeClosedWithEscape() {
        let panel = AlertPanel(
            contentRect: .zero,
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        #expect(panel.canBecomeKey)
        #expect(!panel.styleMask.contains(.closable))
    }
}
