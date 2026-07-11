import CoreGraphics
import Foundation
import ScreenCaptureKit
import XCTest

@testable import CopyLasso

final class SystemScreenCaptureServiceTests: XCTestCase {
  func testRequestUsesOutwardRoundedBackingPixelsAndDisablesCursorAndAudio() throws {
    let display = try DisplayGeometry(
      displayID: 44,
      appKitFrame: CGRect(x: 0, y: 0, width: 100, height: 80),
      coreGraphicsBounds: CGRect(x: 0, y: 0, width: 100, height: 80),
      backingScale: 2
    )
    let selection = try XCTUnwrap(
      display.selectionResult(
        from: CGPoint(x: 10.25, y: 20.25),
        to: CGPoint(x: 30.60, y: 40.90)
      )
    )

    let request = try ScreenCaptureRequestPlanner.request(for: selection)

    XCTAssertEqual(request.displayID, 44)
    XCTAssertEqual(request.expectedDisplayPointSize, CGSize(width: 100, height: 80))
    XCTAssertEqual(request.sourceRect, CGRect(x: 10, y: 39, width: 21, height: 21))
    XCTAssertEqual(request.pixelWidth, 42)
    XCTAssertEqual(request.pixelHeight, 42)
    XCTAssertEqual(request.backingScale, 2)
    XCTAssertFalse(request.showsCursor)
    XCTAssertFalse(request.capturesAudio)
  }

  func testRequestRejectsInvalidScaleAndInconsistentPixelGeometry() throws {
    let selection = try makeSelection()
    let invalidScale = SelectionResult(
      displayID: selection.displayID,
      displayPointSize: selection.displayPointSize,
      appKitGlobalRect: selection.appKitGlobalRect,
      displayLocalRect: selection.displayLocalRect,
      coreGraphicsGlobalRect: selection.coreGraphicsGlobalRect,
      coreGraphicsDisplayLocalRect: selection.coreGraphicsDisplayLocalRect,
      backingPixelRect: selection.backingPixelRect,
      backingScale: 0
    )
    let inconsistentPixels = SelectionResult(
      displayID: selection.displayID,
      displayPointSize: selection.displayPointSize,
      appKitGlobalRect: selection.appKitGlobalRect,
      displayLocalRect: selection.displayLocalRect,
      coreGraphicsGlobalRect: selection.coreGraphicsGlobalRect,
      coreGraphicsDisplayLocalRect: selection.coreGraphicsDisplayLocalRect,
      backingPixelRect: selection.backingPixelRect.offsetBy(dx: 1, dy: 0),
      backingScale: selection.backingScale
    )

    for invalid in [invalidScale, inconsistentPixels] {
      XCTAssertThrowsError(try ScreenCaptureRequestPlanner.request(for: invalid)) { error in
        XCTAssertEqual(error as? ScreenCaptureError, .invalidSelection)
      }
    }
  }

  func testDisplayValidationAcceptsMatchingGeometryAndRejectsChanges() throws {
    let request = try ScreenCaptureRequestPlanner.request(for: makeSelection(scale: 2))
    let matching = ScreenCaptureDisplaySnapshot(
      displayID: request.displayID,
      pointSize: CGSize(width: 100, height: 80),
      pointPixelScale: 2
    )

    XCTAssertNoThrow(try ScreenCaptureRequestValidator.validate(request, against: matching))

    let cases = [
      ScreenCaptureDisplaySnapshot(
        displayID: request.displayID + 1,
        pointSize: matching.pointSize,
        pointPixelScale: matching.pointPixelScale
      ),
      ScreenCaptureDisplaySnapshot(
        displayID: request.displayID,
        pointSize: matching.pointSize,
        pointPixelScale: 1
      ),
      ScreenCaptureDisplaySnapshot(
        displayID: request.displayID,
        pointSize: CGSize(width: 5, height: 5),
        pointPixelScale: matching.pointPixelScale
      ),
    ]

    for changed in cases {
      XCTAssertThrowsError(
        try ScreenCaptureRequestValidator.validate(request, against: changed)
      ) { error in
        XCTAssertEqual(error as? ScreenCaptureError, .displayConfigurationChanged)
      }
    }
  }

