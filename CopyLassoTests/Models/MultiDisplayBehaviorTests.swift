import CoreGraphics
import XCTest

@testable import CopyLasso

final class MultiDisplayBehaviorTests: XCTestCase {
  func testEverySyntheticDisplayPreservesIdentityAndLocalPixelsThroughCapturePlanning()
    throws
  {
    for fixture in fixtures {
      let display = try fixture.geometry()
      let start = CGPoint(
        x: fixture.appKitFrame.minX + 10.25,
        y: fixture.appKitFrame.minY + 20.25
      )
      let end = CGPoint(
        x: fixture.appKitFrame.minX + 210.75,
        y: fixture.appKitFrame.minY + 120.5
      )
      let selection = try XCTUnwrap(display.selectionResult(from: start, to: end))
      let expectedLocal = CGRect(x: 10.25, y: 20.25, width: 200.5, height: 100.25)
      let expectedCoreGraphicsLocal = CGRect(
        x: expectedLocal.minX,
        y: fixture.appKitFrame.height - expectedLocal.maxY,
        width: expectedLocal.width,
        height: expectedLocal.height
      )

      XCTAssertEqual(selection.displayID, fixture.displayID, fixture.name)
      assertRect(selection.displayLocalRect, equals: expectedLocal, fixture.name)
      assertRect(
        selection.coreGraphicsDisplayLocalRect,
        equals: expectedCoreGraphicsLocal,
        fixture.name
      )

      let request = try ScreenCaptureRequestPlanner.request(for: selection)
      XCTAssertEqual(request.displayID, fixture.displayID, fixture.name)
      XCTAssertEqual(request.pixelWidth, Int(selection.backingPixelRect.width), fixture.name)
      XCTAssertEqual(request.pixelHeight, Int(selection.backingPixelRect.height), fixture.name)
      XCTAssertFalse(request.showsCursor, fixture.name)
      XCTAssertFalse(request.capturesAudio, fixture.name)
      XCTAssertNoThrow(
        try ScreenCaptureRequestValidator.validate(
          request,
          against: ScreenCaptureDisplaySnapshot(
            displayID: fixture.displayID,
            pointSize: fixture.appKitFrame.size,
            pointPixelScale: fixture.scale
          )
        ),
        fixture.name
      )
    }
  }

  func testCrossDisplayDragsClampToTheInitiatingDisplayAcrossTheTopology() throws {
    let displays = try fixtures.map { try $0.geometry() }

    for display in displays {
      let start = CGPoint(x: display.appKitFrame.midX, y: display.appKitFrame.midY)
      let endpoints = [
        CGPoint(x: -20_000, y: start.y + 50),
        CGPoint(x: 20_000, y: start.y + 50),
        CGPoint(x: start.x + 50, y: -20_000),
        CGPoint(x: start.x + 50, y: 20_000),
      ]

      for endpoint in endpoints {
        let selection = try XCTUnwrap(display.selectionResult(from: start, to: endpoint))
        XCTAssertEqual(selection.displayID, display.displayID)
        XCTAssertTrue(display.appKitFrame.contains(selection.appKitGlobalRect))
        XCTAssertGreaterThanOrEqual(selection.displayLocalRect.minX, 0)
        XCTAssertGreaterThanOrEqual(selection.displayLocalRect.minY, 0)
        XCTAssertLessThanOrEqual(selection.displayLocalRect.maxX, display.appKitFrame.width)
        XCTAssertLessThanOrEqual(selection.displayLocalRect.maxY, display.appKitFrame.height)
      }
    }
  }

