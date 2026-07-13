import CoreGraphics
import Foundation

enum DisplayGeometryError: Error, Equatable, Sendable {
  case invalidAppKitFrame
  case invalidCoreGraphicsBounds
  case mismatchedCoordinateSpaceSize
  case invalidBackingScale
  case invalidPoint
}

struct DisplayGeometry: Equatable, Sendable {
  let displayID: CGDirectDisplayID
  let appKitFrame: CGRect
  let coreGraphicsBounds: CGRect
  let backingScale: CGFloat

  init(
    displayID: CGDirectDisplayID,
    appKitFrame: CGRect,
    coreGraphicsBounds: CGRect,
    backingScale: CGFloat
  ) throws {
    guard Self.isValid(frame: appKitFrame) else {
      throw DisplayGeometryError.invalidAppKitFrame
    }
    guard Self.isValid(frame: coreGraphicsBounds) else {
      throw DisplayGeometryError.invalidCoreGraphicsBounds
    }
    guard Self.sizesMatch(appKitFrame.size, coreGraphicsBounds.size) else {
      throw DisplayGeometryError.mismatchedCoordinateSpaceSize
    }
    guard backingScale.isFinite, backingScale > 0 else {
      throw DisplayGeometryError.invalidBackingScale
    }

    self.displayID = displayID
    self.appKitFrame = appKitFrame
    self.coreGraphicsBounds = coreGraphicsBounds
    self.backingScale = backingScale
  }

  func selectionResult(
    from start: CGPoint,
    to end: CGPoint,
    minimumSize: CGFloat = 4
  ) throws -> SelectionResult? {
    guard Self.isFinite(point: start), Self.isFinite(point: end) else {
      throw DisplayGeometryError.invalidPoint
    }

    let clampedStart = clamped(point: start)
    let clampedEnd = clamped(point: end)
    let appKitGlobalRect = Self.normalizedRect(from: clampedStart, to: clampedEnd)
    guard appKitGlobalRect.width >= minimumSize, appKitGlobalRect.height >= minimumSize else {
      return nil
    }

    let displayLocalRect = appKitGlobalRect.offsetBy(
      dx: -appKitFrame.minX,
      dy: -appKitFrame.minY
    )
    let coreGraphicsDisplayLocalRect = CGRect(
      x: displayLocalRect.minX,
      y: appKitFrame.height - displayLocalRect.maxY,
      width: displayLocalRect.width,
      height: displayLocalRect.height
    )
    let coreGraphicsGlobalRect = coreGraphicsDisplayLocalRect.offsetBy(
      dx: coreGraphicsBounds.minX,
      dy: coreGraphicsBounds.minY
    )
    let backingPixelRect = Self.outwardRoundedPixelRect(
      coreGraphicsDisplayLocalRect,
      scale: backingScale
    )

    return SelectionResult(
      displayID: displayID,
      displayPointSize: appKitFrame.size,
      appKitGlobalRect: appKitGlobalRect,
      displayLocalRect: displayLocalRect,
      coreGraphicsGlobalRect: coreGraphicsGlobalRect,
      coreGraphicsDisplayLocalRect: coreGraphicsDisplayLocalRect,
      backingPixelRect: backingPixelRect,
      backingScale: backingScale
    )
  }

  func clamped(point: CGPoint) -> CGPoint {
    CGPoint(
      x: min(max(point.x, appKitFrame.minX), appKitFrame.maxX),
      y: min(max(point.y, appKitFrame.minY), appKitFrame.maxY)
    )
  }

  func contains(point: CGPoint) -> Bool {
    point.x >= appKitFrame.minX && point.x <= appKitFrame.maxX
      && point.y >= appKitFrame.minY && point.y <= appKitFrame.maxY
  }

  private static func isValid(frame: CGRect) -> Bool {
    frame.origin.x.isFinite && frame.origin.y.isFinite
      && frame.size.width.isFinite && frame.size.height.isFinite
      && frame.size.width > 0 && frame.size.height > 0
  }

  private static func isFinite(point: CGPoint) -> Bool {
    point.x.isFinite && point.y.isFinite
  }

