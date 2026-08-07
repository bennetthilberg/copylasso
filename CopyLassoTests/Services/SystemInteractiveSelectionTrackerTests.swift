import CoreGraphics
import XCTest

@testable import CopyLasso

final class SystemInteractiveSelectionTrackerTests: XCTestCase {
  func testReleasedDragProducesDisplayClampedSelectionGeometry() throws {
    let display = try makeDisplay()
    var tracker = SystemInteractiveSelectionTracker(
      displays: [display]
    )

    XCTAssertNil(
      tracker.observe(
        .pressed(at: CGPoint(x: 120, y: 140))
      )
    )
    XCTAssertNil(
      tracker.observe(
        .dragged(at: CGPoint(x: 1_200, y: 240))
      )
    )
    let outcome = tracker.observe(
      .released(at: CGPoint(x: 2_500, y: 360))
    )

    guard case .selected(let selection) = outcome else {
      return XCTFail("Expected a completed selection")
    }
    XCTAssertEqual(selection.displayID, display.displayID)
    XCTAssertEqual(
      selection.coreGraphicsGlobalRect, CGRect(x: 120, y: 140, width: 1_800, height: 220))
    XCTAssertEqual(selection.backingPixelRect, CGRect(x: 120, y: 140, width: 1_800, height: 220))
  }

  func testStrayReleaseBeforePressDoesNotStartSelection() throws {
    let display = try makeDisplay()
    var tracker = SystemInteractiveSelectionTracker(
      displays: [display]
    )

    XCTAssertNil(
      tracker.observe(
        .released(at: CGPoint(x: 40, y: 40))
      )
    )
    XCTAssertNil(
      tracker.observe(
        .pressed(at: CGPoint(x: 200, y: 200))
      )
    )
    XCTAssertNil(
      tracker.observe(
        .dragged(at: CGPoint(x: 260, y: 240))
      )
    )
    let outcome = tracker.observe(
      .released(at: CGPoint(x: 320, y: 280))
    )

    guard case .selected(let selection) = outcome else {
      return XCTFail("Expected the second press to define the selection")
    }
    XCTAssertEqual(selection.coreGraphicsGlobalRect, CGRect(x: 200, y: 200, width: 120, height: 80))
  }

  func testTinyDragReturnsTooSmallWithoutPixels() throws {
    let display = try makeDisplay()
    var tracker = SystemInteractiveSelectionTracker(
      displays: [display]
    )

    _ = tracker.observe(
      .pressed(at: CGPoint(x: 100, y: 100))
    )
    _ = tracker.observe(
      .dragged(at: CGPoint(x: 101, y: 101))
    )
    let outcome = tracker.observe(
      .released(at: CGPoint(x: 102, y: 102))
    )

    XCTAssertEqual(outcome, .cancelled(.tooSmall))
  }

  func testQueuedFastDragUsesTheMouseEventCoordinatesWithoutLaterPointerSampling() throws {
    let display = try makeDisplay()
    var tracker = SystemInteractiveSelectionTracker(displays: [display])

    let transitions: [SystemInteractivePointerTransition] = [
      .pressed(at: CGPoint(x: 24, y: 36)),
      .dragged(at: CGPoint(x: 400, y: 300)),
      .released(at: CGPoint(x: 824, y: 636)),
    ]
    let outcome = transitions.compactMap { tracker.observe($0) }.last

    guard case .selected(let selection) = outcome else {
      return XCTFail("Expected the complete fast drag")
    }
    XCTAssertEqual(
      selection.coreGraphicsGlobalRect,
      CGRect(x: 24, y: 36, width: 800, height: 600)
    )
  }

  func testClickWithoutDragIsIgnoredBeforeARealSelection() throws {
    let display = try makeDisplay()
    var tracker = SystemInteractiveSelectionTracker(displays: [display])

    let transitions: [SystemInteractivePointerTransition] = [
      .pressed(at: CGPoint(x: 640, y: 480)),
      .released(at: CGPoint(x: 640, y: 480)),
      .pressed(at: CGPoint(x: 100, y: 120)),
      .dragged(at: CGPoint(x: 420, y: 300)),
      .released(at: CGPoint(x: 420, y: 300)),
    ]
    let outcome = transitions.compactMap { tracker.observe($0) }.last

    guard case .selected(let selection) = outcome else {
      return XCTFail("Expected the confirmation click to be ignored")
    }
    XCTAssertEqual(
      selection.coreGraphicsGlobalRect,
      CGRect(x: 100, y: 120, width: 320, height: 180)
    )
  }

  func testLaterCompletedDragReplacesAnEarlierCandidate() throws {
    let display = try makeDisplay()
    var tracker = SystemInteractiveSelectionTracker(displays: [display])

    let transitions: [SystemInteractivePointerTransition] = [
      .pressed(at: CGPoint(x: 20, y: 20)),
      .dragged(at: CGPoint(x: 120, y: 120)),
      .released(at: CGPoint(x: 120, y: 120)),
      .pressed(at: CGPoint(x: 300, y: 300)),
      .dragged(at: CGPoint(x: 700, y: 600)),
      .released(at: CGPoint(x: 700, y: 600)),
    ]
    let outcomes = transitions.compactMap { tracker.observe($0) }

    XCTAssertEqual(outcomes.count, 2)
    guard case .selected(let selection) = outcomes.last else {
      return XCTFail("Expected the final completed drag")
    }
    XCTAssertEqual(
      selection.coreGraphicsGlobalRect,
      CGRect(x: 300, y: 300, width: 400, height: 300)
    )
  }

  func testSpaceAdjustedDragFailsClosed() throws {
    let display = try makeDisplay()
    var tracker = SystemInteractiveSelectionTracker(displays: [display])

    XCTAssertNil(tracker.observe(.pressed(at: CGPoint(x: 100, y: 100))))
    let outcome = tracker.observe(
      .dragged(
        at: CGPoint(x: 300, y: 250),
        spaceModifierActive: true
      )
    )

    XCTAssertEqual(outcome, .cancelled(.systemInterrupted))
    XCTAssertEqual(
      tracker.observe(.released(at: CGPoint(x: 500, y: 400))),
      .cancelled(.systemInterrupted)
    )
  }

  private func makeDisplay() throws -> DisplayGeometry {
    try DisplayGeometry(
      displayID: 7,
      appKitFrame: CGRect(x: 0, y: 0, width: 1_920, height: 1_080),
      coreGraphicsBounds: CGRect(x: 0, y: 0, width: 1_920, height: 1_080),
      backingScale: 1
    )
  }
}
