import CoreGraphics
import Foundation
import ImageIO
import Vision
import XCTest

@testable import CopyLasso

@MainActor
final class VisionTextRecognizerTests: XCTestCase {
  private enum TestError: Error {
    case missingFixture(String)
    case imageCreationFailed
    case injectedFailure
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

  func testRevisionThreeSupportsUSEnglish() throws {
    let request = VNRecognizeTextRequest()
    request.revision = VNRecognizeTextRequestRevision3
    request.recognitionLevel = .accurate

    let languages = try request.supportedRecognitionLanguages()
    if !languages.contains("en-US") {
      XCTFail("Vision revision 3 does not support the required English locale")
    }
  }

  func testCleanFixturesMatchExactNormalizedText() async throws {
    let recognizer = VisionTextRecognizer()

    for fixture in exactFixtures {
      let observations = try await recognizer.recognize(loadFixture(named: fixture.name))
      assertObservationGeometry(observations, fixture: fixture.name)
      if normalizedText(observations) != fixture.expectedText {
        XCTFail("OCR mismatch for fixture \(fixture.name)")
      }
    }
  }

  func testModerateLowContrastMeetsQualityThreshold() async throws {
    let fixture = "moderate-low-contrast"
    let expected = "Moderate contrast should preserve these words"
    let observations = try await VisionTextRecognizer().recognize(loadFixture(named: fixture))
    let actual = normalizedText(observations)

    if characterSimilarity(actual, expected) < 0.90 {
      XCTFail("OCR character similarity was below 0.90 for fixture \(fixture)")
    }
    assertExpectedTokensPresent(actual: actual, expected: expected, fixture: fixture)
    assertUnexpectedTokenLimit(actual: actual, expected: expected, maximum: 1, fixture: fixture)
  }

  func testPhotographicSignMeetsQualityThreshold() async throws {
    let fixture = "photo-cedar-trail"
    let expected = "CEDAR TRAIL"
    let observations = try await VisionTextRecognizer().recognize(loadFixture(named: fixture))
    let actual = normalizedText(observations)

    if !actual.contains(expected) {
      XCTFail("Required sign phrase was not recognized in fixture \(fixture)")
    }
    assertExpectedTokensPresent(actual: actual, expected: expected, fixture: fixture)
    assertUnexpectedTokenLimit(actual: actual, expected: expected, maximum: 1, fixture: fixture)
  }

  func testBlankImageReturnsNoObservations() async throws {
    let observations = try await VisionTextRecognizer().recognize(try makeBlankImage())
    if !observations.isEmpty {
      XCTFail("Blank image unexpectedly produced OCR observations")
    }
  }

  func testImageOrientationIsHonored() async throws {
    let expected = exactFixtures[1].expectedText
    let image = try loadFixture(named: exactFixtures[1].name)
    let rotatedImage = try rotateClockwise(image)
    let observations = try await VisionTextRecognizer().recognize(
      rotatedImage,
      orientation: .right
    )

    if normalizedText(observations) != expected {
      XCTFail("OCR orientation handling did not preserve the fixture text")
    }
  }

  func testVisionErrorsArePropagated() async throws {
    let recognizer = VisionTextRecognizer(
      performer: { _, _, _ in
        throw TestError.injectedFailure
      }
    )

    do {
      _ = try await recognizer.recognize(try makeBlankImage())
      XCTFail("Injected Vision failure was not propagated")
    } catch TestError.injectedFailure {
      // Expected.
    } catch {
      XCTFail("Unexpected error type was propagated")
    }
  }

  func testLanguageCorrectionComparison() async throws {
    #if COPYLASSO_RUN_OCR_DIAGNOSTIC
      let corrected = VisionTextRecognizer(
        configuration: .init(usesLanguageCorrection: true)
      )
      let uncorrected = VisionTextRecognizer(
        configuration: .init(usesLanguageCorrection: false)
      )
      let correctedPasses = try await fixtureQualityPassCount(recognizer: corrected)
      let uncorrectedPasses = try await fixtureQualityPassCount(recognizer: uncorrected)

      let summary =
        "OCR language correction comparison fixtures=6 corrected=\(correctedPasses) uncorrected=\(uncorrectedPasses)"
      print(summary)
      XCTContext.runActivity(named: summary) { _ in }
      if correctedPasses < uncorrectedPasses {
        XCTFail("Language correction reduced the fixture quality pass count")
      }
    #else
      throw XCTSkip("Build with COPYLASSO_RUN_OCR_DIAGNOSTIC to compare language correction")
    #endif
  }