  private static func sizesMatch(_ first: CGSize, _ second: CGSize) -> Bool {
    abs(first.width - second.width) < 0.01 && abs(first.height - second.height) < 0.01
  }

  private static func normalizedRect(from first: CGPoint, to second: CGPoint) -> CGRect {
    CGRect(
      x: min(first.x, second.x),
      y: min(first.y, second.y),
      width: abs(second.x - first.x),
      height: abs(second.y - first.y)
    )
  }

  private static func outwardRoundedPixelRect(_ rect: CGRect, scale: CGFloat) -> CGRect {
    let minX = floor(rect.minX * scale)
    let minY = floor(rect.minY * scale)
    let maxX = ceil(rect.maxX * scale)
    let maxY = ceil(rect.maxY * scale)
    return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
  }
}

struct SelectionResult: Equatable, Sendable {
  let displayID: CGDirectDisplayID
  let displayPointSize: CGSize
  let appKitGlobalRect: CGRect
  let displayLocalRect: CGRect
  let coreGraphicsGlobalRect: CGRect
  let coreGraphicsDisplayLocalRect: CGRect
  let backingPixelRect: CGRect
  let backingScale: CGFloat
}

enum SelectionCancellationReason: String, Equatable, Sendable {
  case escape
  case tooSmall
  case displayChanged
  case systemInterrupted
  case applicationTerminated
}

enum SelectionOutcome: Equatable, Sendable {
  case selected(SelectionResult)
  case cancelled(SelectionCancellationReason)
}

final class SelectionSession {
  private struct Drag {
    let display: DisplayGeometry
    let start: CGPoint
    var current: CGPoint
  }

  private let displaysByID: [CGDirectDisplayID: DisplayGeometry]
  private let completion: (SelectionOutcome) -> Void
  private let minimumSize: CGFloat
  private var drag: Drag?
  private var hasCompleted = false

  init(
    displays: [DisplayGeometry],
    minimumSize: CGFloat = 4,
    completion: @escaping (SelectionOutcome) -> Void
  ) {
    var indexedDisplays: [CGDirectDisplayID: DisplayGeometry] = [:]
    var containsDuplicateIdentifier = false
    for display in displays
    where indexedDisplays.updateValue(display, forKey: display.displayID) != nil {
      containsDuplicateIdentifier = true
    }
    displaysByID = containsDuplicateIdentifier ? [:] : indexedDisplays
    self.minimumSize = minimumSize
    self.completion = completion
  }

  var currentDisplayID: CGDirectDisplayID? {
    drag?.display.displayID
  }

  var currentAppKitRect: CGRect? {
    guard let drag else { return nil }
    let start = drag.display.clamped(point: drag.start)
    let current = drag.display.clamped(point: drag.current)
    return CGRect(
      x: min(start.x, current.x),
      y: min(start.y, current.y),
      width: abs(current.x - start.x),
      height: abs(current.y - start.y)
    )
  }

  func begin(on displayID: CGDirectDisplayID, at point: CGPoint) -> Bool {
    guard !hasCompleted, drag == nil, let display = displaysByID[displayID],
      display.contains(point: point)
    else {
      return false
    }
    drag = Drag(display: display, start: point, current: point)
    return true
  }

  func update(to point: CGPoint) {
    guard !hasCompleted, var drag else { return }
    drag.current = drag.display.clamped(point: point)
    self.drag = drag
  }

  func finish(at point: CGPoint) {
    guard !hasCompleted, var drag else { return }
    drag.current = drag.display.clamped(point: point)
    self.drag = drag

    do {
      if let result = try drag.display.selectionResult(
        from: drag.start,
        to: drag.current,
        minimumSize: minimumSize
      ) {
        complete(.selected(result))
      } else {
        complete(.cancelled(.tooSmall))
      }
    } catch {
      complete(.cancelled(.displayChanged))
    }
  }

  func cancel(_ reason: SelectionCancellationReason) {
    complete(.cancelled(reason))
  }

  private func complete(_ outcome: SelectionOutcome) {
    guard !hasCompleted else { return }
    hasCompleted = true
    drag = nil
    completion(outcome)
  }
}
