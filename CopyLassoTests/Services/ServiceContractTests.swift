import CoreGraphics
import XCTest

@testable import CopyLasso

@MainActor
final class ServiceContractTests: XCTestCase {
  func testPermissionStubReturnsConfiguredObservationsAndCountsCalls() {
    let service = StubScreenCapturePermissionService(
      currentResult: .notGrantedNeverRequested,
      requestResult: .granted
    )

    XCTAssertEqual(service.currentObservation(), .notGrantedNeverRequested)
    XCTAssertEqual(service.requestAccess(), .granted)
    XCTAssertEqual(service.currentObservationCallCount, 1)
    XCTAssertEqual(service.requestAccessCallCount, 1)
  }

  func testSelectionStubSeparatesCancellationFromFailure() async throws {
    let service = StubRegionSelectionService(result: .success(.cancelled(.escape)))

    let outcome = try await service.selectRegion()
    XCTAssertEqual(outcome, .cancelled(.escape))
    service.cancelSelection()
    XCTAssertEqual(service.selectRegionCallCount, 1)
    XCTAssertEqual(service.cancelSelectionCallCount, 1)

    service.result = .failure(.injected)
    do {
      _ = try await service.selectRegion()
      XCTFail("Expected selection to throw")
    } catch {
      XCTAssertEqual(error as? TestServiceError, .injected)
    }
  }

  func testCaptureStubReturnsAnInMemoryImageAndRecordsGeometry() async throws {
    let image = Self.makeImage(width: 8, height: 6)
    let selection = try Self.makeSelection()
    let service = StubScreenCaptureService(result: .success(image))

    let result = try await service.capture(selection)

    XCTAssertEqual(result.width, 8)
    XCTAssertEqual(result.height, 6)
    let selections = await service.selections
    XCTAssertEqual(selections, [selection])

    await service.setResult(.failure(.injected))
    do {
      _ = try await service.capture(selection)
      XCTFail("Expected capture to throw")
    } catch {
      XCTAssertEqual(error as? TestServiceError, .injected)
    }
  }

  func testOCRStubReturnsNeutralObservationsAndSupportsFailure() async throws {
    let observations = [
      RecognizedTextObservation(
        text: "fixture",
        confidence: 0.9,
        boundingBox: CGRect(x: 0.1, y: 0.2, width: 0.3, height: 0.4)
      )
    ]
    let service = StubOCRService(result: .success(observations))

    let result = try await service.recognizeText(in: Self.makeImage())
    let recognitionCallCount = await service.recognitionCallCount
    XCTAssertEqual(result, observations)
    XCTAssertEqual(recognitionCallCount, 1)

    await service.setResult(.failure(.injected))
    do {
      _ = try await service.recognizeText(in: Self.makeImage())
      XCTFail("Expected OCR to throw")
    } catch {
      XCTAssertEqual(error as? TestServiceError, .injected)
    }
  }

  func testClipboardSpyRecordsOnlySuccessfulWrites() throws {
    let service = SpyClipboardService()

    try service.writePlainText("known test text")
    XCTAssertEqual(service.writtenTexts, ["known test text"])

    service.error = .injected
    XCTAssertThrowsError(try service.writePlainText("rejected"))
    XCTAssertEqual(service.writtenTexts, ["known test text"])
  }

  func testFeedbackSpyRecordsConfiguredEventsAndSupportsFailure() async throws {
    let service = SpyFeedbackService()

    try await service.present(.success(preview: "known preview"))
    try await service.present(.noText)
    try await service.present(.failure(.recognition))

    XCTAssertEqual(
      service.presentedFeedback,
      [.success(preview: "known preview"), .noText, .failure(.recognition)]
    )

    service.error = .injected
    do {
      try await service.present(.failure(.feedback))
      XCTFail("Expected feedback presentation to throw")
    } catch {
      XCTAssertEqual(error as? TestServiceError, .injected)
    }
    XCTAssertEqual(service.presentedFeedback.count, 3)
  }

  private static func makeSelection() throws -> SelectionResult {
    let geometry = try DisplayGeometry(
      displayID: 1,
      appKitFrame: CGRect(x: 0, y: 0, width: 100, height: 100),
      coreGraphicsBounds: CGRect(x: 0, y: 0, width: 100, height: 100),
      backingScale: 1
    )
    return try XCTUnwrap(
      geometry.selectionResult(from: CGPoint(x: 10, y: 20), to: CGPoint(x: 30, y: 50))
    )
  }

  private static func makeImage(width: Int = 4, height: Int = 3) -> CGImage {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(
      data: nil,
      width: width,
      height: height,
      bitsPerComponent: 8,
      bytesPerRow: 0,
      space: colorSpace,
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    return context.makeImage()!
  }
}

extension StubScreenCaptureService {
  fileprivate func setResult(_ result: Result<CGImage, TestServiceError>) {
    self.result = result
  }
}

extension StubOCRService {
  fileprivate func setResult(_ result: Result<[RecognizedTextObservation], TestServiceError>) {
    self.result = result
  }
}