  func testCurrentDisplayChangesRejectTheOriginalRequestForEveryScale() throws {
    for fixture in fixtures {
      let display = try fixture.geometry()
      let selection = try XCTUnwrap(
        display.selectionResult(
          from: CGPoint(x: fixture.appKitFrame.minX + 40, y: fixture.appKitFrame.minY + 50),
          to: CGPoint(x: fixture.appKitFrame.minX + 240, y: fixture.appKitFrame.minY + 150)
        )
      )
      let request = try ScreenCaptureRequestPlanner.request(for: selection)
      let changes = [
        ScreenCaptureDisplaySnapshot(
          displayID: fixture.displayID + 100,
          pointSize: fixture.appKitFrame.size,
          pointPixelScale: fixture.scale
        ),
        ScreenCaptureDisplaySnapshot(
          displayID: fixture.displayID,
          pointSize: CGSize(
            width: fixture.appKitFrame.width - 1,
            height: fixture.appKitFrame.height
          ),
          pointPixelScale: fixture.scale
        ),
        ScreenCaptureDisplaySnapshot(
          displayID: fixture.displayID,
          pointSize: fixture.appKitFrame.size,
          pointPixelScale: fixture.scale + 0.5
        ),
      ]

      for snapshot in changes {
        XCTAssertThrowsError(
          try ScreenCaptureRequestValidator.validate(request, against: snapshot),
          fixture.name
        ) { error in
          XCTAssertEqual(error as? ScreenCaptureError, .displayConfigurationChanged)
        }
      }
    }
  }

  private func assertRect(
    _ actual: CGRect,
    equals expected: CGRect,
    _ message: String,
    accuracy: CGFloat = 0.000_1
  ) {
    XCTAssertEqual(actual.minX, expected.minX, accuracy: accuracy, message)
    XCTAssertEqual(actual.minY, expected.minY, accuracy: accuracy, message)
    XCTAssertEqual(actual.width, expected.width, accuracy: accuracy, message)
    XCTAssertEqual(actual.height, expected.height, accuracy: accuracy, message)
  }

  private var fixtures: [DisplayFixture] {
    [
      DisplayFixture(
        name: "primary landscape 1x",
        displayID: 1,
        appKitFrame: CGRect(x: 0, y: 0, width: 1_920, height: 1_080),
        coreGraphicsBounds: CGRect(x: 0, y: 0, width: 1_920, height: 1_080),
        scale: 1
      ),
      DisplayFixture(
        name: "left offset 2x",
        displayID: 2,
        appKitFrame: CGRect(x: -1_440, y: 100, width: 1_440, height: 900),
        coreGraphicsBounds: CGRect(x: -1_440, y: 180, width: 1_440, height: 900),
        scale: 2
      ),
      DisplayFixture(
        name: "right mixed scale 1.5x",
        displayID: 3,
        appKitFrame: CGRect(x: 1_920, y: -120, width: 2_560, height: 1_440),
        coreGraphicsBounds: CGRect(x: 1_920, y: 120, width: 2_560, height: 1_440),
        scale: 1.5
      ),
      DisplayFixture(
        name: "portrait above 2x",
        displayID: 4,
        appKitFrame: CGRect(x: 300, y: 1_080, width: 1_080, height: 1_920),
        coreGraphicsBounds: CGRect(x: 300, y: -1_920, width: 1_080, height: 1_920),
        scale: 2
      ),
      DisplayFixture(
        name: "below primary 1x",
        displayID: 5,
        appKitFrame: CGRect(x: 200, y: -1_200, width: 1_600, height: 1_200),
        coreGraphicsBounds: CGRect(x: 200, y: 1_080, width: 1_600, height: 1_200),
        scale: 1
      ),
      DisplayFixture(
        name: "diagonal negative origin 1.5x",
        displayID: 6,
        appKitFrame: CGRect(x: -1_280, y: -1_024, width: 1_280, height: 1_024),
        coreGraphicsBounds: CGRect(x: -1_280, y: 1_080, width: 1_280, height: 1_024),
        scale: 1.5
      ),
      DisplayFixture(
        name: "recorded Sidecar shape 2x",
        displayID: 7,
        appKitFrame: CGRect(x: -1_298, y: 126, width: 1_298, height: 954),
        coreGraphicsBounds: CGRect(x: -1_298, y: 0, width: 1_298, height: 954),
        scale: 2
      ),
    ]
  }
}

private struct DisplayFixture {
  let name: String
  let displayID: CGDirectDisplayID
  let appKitFrame: CGRect
  let coreGraphicsBounds: CGRect
  let scale: CGFloat

  func geometry() throws -> DisplayGeometry {
    try DisplayGeometry(
      displayID: displayID,
      appKitFrame: appKitFrame,
      coreGraphicsBounds: coreGraphicsBounds,
      backingScale: scale
    )
  }
}
