import XCTest

@testable import CopyLasso

@MainActor
final class SuccessSoundServiceTests: XCTestCase {
  func testEnabledPlayerStartsOnePlaybackPerSuccessfulRequest() {
    let playback = StubSuccessSoundPlayback()
    let player = SystemSuccessSoundPlayer(
      isEnabled: { true },
      playback: playback
    )

    player.play()
    player.play()

    XCTAssertEqual(playback.playFromStartCallCount, 2)
  }

  func testDisabledPlayerNeverTouchesPlayback() {
    let playback = StubSuccessSoundPlayback()
    let player = SystemSuccessSoundPlayer(
      isEnabled: { false },
      playback: playback
    )

    player.play()
    player.stop()

    XCTAssertEqual(playback.playFromStartCallCount, 0)
    XCTAssertEqual(playback.stopCallCount, 1)
  }

  func testPreferenceBackedPlayerReadsTheCurrentSettingForEveryRequest() {
    let preferences = StubSuccessSoundPreferences(isSuccessSoundEnabled: true)
    let playback = StubSuccessSoundPlayback()
    let player = SystemSuccessSoundPlayer(
      preferences: preferences,
      playback: playback
    )

    player.play()
    preferences.isSuccessSoundEnabled = false
    player.play()

    XCTAssertEqual(playback.playFromStartCallCount, 1)
  }

  func testUnavailableAudioIsASilentNoop() {
    let player = SystemSuccessSoundPlayer(
      isEnabled: { true },
      playback: nil
    )

    player.play()
    player.stop()
  }

  func testPlaybackFailureDoesNotEscapeTheSoundBoundary() {
    let playback = StubSuccessSoundPlayback(playResult: false)
    let player = SystemSuccessSoundPlayer(
      isEnabled: { true },
      playback: playback
    )

    player.play()

    XCTAssertEqual(playback.playFromStartCallCount, 1)
  }

  func testCleanupIsForwardedAndRemainsIdempotent() {
    let playback = StubSuccessSoundPlayback()
    let player = SystemSuccessSoundPlayer(
      isEnabled: { true },
      playback: playback
    )

    player.stop()
    player.stop()

    XCTAssertEqual(playback.stopCallCount, 2)
  }

  func testAppKitPlaybackRestartsAnActiveSoundWithoutOverlap() {
    let sound = StubSoundObject(isPlaying: true, currentTime: 0.12)
    let playback = AppKitSuccessSoundPlayback(sound: sound)

    XCTAssertTrue(playback.playFromStart())

    XCTAssertEqual(sound.events, [.stop, .setCurrentTime(0), .play])
    XCTAssertEqual(sound.currentTime, 0)
  }

  func testAppKitPlaybackStartsAnIdleSoundWithoutRedundantStop() {
    let sound = StubSoundObject(isPlaying: false, currentTime: 0.18)
    let playback = AppKitSuccessSoundPlayback(sound: sound)

    XCTAssertTrue(playback.playFromStart())

    XCTAssertEqual(sound.events, [.setCurrentTime(0), .play])
  }

  func testAppKitPlaybackStopsOnlyWhenActive() {
    let active = StubSoundObject(isPlaying: true)
    let idle = StubSoundObject(isPlaying: false)

    AppKitSuccessSoundPlayback(sound: active).stop()
    AppKitSuccessSoundPlayback(sound: idle).stop()

    XCTAssertEqual(active.events, [.stop])
    XCTAssertEqual(idle.events, [])
  }
}

@MainActor
private final class StubSuccessSoundPreferences: SuccessSoundPreferenceReading {
  var isSuccessSoundEnabled: Bool

  init(isSuccessSoundEnabled: Bool) {
    self.isSuccessSoundEnabled = isSuccessSoundEnabled
  }
}

@MainActor
private final class StubSuccessSoundPlayback: SuccessSoundPlayback {
  private let playResult: Bool
  private(set) var playFromStartCallCount = 0
  private(set) var stopCallCount = 0

  init(playResult: Bool = true) {
    self.playResult = playResult
  }

  func playFromStart() -> Bool {
    playFromStartCallCount += 1
    return playResult
  }

  func stop() {
    stopCallCount += 1
  }
}

@MainActor
private final class StubSoundObject: SoundObjectPlaying {
  enum Event: Equatable {
    case stop
    case setCurrentTime(TimeInterval)
    case play
  }

  var isPlaying: Bool
  var currentTime: TimeInterval {
    didSet {
      events.append(.setCurrentTime(currentTime))
    }
  }
  private(set) var events: [Event] = []

  init(isPlaying: Bool, currentTime: TimeInterval = 0) {
    self.isPlaying = isPlaying
    self.currentTime = currentTime
  }

  func play() -> Bool {
    events.append(.play)
    isPlaying = true
    return true
  }

  func stop() -> Bool {
    events.append(.stop)
    isPlaying = false
    return true
  }
}
