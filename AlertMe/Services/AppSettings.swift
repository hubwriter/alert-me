import AppKit
import Combine
import Foundation
import SwiftUI

enum AppColorMode: String, CaseIterable, Identifiable, Sendable {
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light: "Light"
        case .dark: "Dark"
        }
    }

    var colorScheme: ColorScheme {
        switch self {
        case .light: .light
        case .dark: .dark
        }
    }

    var nsAppearance: NSAppearance? {
        NSAppearance(
            named: self == .light ? .aqua : .darkAqua
        )
    }
}

@MainActor
final class AppSettings: ObservableObject {
    private enum Key {
        static let soundName = "soundName"
        static let colorMode = "colorMode"
    }

    private let defaults: UserDefaults

    @Published var soundName: String {
        didSet {
            defaults.set(soundName, forKey: Key.soundName)
        }
    }

    @Published var colorMode: AppColorMode {
        didSet {
            defaults.set(colorMode.rawValue, forKey: Key.colorMode)
        }
    }

    let availableSounds: [String]

    init(
        defaults: UserDefaults = .standard,
        availableSounds: [String] = SystemSoundService.availableSoundNames()
    ) {
        self.defaults = defaults
        let sounds = availableSounds.isEmpty ? ["Glass"] : availableSounds
        self.availableSounds = sounds
        let savedName = defaults.string(forKey: Key.soundName)
        soundName = savedName.flatMap { sounds.contains($0) ? $0 : nil }
            ?? sounds.first
            ?? "Glass"
        colorMode = defaults.string(forKey: Key.colorMode)
            .flatMap(AppColorMode.init(rawValue:))
            ?? .light
    }

    func previewSound() {
        SystemSoundService.play(named: soundName)
    }

}

enum SystemSoundService {
    static func availableSoundNames() -> [String] {
        let directory = URL(fileURLWithPath: "/System/Library/Sounds", isDirectory: true)
        let names = (try? FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ))?
            .filter { ["aiff", "wav", "caf"].contains($0.pathExtension.lowercased()) }
            .map { $0.deletingPathExtension().lastPathComponent }
            .sorted()
        return names?.isEmpty == false ? names! : ["Glass"]
    }

    static func play(named name: String) {
        (NSSound(named: NSSound.Name(name)) ?? NSSound.beepSound)?.play()
    }
}

private extension NSSound {
    static var beepSound: NSSound? {
        NSSound(named: "Glass")
    }
}
