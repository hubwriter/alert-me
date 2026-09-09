import Foundation

@MainActor
protocol AlertSoundPlaying {
    func play(named name: String)
}

@MainActor
struct SystemAlertSoundPlayer: AlertSoundPlaying {
    func play(named name: String) {
        SystemSoundService.play(named: name)
    }
}

protocol AlertSoundWaiting: Sendable {
    func wait() async throws
}

struct FiveSecondAlertSoundWaiter: AlertSoundWaiting {
    func wait() async throws {
        try await Task.sleep(for: .seconds(5), tolerance: .zero)
    }
}

@MainActor
final class AlertSoundRepeater {
    private let player: AlertSoundPlaying
    private let waiter: AlertSoundWaiting
    private let repeatCount: Int
    private var task: Task<Void, Never>?

    init(
        player: AlertSoundPlaying = SystemAlertSoundPlayer(),
        waiter: AlertSoundWaiting = FiveSecondAlertSoundWaiter(),
        repeatCount: Int = 20
    ) {
        self.player = player
        self.waiter = waiter
        self.repeatCount = repeatCount
    }

    func start(named name: String, isSilent: Bool) {
        stop()
        guard !isSilent else {
            return
        }

        player.play(named: name)
        task = Task { [weak self] in
            guard let self else {
                return
            }
            for _ in 0..<repeatCount {
                do {
                    try await waiter.wait()
                } catch {
                    return
                }
                guard !Task.isCancelled else {
                    return
                }
                player.play(named: name)
            }
        }
    }

    func stop() {
        task?.cancel()
        task = nil
    }

    func waitUntilFinishedForTesting() async {
        await task?.value
    }
}
