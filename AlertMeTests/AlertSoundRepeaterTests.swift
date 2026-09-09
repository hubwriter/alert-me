import Testing
@testable import AlertMe

@MainActor
struct AlertSoundRepeaterTests {
    @Test
    func playsImmediatelyAndThenTwentyMoreTimes() async {
        let player = CountingSoundPlayer()
        let repeater = AlertSoundRepeater(
            player: player,
            waiter: ImmediateSoundWaiter(),
            repeatCount: 20
        )

        repeater.start(named: "Glass", isSilent: false)
        await repeater.waitUntilFinishedForTesting()

        #expect(player.playCount == 21)
        #expect(player.lastName == "Glass")
    }

    @Test
    func silentAlertDoesNotPlay() async {
        let player = CountingSoundPlayer()
        let repeater = AlertSoundRepeater(
            player: player,
            waiter: ImmediateSoundWaiter(),
            repeatCount: 20
        )

        repeater.start(named: "Glass", isSilent: true)
        await repeater.waitUntilFinishedForTesting()

        #expect(player.playCount == 0)
    }

    @Test
    func stoppingAfterPresentationCancelsRepeats() async throws {
        let player = CountingSoundPlayer()
        let repeater = AlertSoundRepeater(
            player: player,
            waiter: LongSoundWaiter(),
            repeatCount: 20
        )

        repeater.start(named: "Glass", isSilent: false)
        repeater.stop()
        try await Task.sleep(for: .milliseconds(10))

        #expect(player.playCount == 1)
    }
}

@MainActor
private final class CountingSoundPlayer: AlertSoundPlaying {
    var playCount = 0
    var lastName: String?

    func play(named name: String) {
        playCount += 1
        lastName = name
    }
}

private struct ImmediateSoundWaiter: AlertSoundWaiting {
    func wait() async throws {
        await Task.yield()
    }
}

private struct LongSoundWaiter: AlertSoundWaiting {
    func wait() async throws {
        try await Task.sleep(for: .seconds(60))
    }
}