  func testDisplayValidationRejectsPixelDimensionsThatDoNotMatchSourceGeometry() throws {
    let request = try ScreenCaptureRequestPlanner.request(for: makeSelection(scale: 1.5))
    let snapshot = ScreenCaptureDisplaySnapshot(
      displayID: request.displayID,
      pointSize: CGSize(width: 200, height: 100),
      pointPixelScale: request.backingScale
    )
    let changedWidth = ScreenCaptureRequest(
      displayID: request.displayID,
      expectedDisplayPointSize: request.expectedDisplayPointSize,
      sourceRect: request.sourceRect,
      pixelWidth: request.pixelWidth + 1,
      pixelHeight: request.pixelHeight,
      backingScale: request.backingScale,
      showsCursor: request.showsCursor,
      capturesAudio: request.capturesAudio
    )
    let changedHeight = ScreenCaptureRequest(
      displayID: request.displayID,
      expectedDisplayPointSize: request.expectedDisplayPointSize,
      sourceRect: request.sourceRect,
      pixelWidth: request.pixelWidth,
      pixelHeight: request.pixelHeight - 1,
      backingScale: request.backingScale,
      showsCursor: request.showsCursor,
      capturesAudio: request.capturesAudio
    )

    XCTAssertThrowsError(
      try ScreenCaptureRequestValidator.validate(changedWidth, against: snapshot))
    XCTAssertThrowsError(
      try ScreenCaptureRequestValidator.validate(changedHeight, against: snapshot))
  }

  func testFractionalScaleEdgeSelectionClampsTheSourceRectAndRemainsValid() throws {
    let display = try DisplayGeometry(
      displayID: 81,
      appKitFrame: CGRect(x: 0, y: 0, width: 101, height: 81),
      coreGraphicsBounds: CGRect(x: 0, y: 0, width: 101, height: 81),
      backingScale: 1.5
    )
    let selection = try XCTUnwrap(
      display.selectionResult(
        from: CGPoint(x: 90.2, y: 0),
        to: CGPoint(x: 101, y: 10.2)
      )
    )

    let request = try ScreenCaptureRequestPlanner.request(for: selection)
    let snapshot = ScreenCaptureDisplaySnapshot(
      displayID: request.displayID,
      pointSize: selection.displayPointSize,
      pointPixelScale: selection.backingScale
    )

    XCTAssertEqual(request.sourceRect.maxX, 101, accuracy: 0.000_1)
    XCTAssertEqual(request.sourceRect.maxY, 81, accuracy: 0.000_1)
    XCTAssertEqual(request.pixelWidth, 17)
    XCTAssertEqual(request.pixelHeight, 16)
    XCTAssertNoThrow(try ScreenCaptureRequestValidator.validate(request, against: snapshot))
  }

  func testDisplayValidationRejectsAChangedSizeEvenWhenTheSelectionStillFits() throws {
    let request = try ScreenCaptureRequestPlanner.request(for: makeSelection())
    let resizedDisplay = ScreenCaptureDisplaySnapshot(
      displayID: request.displayID,
      pointSize: CGSize(width: 90, height: 70),
      pointPixelScale: request.backingScale
    )

    XCTAssertLessThan(request.sourceRect.maxX, resizedDisplay.pointSize.width)
    XCTAssertLessThan(request.sourceRect.maxY, resizedDisplay.pointSize.height)
    XCTAssertThrowsError(
      try ScreenCaptureRequestValidator.validate(request, against: resizedDisplay)
    ) { error in
      XCTAssertEqual(error as? ScreenCaptureError, .displayConfigurationChanged)
    }
  }

