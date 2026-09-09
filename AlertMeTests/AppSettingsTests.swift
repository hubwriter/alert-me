import Foundation
import Testing
@testable import AlertMe

@MainActor
struct AppSettingsTests {
    @Test
    func changingDefaultSoundPersists() throws {
        let suiteName = "AppSettingsTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let settings = AppSettings(
            defaults: defaults,
            availableSounds: ["Glass", "Ping"]
        )
        settings.soundName = "Ping"

        let reloadedSettings = AppSettings(
            defaults: defaults,
            availableSounds: ["Glass", "Ping"]
        )
        #expect(reloadedSettings.soundName == "Ping")
    }

    @Test
    func DockIconIsHiddenByDefaultAndPreferencePersists() throws {
        let suiteName = "AppSettingsTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let settings = AppSettings(defaults: defaults, availableSounds: ["Glass"])
        #expect(!settings.showsDockIcon)

        settings.showsDockIcon = true
        let reloadedSettings = AppSettings(defaults: defaults, availableSounds: ["Glass"])
        #expect(reloadedSettings.showsDockIcon)
    }

    @Test
    func LightModeIsDefaultAndDarkModePersists() throws {
        let suiteName = "AppSettingsTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let settings = AppSettings(defaults: defaults, availableSounds: ["Glass"])
        #expect(settings.colorMode == .light)

        settings.colorMode = .dark
        let reloadedSettings = AppSettings(defaults: defaults, availableSounds: ["Glass"])
        #expect(reloadedSettings.colorMode == .dark)
    }
}
