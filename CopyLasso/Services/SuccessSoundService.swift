import AppKit
import Foundation

@MainActor
protocol SuccessSoundPlaying: AnyObject {
  func play()
  func stop()
}

@MainActor
protocol SuccessSoundPreferenceReading: AnyObject {
  var isSuccessSoundEnabled: Bool { get }
}

@MainActor
protocol SuccessSoundPlayback: AnyObject {
  @discardableResult
  func playFromStart() -> Bool
  func stop()
}

@MainActor
protocol SoundObjectPlaying: AnyObject {
  var isPlaying: Bool { get }
  var currentTime: TimeInterval { get set }

  @discardableResult
  func play() -> Bool

  @discardableResult
  func stop() -> Bool
}

extension NSSound: SoundObjectPlaying {}

@MainActor
final class AppKitSuccessSoundPlayback: SuccessSoundPlayback {
  private let sound: any SoundObjectPlaying

  init(sound: any SoundObjectPlaying) {
    self.sound = sound
  }

  func playFromStart() -> Bool {
    if sound.isPlaying {
      _ = sound.stop()
    }
    sound.currentTime = 0
    return sound.play()
  }

  func stop() {
    guard sound.isPlaying else { return }
    _ = sound.stop()
  }
}

@MainActor
final class SystemSuccessSoundPlayer: SuccessSoundPlaying {
  static let resourceName = "CopyLassoSuccess"
  static let resourceExtension = "wav"

  typealias EnabledProvider = @MainActor () -> Bool

  private let isEnabled: EnabledProvider
  private let playback: (any SuccessSoundPlayback)?

  convenience init(
    preferences: any SuccessSoundPreferenceReading,
    bundle: Bundle = .main
  ) {
    let playback = bundle.url(
      forResource: Self.resourceName,
      withExtension: Self.resourceExtension
    ).flatMap {
      NSSound(contentsOf: $0, byReference: false)
    }.map {
      AppKitSuccessSoundPlayback(sound: $0)
    }
    self.init(preferences: preferences, playback: playback)
  }

  convenience init(
    preferences: any SuccessSoundPreferenceReading,
    playback: (any SuccessSoundPlayback)?
  ) {
    self.init(
      isEnabled: { preferences.isSuccessSoundEnabled },
      playback: playback
    )
  }

  init(
    isEnabled: @escaping EnabledProvider,
    playback: (any SuccessSoundPlayback)?
  ) {
    self.isEnabled = isEnabled
    self.playback = playback
  }

  func play() {
    guard isEnabled() else { return }
    _ = playback?.playFromStart()
  }

  func stop() {
    playback?.stop()
  }
}

@MainActor
final class NoopSuccessSoundPlayer: SuccessSoundPlaying {
  func play() {}
  func stop() {}
}
