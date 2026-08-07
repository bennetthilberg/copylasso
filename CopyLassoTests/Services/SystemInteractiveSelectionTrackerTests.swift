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

  private func makeDisplay() throws -> DisplayGeometry {
    try DisplayGeometry(
      displayID: 7,
      appKitFrame: CGRect(x: 0, y: 0, width: 1_920, height: 1_080),
      coreGraphicsBounds: CGRect(x: 0, y: 0, width: 1_920, height: 1_080),
      backingScale: 1
    )
  }
}
