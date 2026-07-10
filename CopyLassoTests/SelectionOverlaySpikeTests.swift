import CoreGraphics
import XCTest

@testable import CopyLasso

final class SelectionOverlaySpikeTests: XCTestCase {
  func testForwardAndReverseDragsProduceTheSameSelection() throws {
    let display = try makeDisplay()

    let forward = try XCTUnwrap(
      display.selectionResult(
        from: CGPoint(x: 10, y: 20),
        to: CGPoint(x: 50, y: 70)
      )
    )
    let reverse = try XCTUnwrap(
      display.selectionResult(
        from: CGPoint(x: 50, y: 70),
        to: CGPoint(x: 10, y: 20)
      )
    )

    XCTAssertEqual(forward, reverse)
    XCTAssertEqual(forward.appKitGlobalRect, CGRect(x: 10, y: 20, width: 40, height: 50))
    XCTAssertEqual(forward.displayLocalRect, CGRect(x: 10, y: 20, width: 40, height: 50))
    XCTAssertEqual(
      forward.coreGraphicsDisplayLocalRect,
      CGRect(x: 10, y: 30, width: 40, height: 50)
    )
  }

  func testEndpointsClampToEveryDisplayEdge() throws {
    let display = try makeDisplay()
    let cases: [(CGPoint, CGRect)] = [
      (CGPoint(x: -20, y: 60), CGRect(x: 0, y: 50, width: 50, height: 10)),
      (CGPoint(x: 120, y: 60), CGRect(x: 50, y: 50, width: 50, height: 10)),
      (CGPoint(x: 60, y: -20), CGRect(x: 50, y: 0, width: 10, height: 50)),
      (CGPoint(x: 60, y: 120), CGRect(x: 50, y: 50, width: 10, height: 50)),
    ]

    for (endpoint, expected) in cases {
      let result = try XCTUnwrap(
        display.selectionResult(from: CGPoint(x: 50, y: 50), to: endpoint)
      )
      XCTAssertEqual(result.appKitGlobalRect, expected)
    }
  }

  func testCrossDisplayEndpointClampsToInitiatingDisplay() throws {
    let display = try makeDisplay(
      appKitFrame: CGRect(x: -100, y: 25, width: 100, height: 100),
      coreGraphicsBounds: CGRect(x: -100, y: 0, width: 100, height: 100)
    )

    let result = try XCTUnwrap(
      display.selectionResult(from: CGPoint(x: -50, y: 75), to: CGPoint(x: 500, y: 500))
    )

    XCTAssertEqual(result.appKitGlobalRect, CGRect(x: -50, y: 75, width: 50, height: 50))
    XCTAssertEqual(result.displayLocalRect, CGRect(x: 50, y: 50, width: 50, height: 50))
  }

  func testNegativeCoordinateDisplayUsesItsOwnCoreGraphicsOrigin() throws {
    let display = try makeDisplay(
      id: 42,
      appKitFrame: CGRect(x: -200, y: -50, width: 200, height: 100),
      coreGraphicsBounds: CGRect(x: -200, y: 30, width: 200, height: 100)
    )

    let result = try XCTUnwrap(
      display.selectionResult(from: CGPoint(x: -180, y: -40), to: CGPoint(x: -100, y: 20))
    )

    XCTAssertEqual(result.displayID, 42)
    XCTAssertEqual(result.displayLocalRect, CGRect(x: 20, y: 10, width: 80, height: 60))
    XCTAssertEqual(
      result.coreGraphicsDisplayLocalRect,
      CGRect(x: 20, y: 30, width: 80, height: 60)
    )
    XCTAssertEqual(
      result.coreGraphicsGlobalRect,
      CGRect(x: -180, y: 60, width: 80, height: 60)
    )
  }

