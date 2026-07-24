import CoreGraphics
import Foundation
import ImageIO
import Vision
import XCTest

@testable import CopyLasso

@MainActor
final class VisionBarcodeServiceTests: XCTestCase {
  private enum TestError: Error {
    case missingFixture(String)
    case imageCreationFailed
    case injected
  }

  private struct Fixture {
    let name: String
    let payload: String
    let symbology: CodeSymbology
  }

  private let fixtures = [
    Fixture(
      name: "code-qr",
      payload: "https://copylasso.com/g38?mode=qr",
      symbology: .qr
    ),
    Fixture(
      name: "code-code128",
      payload: "COPYLASSO-CODE128",
      symbology: .code128
    ),
    Fixture(
      name: "code-data-matrix",
      payload: "DM",
      symbology: .dataMatrix
    ),
    Fixture(
      name: "code-pdf417",
      payload: "COPYLASSO PDF417",
      symbology: .pdf417
    ),
    Fixture(
      name: "code-aztec",
      payload: "COPYLASSO AZTEC",
      symbology: .aztec
    ),
  ]

  func testDefaultConfigurationPinsRevisionAndFiveApprovedSymbologies() async throws {
    let expected = [
      RecognizedCodeObservation(
        payload: "payload",
        symbology: .qr,
        confidence: 0.9,
        boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.3)
      )
    ]
    let probe = BarcodePerformerProbe(observations: expected)
    let service = VisionBarcodeService(performer: probe.perform)

    let observations = try await service.recognizeCodes(in: makeBlankImage())

