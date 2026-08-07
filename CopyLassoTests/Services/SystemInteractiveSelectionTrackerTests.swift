import CoreGraphics
import XCTest

@testable import CopyLasso

final class SystemInteractiveSelectionTrackerTests: XCTestCase {
  func testReleasedDragProducesDisplayClampedSelectionGeometry() throws {
    let display = try makeDisplay()
    var tracker = SystemInteractiveSelectionTracker(
      displays: [display],
      initialPointerState: SystemInteractivePointerState(
        location: CGPoint(x: 120, y: 140),
        isLeftButtonPressed: false
      )
    )

    XCTAssertNil(
      tracker.observe(
        SystemInteractivePointerState(
          location: CGPoint(x: 120, y: 140),
          isLeftButtonPressed: true
        )
      )
    )
    let outcome = tracker.observe(
      SystemInteractivePointerState(
        location: CGPoint(x: 2_500, y: 360),
        isLeftButtonPressed: false
      )
    )

    guard case .selected(let selection) = outcome else {
      return XCTFail("Expected a completed selection")
    }
    XCTAssertEqual(selection.displayID, display.displayID)
    XCTAssertEqual(
      selection.coreGraphicsGlobalRect, CGRect(x: 120, y: 140, width: 1_800, height: 220))
    XCTAssertEqual(selection.backingPixelRect, CGRect(x: 120, y: 140, width: 1_800, height: 220))
  }

  func testPreexistingMenuMouseDownMustReleaseBeforeSelectionCanBegin() throws {
    let display = try makeDisplay()
    var tracker = SystemInteractiveSelectionTracker(
      displays: [display],
      initialPointerState: SystemInteractivePointerState(
        location: CGPoint(x: 40, y: 40),
        isLeftButtonPressed: true
      )
    )

    XCTAssertNil(
      tracker.observe(
        SystemInteractivePointerState(
          location: CGPoint(x: 40, y: 40),
          isLeftButtonPressed: false
        )
      )
    )
    XCTAssertNil(
      tracker.observe(
        SystemInteractivePointerState(
          location: CGPoint(x: 200, y: 200),
          isLeftButtonPressed: true
        )
      )
    )
    let outcome = tracker.observe(
      SystemInteractivePointerState(
        location: CGPoint(x: 320, y: 280),
        isLeftButtonPressed: false
      )
    )

    guard case .selected(let selection) = outcome else {
      return XCTFail("Expected the second press to define the selection")
    }
    XCTAssertEqual(selection.coreGraphicsGlobalRect, CGRect(x: 200, y: 200, width: 120, height: 80))
  }

  func testTinyDragReturnsTooSmallWithoutPixels() throws {
    let display = try makeDisplay()
    var tracker = SystemInteractiveSelectionTracker(
      displays: [display],
      initialPointerState: SystemInteractivePointerState(
        location: CGPoint(x: 100, y: 100),
        isLeftButtonPressed: false
      )
    )

    _ = tracker.observe(
      SystemInteractivePointerState(
        location: CGPoint(x: 100, y: 100),
        isLeftButtonPressed: true
      )
    )
    let outcome = tracker.observe(
      SystemInteractivePointerState(
        location: CGPoint(x: 102, y: 102),
        isLeftButtonPressed: false
      )
    )

    XCTAssertEqual(outcome, .cancelled(.tooSmall))
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