  func testYFlipIsDisplayLocalForDisplaysAboveBelowAndBesidePrimary() throws {
    let frames = [
      (
        CGRect(x: 0, y: 100, width: 100, height: 100),
        CGRect(x: 0, y: -100, width: 100, height: 100)
      ),
      (
        CGRect(x: 0, y: -100, width: 100, height: 100),
        CGRect(x: 0, y: 100, width: 100, height: 100)
      ),
      (
        CGRect(x: -100, y: 0, width: 100, height: 100),
        CGRect(x: -100, y: 0, width: 100, height: 100)
      ),
    ]

    for (appKitFrame, coreGraphicsBounds) in frames {
      let display = try makeDisplay(
        appKitFrame: appKitFrame,
        coreGraphicsBounds: coreGraphicsBounds
      )
      let result = try XCTUnwrap(
        display.selectionResult(
          from: CGPoint(x: appKitFrame.minX + 10, y: appKitFrame.minY + 20),
          to: CGPoint(x: appKitFrame.minX + 30, y: appKitFrame.minY + 50)
        )
      )

      XCTAssertEqual(
        result.coreGraphicsDisplayLocalRect,
        CGRect(x: 10, y: 50, width: 20, height: 30)
      )
      XCTAssertEqual(
        result.coreGraphicsGlobalRect,
        CGRect(
          x: coreGraphicsBounds.minX + 10,
          y: coreGraphicsBounds.minY + 50,
          width: 20,
          height: 30
        )
      )
    }
  }

  func testBackingPixelConversionSupportsOneOnePointFiveAndTwoX() throws {
    let appKitRect = CGRect(x: 10.2, y: 40.6, width: 20.2, height: 39.2)
    let expected: [(CGFloat, CGRect)] = [
      (1, CGRect(x: 10, y: 20, width: 21, height: 40)),
      (1.5, CGRect(x: 15, y: 30, width: 31, height: 60)),
      (2, CGRect(x: 20, y: 40, width: 41, height: 79)),
    ]

    for (scale, expectedPixels) in expected {
      let display = try makeDisplay(scale: scale)
      let result = try XCTUnwrap(
        display.selectionResult(
          from: appKitRect.origin,
          to: CGPoint(x: appKitRect.maxX, y: appKitRect.maxY)
        )
      )
      XCTAssertEqual(result.backingPixelRect, expectedPixels)
    }
  }

  func testSidecarStyleGeometryDoesNotDependOnRuntimeDisplayID() throws {
    let display = try makeDisplay(
      id: 9_999,
      appKitFrame: CGRect(x: -1298, y: 126, width: 1298, height: 954),
      coreGraphicsBounds: CGRect(x: -1298, y: 0, width: 1298, height: 954),
      scale: 2
    )

    let result = try XCTUnwrap(
      display.selectionResult(from: CGPoint(x: -1200, y: 200), to: CGPoint(x: -1000, y: 400))
    )

    XCTAssertEqual(result.displayID, 9_999)
    XCTAssertEqual(result.displayLocalRect, CGRect(x: 98, y: 74, width: 200, height: 200))
    XCTAssertEqual(
      result.coreGraphicsDisplayLocalRect,
      CGRect(x: 98, y: 680, width: 200, height: 200)
    )
    XCTAssertEqual(
      result.coreGraphicsGlobalRect,
      CGRect(x: -1200, y: 680, width: 200, height: 200)
    )
    XCTAssertEqual(result.backingPixelRect, CGRect(x: 196, y: 1360, width: 400, height: 400))
  }

