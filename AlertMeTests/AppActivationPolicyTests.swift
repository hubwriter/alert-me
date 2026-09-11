import AppKit
import Testing
@testable import AlertMe

struct AppActivationPolicyTests {
    @Test
    func visibleWindowUsesRegularActivationPolicy() {
        #expect(
            AppActivationPolicy.policy(
                hasVisibleAppWindow: true,
                isUITesting: false
            ) == .regular
        )
    }

    @Test
    func backgroundOnlyAppUsesAccessoryActivationPolicy() {
        #expect(
            AppActivationPolicy.policy(
                hasVisibleAppWindow: false,
                isUITesting: false
            ) == .accessory
        )
    }

    @Test
    func uiTestsAlwaysUseRegularActivationPolicy() {
        #expect(
            AppActivationPolicy.policy(
                hasVisibleAppWindow: false,
                isUITesting: true
            ) == .regular
        )
    }
}
