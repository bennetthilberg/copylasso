import CoreGraphics
import Foundation
import ImageIO
import Vision
import XCTest

@testable import CopyLasso

private typealias NeutralTextObservation = CopyLasso.RecognizedTextObservation

@MainActor
final class VisionOCRServiceTests: XCTestCase {
  private enum TestError: Error {
    case missingFixture(String)
    case imageCreationFailed
    case injected
  }

  private struct ExactFixture {
    let name: String
    let expectedText: String
  }

  private let exactFixtures = [
    ExactFixture(
      name: "clean-multiline",
      expectedText: "Read every visible line Keep the original order Process all text offline"
    ),
    ExactFixture(
      name: "small-text",
      expectedText: "Small screen text should remain readable"
    ),
    ExactFixture(
      name: "light-on-dark",
      expectedText: "LIGHT TEXT ON DARK BACKGROUND"
    ),
    ExactFixture(
      name: "rasterized-application-text",
      expectedText:
        "CopyLasso Settings Capture text from any screen Recognition stays on this Mac Save Changes"
    ),
  ]

  func testDefaultConfigurationIsAccurateCorrectedUSEnglishWithoutLanguageDetection() async throws {
    let probe = PerformerProbe(
      observations: [
        NeutralTextObservation(
          text: "Local text",
          confidence: 0.91,
          boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.1)
        )
      ]
    )
    let service = VisionOCRService(performer: probe.perform)

    let observations = try await service.recognizeText(in: makeBlankImage())