  func testExactlyFourPointsIsAcceptedAndSmallerDimensionCancels() throws {
    let display = try makeDisplay()

    XCTAssertNotNil(
      try display.selectionResult(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 14, y: 14))
    )
    XCTAssertNil(
      try display.selectionResult(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 13.999, y: 20))
    )
    XCTAssertNil(
      try display.selectionResult(from: CGPoint(x: 10, y: 10), to: CGPoint(x: 20, y: 13.999))
    )
  }

  func testInvalidDisplayGeometryIsRejected() {
    let invalidFrames = [
      CGRect(x: 0, y: 0, width: 0, height: 100),
      CGRect(x: 0, y: 0, width: 100, height: -1),
      CGRect(x: CGFloat.infinity, y: 0, width: 100, height: 100),
    ]

    for frame in invalidFrames {
      XCTAssertThrowsError(
        try makeDisplay(appKitFrame: frame)
      )
      XCTAssertThrowsError(
        try makeDisplay(coreGraphicsBounds: frame)
      )
    }
    XCTAssertThrowsError(try makeDisplay(scale: 0))
    XCTAssertThrowsError(try makeDisplay(scale: -1))
    XCTAssertThrowsError(try makeDisplay(scale: .infinity))
  }

  func testSessionCompletesAValidSelectionExactlyOnce() throws {
    let display = try makeDisplay()
    var outcomes: [SelectionOutcome] = []
    let session = SelectionSession(displays: [display]) { outcomes.append($0) }

    XCTAssertTrue(session.begin(on: display.displayID, at: CGPoint(x: 10, y: 10)))
    session.update(to: CGPoint(x: 30, y: 40))
    session.finish(at: CGPoint(x: 50, y: 60))
    session.cancel(.escape)
    session.finish(at: CGPoint(x: 80, y: 80))

    XCTAssertEqual(outcomes.count, 1)
    guard case .selected(let result) = outcomes[0] else {
      return XCTFail("Expected a selection")
    }
    XCTAssertEqual(result.appKitGlobalRect, CGRect(x: 10, y: 10, width: 40, height: 50))
  }

  func testSessionReportsTooSmallAsCancellation() throws {
    let display = try makeDisplay()
    var outcome: SelectionOutcome?
    let session = SelectionSession(displays: [display]) { outcome = $0 }

    XCTAssertTrue(session.begin(on: display.displayID, at: CGPoint(x: 10, y: 10)))
    session.finish(at: CGPoint(x: 12, y: 40))

    XCTAssertEqual(outcome, .cancelled(.tooSmall))
  }

  func testEscapeBeforeAndDuringDragCancels() throws {
    let display = try makeDisplay()

    for beginDrag in [false, true] {
      var outcome: SelectionOutcome?
      let session = SelectionSession(displays: [display]) { outcome = $0 }
      if beginDrag {
        XCTAssertTrue(session.begin(on: display.displayID, at: CGPoint(x: 10, y: 10)))
        session.update(to: CGPoint(x: 30, y: 40))
      }
      session.cancel(.escape)
      XCTAssertEqual(outcome, .cancelled(.escape))
    }
  }

  func testDisplayChangeAndApplicationTerminationCancelExactlyOnce() throws {
    let display = try makeDisplay()

    for reason in [SelectionCancellationReason.displayChanged, .applicationTerminated] {
      var outcomes: [SelectionOutcome] = []
      let session = SelectionSession(displays: [display]) { outcomes.append($0) }
      XCTAssertTrue(session.begin(on: display.displayID, at: CGPoint(x: 10, y: 10)))
      session.cancel(reason)
      session.cancel(reason)
      XCTAssertEqual(outcomes, [.cancelled(reason)])
    }
  }

  func testSessionRejectsUnknownDisplayAndTracksClampedDragRect() throws {
    let display = try makeDisplay()
    let session = SelectionSession(displays: [display]) { _ in }

    XCTAssertFalse(session.begin(on: 999, at: .zero))
    XCTAssertTrue(session.begin(on: display.displayID, at: CGPoint(x: 40, y: 40)))
    session.update(to: CGPoint(x: 200, y: -100))
    XCTAssertEqual(session.currentAppKitRect, CGRect(x: 40, y: 0, width: 60, height: 40))
  }

  private func makeDisplay(
    id: CGDirectDisplayID = 1,
    appKitFrame: CGRect = CGRect(x: 0, y: 0, width: 100, height: 100),
    coreGraphicsBounds: CGRect = CGRect(x: 0, y: 0, width: 100, height: 100),
    scale: CGFloat = 1
  ) throws -> DisplayGeometry {
    try DisplayGeometry(
      displayID: id,
      appKitFrame: appKitFrame,
      coreGraphicsBounds: coreGraphicsBounds,
      backingScale: scale
    )
  }
}