  func testOrdinaryRegionMedianRecognitionTime() async throws {
    #if COPYLASSO_RUN_OCR_BENCHMARK
      let image = try loadFixture(named: "clean-multiline")
      let recognizer = VisionTextRecognizer()

      for _ in 0..<2 {
        _ = try await recognizer.recognize(image)
      }

      let clock = ContinuousClock()
      var measurements: [Double] = []
      for _ in 0..<11 {
        let start = clock.now
        _ = try await recognizer.recognize(image)
        measurements.append(seconds(from: clock.now - start))
      }

      let sorted = measurements.sorted()
      let median = sorted[sorted.count / 2]
      let minimum = sorted[0]
      let maximum = sorted[sorted.count - 1]
      let summary = String(
        format:
          "OCR benchmark fixture=clean-multiline dimensions=1200x500 iterations=11 median=%.4fs min=%.4fs max=%.4fs",
        median,
        minimum,
        maximum
      )
      print(summary)
      XCTContext.runActivity(named: summary) { _ in }

      if median > 0.500 {
        XCTFail(String(format: "OCR benchmark median %.4fs exceeded 0.5000s", median))
      }
    #else
      throw XCTSkip("Build with COPYLASSO_RUN_OCR_BENCHMARK to run the workstation benchmark")
    #endif
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

  private func makeBlankImage() throws -> CGImage {
    guard
      let context = CGContext(
        data: nil,
        width: 320,
        height: 200,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
    else {
      throw TestError.imageCreationFailed
    }
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: 320, height: 200))
    guard let image = context.makeImage() else {
      throw TestError.imageCreationFailed
    }
    return image
  }

  private func rotateClockwise(_ image: CGImage) throws -> CGImage {
    guard
      let context = CGContext(
        data: nil,
        width: image.height,
        height: image.width,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
    else {
      throw TestError.imageCreationFailed
    }

    context.translateBy(x: CGFloat(image.height), y: 0)
    context.rotate(by: .pi / 2)
    context.draw(
      image,
      in: CGRect(x: 0, y: 0, width: image.width, height: image.height)
    )
    guard let rotated = context.makeImage() else {
      throw TestError.imageCreationFailed
    }
    return rotated
  }

  private func normalizedText(_ observations: [VisionTextObservation]) -> String {
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
    _ observations: [VisionTextObservation],
    fixture: String
  ) {
    for observation in observations {
      if !(0...1).contains(observation.confidence) {
        XCTFail("OCR confidence was outside 0...1 for fixture \(fixture)")
      }

      let box = observation.boundingBox
      if box.minX < 0 || box.minY < 0 || box.maxX > 1 || box.maxY > 1 {
        XCTFail("OCR bounding box was outside normalized coordinates for fixture \(fixture)")
      }
    }
  }

  private func normalizedTokens(_ text: String) -> [String] {
    text.lowercased().split { !$0.isLetter }.map(String.init)
  }

  private func assertExpectedTokensPresent(actual: String, expected: String, fixture: String) {
    let actualTokens = normalizedTokens(actual)
    for token in normalizedTokens(expected) where !actualTokens.contains(token) {
      XCTFail("An expected token was absent from fixture \(fixture)")
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
    if unexpectedCount > maximum {
      XCTFail("Fixture \(fixture) exceeded its unexpected-token limit")
    }
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

  private func seconds(from duration: Duration) -> Double {
    let components = duration.components
    return Double(components.seconds) + (Double(components.attoseconds) / 1_000_000_000_000_000_000)
  }

  private func fixtureQualityPassCount(recognizer: VisionTextRecognizer) async throws -> Int {
    var passCount = 0

    for fixture in exactFixtures {
      let observations = try await recognizer.recognize(try loadFixture(named: fixture.name))
      if normalizedText(observations) == fixture.expectedText {
        passCount += 1
      }
    }

    let lowContrastExpected = "Moderate contrast should preserve these words"
    let lowContrastActual = normalizedText(
      try await recognizer.recognize(try loadFixture(named: "moderate-low-contrast"))
    )
    if characterSimilarity(lowContrastActual, lowContrastExpected) >= 0.90,
      containsExpectedTokens(actual: lowContrastActual, expected: lowContrastExpected),
      unexpectedTokenCount(actual: lowContrastActual, expected: lowContrastExpected) <= 1
    {
      passCount += 1
    }

    let photoExpected = "CEDAR TRAIL"
    let photoActual = normalizedText(
      try await recognizer.recognize(try loadFixture(named: "photo-cedar-trail"))
    )
    if photoActual.contains(photoExpected),
      containsExpectedTokens(actual: photoActual, expected: photoExpected),
      unexpectedTokenCount(actual: photoActual, expected: photoExpected) <= 1
    {
      passCount += 1
    }

    return passCount
  }

  private func containsExpectedTokens(actual: String, expected: String) -> Bool {
    let actualTokens = normalizedTokens(actual)
    return normalizedTokens(expected).allSatisfy(actualTokens.contains)
  }

  private func unexpectedTokenCount(actual: String, expected: String) -> Int {
    let expectedTokens = Set(normalizedTokens(expected))
    return normalizedTokens(actual).filter { !expectedTokens.contains($0) }.count
  }
}