    XCTAssertEqual(probe.configurations, [.englishAccurate])
    XCTAssertEqual(probe.imageSizes, [CGSize(width: 320, height: 200)])
    XCTAssertEqual(observations, probe.observations)
  }

  func testPinnedRevisionSupportsUSEnglishOnTheCurrentRuntime() throws {
    let request = VNRecognizeTextRequest()
    request.revision = VNRecognizeTextRequestRevision3
    request.recognitionLevel = .accurate

    XCTAssertTrue(try request.supportedRecognitionLanguages().contains("en-US"))
  }

  func testPerformerExecutesAwayFromMainThread() async throws {
    let probe = PerformerProbe(observations: [])
    let service = VisionOCRService(performer: probe.perform)

    _ = try await service.recognizeText(in: makeBlankImage())

    XCTAssertEqual(probe.mainThreadObservations, [false])
  }

  func testCleanFixturesMatchExactNormalizedTextAndNeutralGeometry() async throws {
    let service = VisionOCRService()

    for fixture in exactFixtures {
      let observations = try await service.recognizeText(in: loadFixture(named: fixture.name))
      XCTAssertEqual(normalizedText(observations), fixture.expectedText, "Fixture: \(fixture.name)")
      assertObservationGeometry(observations, fixture: fixture.name)
    }
  }

  func testModerateLowContrastMeetsQualityThreshold() async throws {
    let fixture = "moderate-low-contrast"
    let expected = "Moderate contrast should preserve these words"
    let observations = try await VisionOCRService().recognizeText(
      in: loadFixture(named: fixture)
    )
    let actual = normalizedText(observations)

    XCTAssertGreaterThanOrEqual(characterSimilarity(actual, expected), 0.90)
    assertExpectedTokensPresent(actual: actual, expected: expected, fixture: fixture)
    assertUnexpectedTokenLimit(actual: actual, expected: expected, maximum: 1, fixture: fixture)
    assertObservationGeometry(observations, fixture: fixture)
  }

  func testPhotographicSignMeetsQualityThreshold() async throws {
    let fixture = "photo-cedar-trail"
    let expected = "CEDAR TRAIL"
    let observations = try await VisionOCRService().recognizeText(
      in: loadFixture(named: fixture)
    )
    let actual = normalizedText(observations)

    XCTAssertTrue(actual.contains(expected))
    assertExpectedTokensPresent(actual: actual, expected: expected, fixture: fixture)
    assertUnexpectedTokenLimit(actual: actual, expected: expected, maximum: 1, fixture: fixture)
    assertObservationGeometry(observations, fixture: fixture)
  }

  func testBlankImageReturnsEmptySuccessDistinctFromFailure() async throws {
    let observations = try await VisionOCRService().recognizeText(in: makeBlankImage())

    XCTAssertEqual(observations, [])
  }

  func testLargeFixtureRecognizesExpectedText() async throws {
    let fixture = try scale(loadFixture(named: "clean-multiline"), by: 2)

    let observations = try await VisionOCRService().recognizeText(in: fixture)

    XCTAssertEqual(
      normalizedText(observations),
      "Read every visible line Keep the original order Process all text offline"
    )
  }

  func testUnexpectedEngineFailureMapsToTypedRecognitionFailure() async throws {
    let service = VisionOCRService { _, _, _ in throw TestError.injected }

    do {
      _ = try await service.recognizeText(in: makeBlankImage())
      XCTFail("Expected recognition to fail")
    } catch {
      XCTAssertEqual(error as? VisionOCRError, .recognitionFailed)
    }
  }

  func testCancellationReturnsPromptlyAndReleasesTheInputImage() async throws {
    let performer = HoldingPerformer()
    let service = VisionOCRService(performer: performer.perform)
    var image: CGImage? = try makeBlankImage(width: 4_000, height: 2_000)
    let weakImage = WeakImageReference(try XCTUnwrap(image))
    let task = startRecognition(service: service, image: try XCTUnwrap(image))
    image = nil
    await waitUntil { performer.hasStarted }

    let clock = ContinuousClock()
    let start = clock.now
    task.cancel()

    do {
      _ = try await task.value
      XCTFail("Expected cancellation")
    } catch {
      XCTAssertEqual(error as? VisionOCRError, .cancelled)
    }
    XCTAssertLessThan(seconds(from: clock.now - start), 1)
    await waitUntil { weakImage.image == nil }
    XCTAssertNil(weakImage.image)
  }

  func testCancellationBeforeRequestInstallationCancelsItWhenInstalled() {
    let cancellation = VisionOCRCancellation()
    let request = CancellationSpy()

    cancellation.cancel()
    XCTAssertFalse(cancellation.install(request))

    XCTAssertEqual(request.cancelCallCount, 1)
    XCTAssertTrue(cancellation.isCancelled)
  }

  func testCancellationAfterRequestInstallationCancelsExactlyOnce() {
    let cancellation = VisionOCRCancellation()
    let request = CancellationSpy()

    XCTAssertTrue(cancellation.install(request))
    cancellation.cancel()
    cancellation.cancel()

    XCTAssertEqual(request.cancelCallCount, 1)
    XCTAssertTrue(cancellation.isCancelled)
  }

  func testClearedRequestIsNotCancelledLater() {
    let cancellation = VisionOCRCancellation()
    let request = CancellationSpy()

    XCTAssertTrue(cancellation.install(request))
    cancellation.clear(request)
    cancellation.cancel()

    XCTAssertEqual(request.cancelCallCount, 0)
  }

  private func startRecognition(
    service: VisionOCRService,
    image: CGImage
  ) -> Task<[NeutralTextObservation], Error> {
    Task { try await service.recognizeText(in: image) }
  }

  private func loadFixture(named name: String) throws -> CGImage {
    let bundle = Bundle(for: Self.self)
    guard
      let url =
        bundle.url(forResource: name, withExtension: "png", subdirectory: "Fixtures")
        ?? bundle.url(forResource: name, withExtension: "png"),
      let source = CGImageSourceCreateWithURL(url as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
      throw TestError.missingFixture(name)
    }
    return image
  }

  private func makeBlankImage(width: Int = 320, height: Int = 200) throws -> CGImage {
    guard
      let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
    else {
      throw TestError.imageCreationFailed
    }
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    guard let image = context.makeImage() else {
      throw TestError.imageCreationFailed
    }
    return image
  }

  private func scale(_ image: CGImage, by factor: Int) throws -> CGImage {
    let width = image.width * factor
    let height = image.height * factor
    guard
      let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
    else {
      throw TestError.imageCreationFailed
    }
    context.interpolationQuality = .none
    context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
    guard let scaled = context.makeImage() else {
      throw TestError.imageCreationFailed
    }
    return scaled
  }

  private func normalizedText(_ observations: [NeutralTextObservation]) -> String {
    observations
      .sorted { lhs, rhs in
        let verticalDifference = abs(lhs.boundingBox.midY - rhs.boundingBox.midY)
        if verticalDifference > 0.02 {
          return lhs.boundingBox.midY > rhs.boundingBox.midY
        }
        return lhs.boundingBox.minX < rhs.boundingBox.minX
      }
      .map(\.text)
      .joined(separator: " ")
      .split(whereSeparator: \.isWhitespace)
      .joined(separator: " ")
  }

  private func assertObservationGeometry(
    _ observations: [NeutralTextObservation],
    fixture: String
  ) {
    for observation in observations {
      XCTAssertTrue((0...1).contains(observation.confidence), "Fixture: \(fixture)")
      let box = observation.boundingBox
      XCTAssertGreaterThanOrEqual(box.minX, 0, "Fixture: \(fixture)")
      XCTAssertGreaterThanOrEqual(box.minY, 0, "Fixture: \(fixture)")
      XCTAssertLessThanOrEqual(box.maxX, 1, "Fixture: \(fixture)")
      XCTAssertLessThanOrEqual(box.maxY, 1, "Fixture: \(fixture)")
    }
  }

  private func normalizedTokens(_ text: String) -> [String] {
    text.lowercased().split { !$0.isLetter }.map(String.init)
  }

  private func assertExpectedTokensPresent(actual: String, expected: String, fixture: String) {
    let actualTokens = normalizedTokens(actual)
    for token in normalizedTokens(expected) {
      XCTAssertTrue(actualTokens.contains(token), "Missing token in fixture \(fixture)")
    }
  }

  private func assertUnexpectedTokenLimit(
    actual: String,
    expected: String,
    maximum: Int,
    fixture: String
  ) {
    let expectedTokens = Set(normalizedTokens(expected))
    let unexpectedCount = normalizedTokens(actual).filter { !expectedTokens.contains($0) }.count
    XCTAssertLessThanOrEqual(unexpectedCount, maximum, "Fixture: \(fixture)")
  }

  private func characterSimilarity(_ lhs: String, _ rhs: String) -> Double {
    let left = Array(lhs)
    let right = Array(rhs)
    let denominator = max(left.count, right.count)
    guard denominator > 0 else { return 1 }

    var previous = Array(0...right.count)
    for (leftIndex, leftCharacter) in left.enumerated() {
      var current = [leftIndex + 1]
      for (rightIndex, rightCharacter) in right.enumerated() {
        current.append(
          min(
            current[rightIndex] + 1,
            previous[rightIndex + 1] + 1,
            previous[rightIndex] + (leftCharacter == rightCharacter ? 0 : 1)
          )
        )
      }
      previous = current
    }
    return 1 - (Double(previous[right.count]) / Double(denominator))
  }

  private func waitUntil(
    timeout: Duration = .seconds(2),
    _ condition: @escaping @MainActor () -> Bool
  ) async {
    let clock = ContinuousClock()
    let deadline = clock.now + timeout
    while !condition(), clock.now < deadline {
      await Task.yield()
    }
    XCTAssertTrue(condition())
  }

  private func seconds(from duration: Duration) -> Double {
    let components = duration.components
    return Double(components.seconds)
      + (Double(components.attoseconds) / 1_000_000_000_000_000_000)
  }
}