  func testCaptureReturnsExactInMemoryImageAndForwardsRequestOnce() async throws {
    let selection = try makeSelection()
    let image = try makeImage(width: 8, height: 6)
    let recorder = CaptureRequestRecorder()
    let service = SystemScreenCaptureService(
      client: ScreenCaptureKitClient { request in
        await recorder.record(request)
        return image
      }
    )

    let returned = try await service.capture(selection)

    let requests = await recorder.requests
    XCTAssertEqual(requests, [try ScreenCaptureRequestPlanner.request(for: selection)])
    XCTAssertEqual(returned.width, 8)
    XCTAssertEqual(returned.height, 6)
    XCTAssertEqual(try pixelData(returned), try pixelData(image))
  }

  func testCaptureRejectsEmptyAndUnexpectedImageOutput() async throws {
    let selection = try makeSelection()
    let cases: [(CGImage?, ScreenCaptureError)] = [
      (nil, .emptyOutput),
      (
        try makeImage(width: 4, height: 4),
        .unexpectedImageDimensions(
          expectedWidth: 8,
          expectedHeight: 6,
          actualWidth: 4,
          actualHeight: 4
        )
      ),
    ]

    for (image, expectedError) in cases {
      let service = SystemScreenCaptureService(
        client: ScreenCaptureKitClient { _ in image }
      )
      do {
        _ = try await service.capture(selection)
        XCTFail("Expected invalid output rejection")
      } catch {
        XCTAssertEqual(error as? ScreenCaptureError, expectedError)
      }
    }
  }

  func testFrameworkErrorsMapToTypedCaptureFailures() async throws {
    let selection = try makeSelection()
    let cases: [(NSError, ScreenCaptureError)] = [
      (
        NSError(
          domain: SCStreamErrorDomain,
          code: SCStreamError.Code.userDeclined.rawValue
        ),
        .permissionDenied
      ),
      (
        NSError(
          domain: SCStreamErrorDomain,
          code: SCStreamError.Code.noDisplayList.rawValue
        ),
        .displayUnavailable
      ),
      (
        NSError(
          domain: SCStreamErrorDomain,
          code: SCStreamError.Code.noCaptureSource.rawValue
        ),
        .displayUnavailable
      ),
      (NSError(domain: "CopyLassoTests", code: 73), .frameworkFailure(code: 73)),
    ]

    for (injectedError, expectedError) in cases {
      let service = SystemScreenCaptureService(
        client: ScreenCaptureKitClient { _ in throw injectedError }
      )
      do {
        _ = try await service.capture(selection)
        XCTFail("Expected framework failure")
      } catch {
        XCTAssertEqual(error as? ScreenCaptureError, expectedError)
      }
    }
  }

  private func makeSelection(scale: CGFloat = 1) throws -> SelectionResult {
    let display = try DisplayGeometry(
      displayID: 7,
      appKitFrame: CGRect(x: 0, y: 0, width: 100, height: 80),
      coreGraphicsBounds: CGRect(x: 0, y: 0, width: 100, height: 80),
      backingScale: scale
    )
    return try XCTUnwrap(
      display.selectionResult(
        from: CGPoint(x: 10, y: 20),
        to: CGPoint(x: 18, y: 26)
      )
    )
  }

  private func makeImage(width: Int, height: Int) throws -> CGImage {
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
      throw TestServiceError.injected
    }
    context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    guard let image = context.makeImage() else {
      throw TestServiceError.injected
    }
    return image
  }

  private func pixelData(_ image: CGImage) throws -> Data {
    guard let data = image.dataProvider?.data else {
      throw TestServiceError.injected
    }
    return data as Data
  }
}

private actor CaptureRequestRecorder {
  private(set) var requests: [ScreenCaptureRequest] = []

  func record(_ request: ScreenCaptureRequest) {
    requests.append(request)
  }
}
