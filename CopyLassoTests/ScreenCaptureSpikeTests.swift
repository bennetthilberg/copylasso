import CoreGraphics
import ScreenCaptureKit
import XCTest

@testable import CopyLasso

@MainActor
final class ScreenCaptureSpikeTests: XCTestCase {
  func testPermissionObservationReportsOnlyKnownOrSafelyInferredStates() {
    var history = ScreenCapturePermissionHistory()

    XCTAssertEqual(history.observation(preflightGranted: false), .notGrantedNeverRequested)

    history.hasRequested = true
    XCTAssertEqual(history.observation(preflightGranted: false), .notGrantedAfterRequest)

    history.hasObservedGranted = true
    XCTAssertEqual(history.observation(preflightGranted: false), .notGrantedAfterPreviouslyGranted)
    XCTAssertEqual(history.observation(preflightGranted: true), .granted)
  }

  func testPermissionObservationMessagesDoNotOverstateSystemKnowledge() {
    XCTAssertEqual(
      ScreenCaptureAuthorizationObservation.notGrantedNeverRequested.message,
      "Not granted; CopyLasso has not requested access in this preferences history."
    )
    XCTAssertEqual(
      ScreenCaptureAuthorizationObservation.notGrantedAfterRequest.message,
      "Not granted after a prior request; macOS does not expose whether access is denied or pending."
    )
    XCTAssertEqual(
      ScreenCaptureAuthorizationObservation.notGrantedAfterPreviouslyGranted.message,
      "Not granted after previously observed access; access may have been revoked."
    )
  }

  func testCenteredRegionUsesLogicalPointsAndPixelScale() throws {
    let region = try ScreenCaptureRegionPlanner.centeredRegion(
      displaySize: CGSize(width: 1920, height: 1080),
      pointPixelScale: 2
    )

    XCTAssertEqual(region.sourceRect, CGRect(x: 640, y: 360, width: 640, height: 360))
    XCTAssertEqual(region.pixelWidth, 1280)
    XCTAssertEqual(region.pixelHeight, 720)
  }

  func testCenteredRegionClampsToSmallDisplay() throws {
    let region = try ScreenCaptureRegionPlanner.centeredRegion(
      displaySize: CGSize(width: 320, height: 200),
      pointPixelScale: 1.5
    )

    XCTAssertEqual(region.sourceRect, CGRect(x: 0, y: 0, width: 320, height: 200))
    XCTAssertEqual(region.pixelWidth, 480)
    XCTAssertEqual(region.pixelHeight, 300)
  }

  func testCenteredRegionRejectsInvalidInputs() {
    XCTAssertThrowsError(
      try ScreenCaptureRegionPlanner.centeredRegion(
        displaySize: CGSize(width: 0, height: 1080),
        pointPixelScale: 2
      )
    ) { error in
      XCTAssertEqual(error as? ScreenCaptureSpikeError, .invalidGeometry)
    }

    XCTAssertThrowsError(
      try ScreenCaptureRegionPlanner.centeredRegion(
        displaySize: CGSize(width: 1920, height: 1080),
        pointPixelScale: 0
      )
    ) { error in
      XCTAssertEqual(error as? ScreenCaptureSpikeError, .invalidGeometry)
    }
  }

  func testSystemDeclineErrorMapsToControlledPermissionError() {
    let error = NSError(
      domain: SCStreamErrorDomain,
      code: SCStreamError.Code.userDeclined.rawValue
    )

    XCTAssertEqual(ScreenCaptureSpikeError.from(error), .permissionNotGranted)
  }

  func testUnexpectedFrameworkErrorRetainsDiagnosticCode() {
    let error = NSError(domain: "CopyLassoTests", code: 42)

    XCTAssertEqual(ScreenCaptureSpikeError.from(error), .captureFailed(code: 42))
  }

  func testInitializationPreflightsWithoutRequestingOrCapturing() {
    let history = InMemoryScreenCaptureHistoryStore()
    var requestCount = 0
    var captureCount = 0

    let model = ScreenCaptureSpikeModel(
      permissionClient: ScreenCapturePermissionClient(
        preflight: { false },
        request: {
          requestCount += 1
          return false
        }
      ),
      imageClient: ScreenCaptureImageClient(capture: {
        captureCount += 1
        return Self.makeImage()
      }),
      historyStore: history
    )

    XCTAssertEqual(model.authorizationObservation, .notGrantedNeverRequested)
    XCTAssertEqual(requestCount, 0)
    XCTAssertEqual(captureCount, 0)
    XCTAssertNil(model.previewImage)
  }

  func testDeniedRequestProducesControlledErrorAndDoesNotCapture() async {
    let history = InMemoryScreenCaptureHistoryStore()
    var captureCount = 0
    let model = ScreenCaptureSpikeModel(
      permissionClient: ScreenCapturePermissionClient(
        preflight: { false },
        request: { false }
      ),
      imageClient: ScreenCaptureImageClient(capture: {
        captureCount += 1
        return Self.makeImage()
      }),
      historyStore: history
    )

    await model.requestAndCapture()

    XCTAssertTrue(history.hasRequested)
    XCTAssertEqual(model.authorizationObservation, .notGrantedAfterRequest)
    XCTAssertEqual(model.lastError, .permissionNotGranted)
    XCTAssertEqual(captureCount, 0)
    XCTAssertNil(model.previewImage)
  }