    XCTAssertEqual(probe.configurations, [.copyLasso])
    XCTAssertEqual(probe.imageSizes, [CGSize(width: 320, height: 200)])
    XCTAssertEqual(observations, expected)
  }

  func testPinnedRevisionSupportsExactlyTheApprovedRuntimeSymbologies() throws {
    let request = VNDetectBarcodesRequest()
    request.revision = VNDetectBarcodesRequestRevision3
    let supported = Set(try request.supportedSymbologies())

    XCTAssertTrue(
      Set(VisionBarcodeConfiguration.copyLasso.visionSymbologies).isSubset(of: supported)
    )
    XCTAssertEqual(
      VisionBarcodeConfiguration.copyLasso.symbologies,
      [.qr, .code128, .dataMatrix, .pdf417, .aztec]
    )
  }

  func testPerformerExecutesAwayFromMainThread() async throws {
    let probe = BarcodePerformerProbe(observations: [])

    _ = try await VisionBarcodeService(performer: probe.perform).recognizeCodes(
      in: makeBlankImage()
    )

    XCTAssertEqual(probe.mainThreadObservations, [false])
  }

  func testCanonicalFixturesRecognizeExactPayloadAndNeutralGeometry() async throws {
    let service = VisionBarcodeService()

    for fixture in fixtures {
      let observations = try await service.recognizeCodes(in: loadFixture(named: fixture.name))
      XCTAssertEqual(observations.count, 1, "Fixture: \(fixture.name)")
      XCTAssertEqual(observations.first?.payload, fixture.payload, "Fixture: \(fixture.name)")
      XCTAssertEqual(observations.first?.symbology, fixture.symbology, "Fixture: \(fixture.name)")
      assertObservationGeometry(observations, fixture: fixture.name)
    }
  }

  func testEveryFixtureRecognizesAtRightAngleRotations() async throws {
    let service = VisionBarcodeService()

    for fixture in fixtures {
      let image = try loadFixture(named: fixture.name)
      for quarterTurns in 1...3 {
        let rotated = try rotate(image, quarterTurns: quarterTurns)
        let observations = try await service.recognizeCodes(in: rotated)
        XCTAssertEqual(observations.map(\.payload), [fixture.payload], "Fixture: \(fixture.name)")
      }
    }
  }

  func testEveryFixtureRecognizesAtReducedScaleAndContrast() async throws {
    let service = VisionBarcodeService()

    for fixture in fixtures {
      let image = try loadFixture(named: fixture.name)
      let transformed = try reducedScaleAndContrast(image)
      let observations = try await service.recognizeCodes(in: transformed)
      XCTAssertEqual(observations.map(\.payload), [fixture.payload], "Fixture: \(fixture.name)")
    }
  }

  func testCorrectableAndUncorrectableDamageRemainDistinct() async throws {
    let service = VisionBarcodeService()
    let source = try loadFixture(named: "code-qr")
    let correctable = try obscured(
      source,
      rect: CGRect(x: 290, y: 290, width: 36, height: 36)
    )
    let uncorrectable = try obscured(
      source,
      rect: CGRect(x: 120, y: 120, width: 400, height: 400)
    )

    let correctablePayloads = try await service.recognizeCodes(in: correctable).map(\.payload)
    let uncorrectableObservations = try await service.recognizeCodes(in: uncorrectable)
    XCTAssertEqual(correctablePayloads, ["https://copylasso.com/g38?mode=qr"])
    XCTAssertEqual(uncorrectableObservations, [])
  }

  func testMultipleAndDuplicateCodeCompositionsReturnIndependentObservations() async throws {
    let service = VisionBarcodeService()
    let qr = try loadFixture(named: "code-qr")
    let dataMatrix = try loadFixture(named: "code-data-matrix")

    let distinct = try sideBySide(qr, dataMatrix)
    let distinctPayloads = Set(
      try await service.recognizeCodes(in: distinct).compactMap(\.payload)
    )
    XCTAssertEqual(distinctPayloads, ["https://copylasso.com/g38?mode=qr", "DM"])

    let duplicates = try sideBySide(qr, qr)
    let duplicatePayloads = try await service.recognizeCodes(in: duplicates).compactMap(\.payload)
    XCTAssertEqual(
      duplicatePayloads,
      ["https://copylasso.com/g38?mode=qr", "https://copylasso.com/g38?mode=qr"]
    )
  }

  func testBlankImageReturnsEmptySuccessDistinctFromFailure() async throws {
    let observations = try await VisionBarcodeService().recognizeCodes(in: makeBlankImage())

    XCTAssertEqual(observations, [])
  }

  func testUnexpectedEngineFailureMapsToTypedRecognitionFailure() async throws {
    let service = VisionBarcodeService { _, _, _ in throw TestError.injected }

    do {
      _ = try await service.recognizeCodes(in: makeBlankImage())
      XCTFail("Expected recognition to fail")
    } catch {
      XCTAssertEqual(error as? VisionBarcodeError, .recognitionFailed)
    }
  }

  func testCancellationReturnsPromptlyAndReleasesTheInputImage() async throws {
    let performer = HoldingBarcodePerformer()
    let service = VisionBarcodeService(performer: performer.perform)
    var image: CGImage? = try makeBlankImage(width: 4_000, height: 2_000)
    let weakImage = WeakBarcodeImageReference(try XCTUnwrap(image))
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
      XCTAssertEqual(error as? VisionBarcodeError, .cancelled)
    }
    XCTAssertLessThan(seconds(from: clock.now - start), 1)
    await waitUntil { weakImage.image == nil }
    XCTAssertNil(weakImage.image)
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

  private func rotate(_ image: CGImage, quarterTurns: Int) throws -> CGImage {
    let normalizedTurns = quarterTurns % 4
    let swapsDimensions = normalizedTurns % 2 == 1
    let width = swapsDimensions ? image.height : image.width
    let height = swapsDimensions ? image.width : image.height
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
    context.translateBy(x: CGFloat(width) / 2, y: CGFloat(height) / 2)
    context.rotate(by: CGFloat(normalizedTurns) * .pi / 2)
    context.draw(
      image,
      in: CGRect(
        x: -CGFloat(image.width) / 2,
        y: -CGFloat(image.height) / 2,
        width: CGFloat(image.width),
        height: CGFloat(image.height)
      )
    )
    guard let rotated = context.makeImage() else {
      throw TestError.imageCreationFailed
    }
    return rotated
  }

  private func reducedScaleAndContrast(_ image: CGImage) throws -> CGImage {
    let width = max(160, image.width / 2)
    let height = max(120, image.height / 2)
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
    context.setFillColor(CGColor(gray: 0.82, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.setAlpha(0.65)
    context.interpolationQuality = .none
    context.draw(image, in: CGRect(x: 20, y: 20, width: width - 40, height: height - 40))
    guard let transformed = context.makeImage() else {
      throw TestError.imageCreationFailed
    }
    return transformed
  }

  private func obscured(_ image: CGImage, rect: CGRect) throws -> CGImage {
    guard
      let context = CGContext(
        data: nil,
        width: image.width,
        height: image.height,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
    else {
      throw TestError.imageCreationFailed
    }
    context.draw(
      image,
      in: CGRect(x: 0, y: 0, width: CGFloat(image.width), height: CGFloat(image.height))
    )
    context.setFillColor(CGColor(gray: 1, alpha: 1))
    context.fill(rect)
    guard let damaged = context.makeImage() else {
      throw TestError.imageCreationFailed
    }
    return damaged
  }

  private func sideBySide(_ lhs: CGImage, _ rhs: CGImage) throws -> CGImage {
    let gap = 80
    let width = lhs.width + rhs.width + gap
    let height = max(lhs.height, rhs.height)
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
    context.fill(CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
    context.draw(
      lhs,
      in: CGRect(x: 0, y: 0, width: CGFloat(lhs.width), height: CGFloat(lhs.height))
    )
    context.draw(
      rhs,
      in: CGRect(
        x: CGFloat(lhs.width + gap),
        y: 0,
        width: CGFloat(rhs.width),
        height: CGFloat(rhs.height)
      )
    )
    guard let composition = context.makeImage() else {
      throw TestError.imageCreationFailed
    }
    return composition
  }

  private func assertObservationGeometry(
    _ observations: [RecognizedCodeObservation],
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

  private func startRecognition(
    service: VisionBarcodeService,
    image: CGImage
  ) -> Task<[RecognizedCodeObservation], Error> {
    Task {
      try await service.recognizeCodes(in: image)
    }
  }

  private func seconds(from duration: Duration) -> Double {
    let components = duration.components
    return Double(components.seconds)
      + (Double(components.attoseconds) / 1_000_000_000_000_000_000)
  }
}

private final class BarcodePerformerProbe: @unchecked Sendable {
  let observations: [RecognizedCodeObservation]
  private let lock = NSLock()
  private var storedConfigurations: [VisionBarcodeConfiguration] = []
  private var storedImageSizes: [CGSize] = []
  private var storedMainThreadObservations: [Bool] = []

  init(observations: [RecognizedCodeObservation]) {
    self.observations = observations
  }

  var configurations: [VisionBarcodeConfiguration] {
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
    _ configuration: VisionBarcodeConfiguration,
    _ cancellation: VisionBarcodeCancellation
  ) throws -> [RecognizedCodeObservation] {
    lock.withLock {
      storedConfigurations.append(configuration)
      storedImageSizes.append(CGSize(width: image.width, height: image.height))
      storedMainThreadObservations.append(Thread.isMainThread)
    }
    return observations
  }
}

private final class HoldingBarcodePerformer: @unchecked Sendable {
  private let lock = NSLock()
  private var started = false

  var hasStarted: Bool {
    lock.withLock { started }
  }

  func perform(
    _ image: CGImage,
    _ configuration: VisionBarcodeConfiguration,
    _ cancellation: VisionBarcodeCancellation
  ) throws -> [RecognizedCodeObservation] {
    lock.withLock { started = true }
    while !cancellation.isCancelled {
      Thread.sleep(forTimeInterval: 0.001)
    }
    throw VisionBarcodeError.cancelled
  }
}

private final class WeakBarcodeImageReference {
  weak var image: CGImage?

  init(_ image: CGImage) {
    self.image = image
  }
}
