import CoreGraphics
import CoreText
import Foundation

/// Loads the on-device text-recognition models before the user needs them.
///
/// The first recognition in a process can wait 20 seconds or more while macOS
/// compiles Vision's models for the Neural Engine. That compiled form is cached
/// per app and is lost after app updates, restarts, and long idle periods, so
/// CopyLasso pays the cost in the background instead of during a capture.
protocol RecognitionWarming: Sendable {
  func warmUp() async throws
}

/// A fixed, app-drawn image used only to warm up recognition. It never
/// contains screen content.
enum RecognitionWarmUpSample {
  static let text = "CopyLasso 2026"
  static let pixelWidth = 480
  static let pixelHeight = 96

  static func makeImage() -> CGImage? {
    guard
      let context = CGContext(
        data: nil,
        width: pixelWidth,
        height: pixelHeight,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
    else {
      return nil
    }
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: pixelWidth, height: pixelHeight))

    let font =
      CTFontCreateUIFontForLanguage(.system, 44, nil)
      ?? CTFontCreateWithName("Helvetica" as CFString, 44, nil)
    let attributes: [NSAttributedString.Key: Any] = [
      NSAttributedString.Key(kCTFontAttributeName as String): font,
      NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(
        gray: 0,
        alpha: 1
      ),
    ]
    let line = CTLineCreateWithAttributedString(
      NSAttributedString(string: text, attributes: attributes)
    )
    var ascent: CGFloat = 0
    var descent: CGFloat = 0
    let width = CGFloat(CTLineGetTypographicBounds(line, &ascent, &descent, nil))
    context.textPosition = CGPoint(
      x: max(0, (CGFloat(pixelWidth) - width) / 2),
      y: (CGFloat(pixelHeight) - ascent - descent) / 2 + descent
    )
    CTLineDraw(line, context)
    return context.makeImage()
  }
}

/// Runs recognition warm-ups shortly after launch and after the Mac wakes,
/// retrying with backoff when a warm-up fails.
@MainActor
final class RecognitionWarmUpController {
  typealias Sleep = @Sendable (Duration) async throws -> Void

  static let defaultLaunchDelay: Duration = .seconds(5)
  static let defaultResumeDelay: Duration = .seconds(3)
  static let defaultRetryDelays: [Duration] = [.seconds(30), .seconds(120), .seconds(600)]

  private let warmer: any RecognitionWarming
  private let launchDelay: Duration
  private let resumeDelay: Duration
  private let retryDelays: [Duration]
  private let sleep: Sleep
  private var generation: UInt = 0
  private var isWarmingUp = false
  private(set) var activeTask: Task<Void, Never>?

  init(
    warmer: any RecognitionWarming,
    launchDelay: Duration = defaultLaunchDelay,
    resumeDelay: Duration = defaultResumeDelay,
    retryDelays: [Duration] = defaultRetryDelays,
    sleep: @escaping Sleep = { try await Task.sleep(for: $0) }
  ) {
    self.warmer = warmer
    self.launchDelay = launchDelay
    self.resumeDelay = resumeDelay
    self.retryDelays = retryDelays
    self.sleep = sleep
  }

  func start() {
    schedule(after: launchDelay)
  }

  func systemResumed() {
    schedule(after: resumeDelay)
  }

  func stop() {
    generation &+= 1
    activeTask?.cancel()
    activeTask = nil
    isWarmingUp = false
  }

  private func schedule(after delay: Duration) {
    // A warm-up already in progress covers this request, and cancelling it
    // would throw away work the system has already started.
    guard !isWarmingUp else { return }
    stop()
    let generation = generation
    activeTask = Task(priority: .utility) { [weak self] in
      await self?.run(firstDelay: delay, generation: generation)
    }
  }

  private func run(firstDelay: Duration, generation: UInt) async {
    var delay = firstDelay
    var remainingRetryDelays = retryDelays[...]
    while true {
      do {
        try await sleep(delay)
      } catch {
        return finish(generation)
      }
      guard isCurrent(generation) else { return }

      isWarmingUp = true
      let succeeded: Bool
      do {
        try await warmer.warmUp()
        succeeded = true
      } catch {
        succeeded = false
      }
      guard isCurrent(generation) else { return }
      isWarmingUp = false

      guard !succeeded, let nextDelay = remainingRetryDelays.popFirst() else {
        return finish(generation)
      }
      delay = nextDelay
    }
  }

  private func isCurrent(_ generation: UInt) -> Bool {
    generation == self.generation && !Task.isCancelled
  }

  private func finish(_ generation: UInt) {
    guard generation == self.generation else { return }
    activeTask = nil
    isWarmingUp = false
  }
}