  func testGrantedPreflightCapturesAndRecordsAccess() async {
    let history = InMemoryScreenCaptureHistoryStore()
    var requestCount = 0
    let model = ScreenCaptureSpikeModel(
      permissionClient: ScreenCapturePermissionClient(
        preflight: { true },
        request: {
          requestCount += 1
          return true
        }
      ),
      imageClient: ScreenCaptureImageClient(capture: { Self.makeImage(width: 12, height: 8) }),
      historyStore: history
    )

    await model.requestAndCapture()

    XCTAssertTrue(history.hasObservedGranted)
    XCTAssertEqual(model.authorizationObservation, .granted)
    XCTAssertEqual(requestCount, 0)
    XCTAssertEqual(model.previewImage?.width, 12)
    XCTAssertEqual(model.previewImage?.height, 8)
    XCTAssertNil(model.lastError)
  }

  func testCaptureFailureNeverLeavesAStalePreview() async {
    let history = InMemoryScreenCaptureHistoryStore(hasObservedGranted: true)
    var shouldFail = false
    let model = ScreenCaptureSpikeModel(
      permissionClient: ScreenCapturePermissionClient(
        preflight: { true },
        request: { true }
      ),
      imageClient: ScreenCaptureImageClient(capture: {
        if shouldFail {
          throw ScreenCaptureSpikeError.captureFailed(code: 77)
        }
        return Self.makeImage()
      }),
      historyStore: history
    )

    await model.captureAgain()
    XCTAssertNotNil(model.previewImage)

    shouldFail = true
    await model.captureAgain()

    XCTAssertNil(model.previewImage)
    XCTAssertEqual(model.lastError, .captureFailed(code: 77))
  }

  func testCaptureAgainObservesLikelyRevocationWithoutRequesting() async {
    let history = InMemoryScreenCaptureHistoryStore(hasRequested: true, hasObservedGranted: true)
    var requestCount = 0
    var captureCount = 0
    let model = ScreenCaptureSpikeModel(
      permissionClient: ScreenCapturePermissionClient(
        preflight: { false },
        request: {
          requestCount += 1
          return false
        }
      ),
      imageClient: ScreenCaptureImageClient(capture: {
        captureCount += 1
        return Self.makeImage()
      }),
      historyStore: history
    )

    await model.captureAgain()

    XCTAssertEqual(model.authorizationObservation, .notGrantedAfterPreviouslyGranted)
    XCTAssertEqual(model.lastError, .permissionNotGranted)
    XCTAssertEqual(requestCount, 0)
    XCTAssertEqual(captureCount, 0)
  }

  func testCaptureDenialOverridesStaleGrantedPreflight() async {
    let history = InMemoryScreenCaptureHistoryStore(
      hasRequested: true,
      hasObservedGranted: true
    )
    let model = ScreenCaptureSpikeModel(
      permissionClient: ScreenCapturePermissionClient(
        preflight: { true },
        request: { true }
      ),
      imageClient: ScreenCaptureImageClient(capture: {
        throw ScreenCaptureSpikeError.permissionNotGranted
      }),
      historyStore: history
    )

    await model.captureAgain()

    XCTAssertEqual(model.authorizationObservation, .notGrantedAfterPreviouslyGranted)
    XCTAssertEqual(model.lastError, .permissionNotGranted)
    XCTAssertNil(model.previewImage)
  }

  func testClearPreviewReleasesTheImageAndError() async {
    let history = InMemoryScreenCaptureHistoryStore(hasObservedGranted: true)
    let model = ScreenCaptureSpikeModel(
      permissionClient: ScreenCapturePermissionClient(preflight: { true }, request: { true }),
      imageClient: ScreenCaptureImageClient(capture: { Self.makeImage() }),
      historyStore: history
    )

    await model.captureAgain()
    XCTAssertNotNil(model.previewImage)

    model.clearPreview()

    XCTAssertNil(model.previewImage)
    XCTAssertNil(model.lastError)
  }

  func testResetLocalHistoryPreservesNoPermissionClaim() {
    let history = InMemoryScreenCaptureHistoryStore(hasRequested: true, hasObservedGranted: true)
    let model = ScreenCaptureSpikeModel(
      permissionClient: ScreenCapturePermissionClient(preflight: { false }, request: { false }),
      imageClient: ScreenCaptureImageClient(capture: { Self.makeImage() }),
      historyStore: history
    )

    model.resetLocalHistory()

    XCTAssertFalse(history.hasRequested)
    XCTAssertFalse(history.hasObservedGranted)
    XCTAssertEqual(model.authorizationObservation, .notGrantedNeverRequested)
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

@MainActor
private final class InMemoryScreenCaptureHistoryStore: ScreenCaptureHistoryStoring {
  var hasRequested: Bool
  var hasObservedGranted: Bool

  init(hasRequested: Bool = false, hasObservedGranted: Bool = false) {
    self.hasRequested = hasRequested
    self.hasObservedGranted = hasObservedGranted
  }

  func reset() {
    hasRequested = false
    hasObservedGranted = false
  }
}