private final class PerformerProbe: @unchecked Sendable {
  let observations: [NeutralTextObservation]
  private let lock = NSLock()
  private var storedConfigurations: [VisionOCRConfiguration] = []
  private var storedImageSizes: [CGSize] = []
  private var storedMainThreadObservations: [Bool] = []

  init(observations: [NeutralTextObservation]) {
    self.observations = observations
  }

  var configurations: [VisionOCRConfiguration] {
    lock.withLock { storedConfigurations }
  }

  var imageSizes: [CGSize] {
    lock.withLock { storedImageSizes }
  }

  var mainThreadObservations: [Bool] {
    lock.withLock { storedMainThreadObservations }
  }

  func perform(
    _ image: CGImage,
    _ configuration: VisionOCRConfiguration,
    _ cancellation: VisionOCRCancellation
  ) throws -> [NeutralTextObservation] {
    lock.withLock {
      storedConfigurations.append(configuration)
      storedImageSizes.append(CGSize(width: image.width, height: image.height))
      storedMainThreadObservations.append(Thread.isMainThread)
    }
    return observations
  }
}

private final class HoldingPerformer: @unchecked Sendable {
  private let lock = NSLock()
  private var started = false

  var hasStarted: Bool {
    lock.withLock { started }
  }

  func perform(
    _ image: CGImage,
    _ configuration: VisionOCRConfiguration,
    _ cancellation: VisionOCRCancellation
  ) throws -> [NeutralTextObservation] {
    lock.withLock { started = true }
    while !cancellation.isCancelled {
      Thread.sleep(forTimeInterval: 0.001)
    }
    throw VisionOCRError.cancelled
  }
}

private final class CancellationSpy: VisionRequestCancelling, @unchecked Sendable {
  private let lock = NSLock()
  private var storedCancelCallCount = 0

  var cancelCallCount: Int {
    lock.withLock { storedCancelCallCount }
  }

  func cancel() {
    lock.withLock { storedCancelCallCount += 1 }
  }
}

private final class WeakImageReference {
  weak var image: CGImage?

  init(_ image: CGImage) {
    self.image = image
  }
}
