import CoreGraphics
import CoreVideo
import Foundation
import ScreenCaptureKit

enum ScreenCaptureError: Error, Equatable, Sendable {
  case invalidSelection
  case displayUnavailable
  case displayConfigurationChanged
  case permissionDenied
  case emptyOutput
  case unexpectedImageDimensions(
    expectedWidth: Int,
    expectedHeight: Int,
    actualWidth: Int,
    actualHeight: Int
  )
  case frameworkFailure(code: Int)
}

struct ScreenCaptureRequest: Equatable, Sendable {
  let displayID: CGDirectDisplayID
  let expectedDisplayPointSize: CGSize
  let sourceRect: CGRect
  let pixelWidth: Int
  let pixelHeight: Int
  let backingScale: CGFloat
  let showsCursor: Bool
  let capturesAudio: Bool
}

enum ScreenCaptureRequestPlanner {
  static func request(for selection: SelectionResult) throws -> ScreenCaptureRequest {
    let pointRect = selection.coreGraphicsDisplayLocalRect
    let pixelRect = selection.backingPixelRect
    let scale = selection.backingScale

    guard isValid(rect: pointRect), isValid(rect: pixelRect), scale.isFinite, scale > 0,
      pixelRect.minX >= 0, pixelRect.minY >= 0
    else {
      throw ScreenCaptureError.invalidSelection
    }

    let expectedPixelRect = outwardRoundedPixelRect(pointRect, scale: scale)
    guard pixelRect == expectedPixelRect,
      pixelRect.width <= CGFloat(Int.max), pixelRect.height <= CGFloat(Int.max)
    else {
      throw ScreenCaptureError.invalidSelection
    }

    let pixelWidth = Int(pixelRect.width)
    let pixelHeight = Int(pixelRect.height)
    guard pixelWidth > 0, pixelHeight > 0 else {
      throw ScreenCaptureError.invalidSelection
    }

    let sourceRect = CGRect(
      x: pixelRect.minX / scale,
      y: pixelRect.minY / scale,
      width: pixelRect.width / scale,
      height: pixelRect.height / scale
    )
    guard isValid(rect: sourceRect) else {
      throw ScreenCaptureError.invalidSelection
    }

    return ScreenCaptureRequest(
      displayID: selection.displayID,
      expectedDisplayPointSize: selection.displayPointSize,
      sourceRect: sourceRect,
      pixelWidth: pixelWidth,
      pixelHeight: pixelHeight,
      backingScale: scale,
      showsCursor: false,
      capturesAudio: false
    )
  }

  private static func outwardRoundedPixelRect(_ rect: CGRect, scale: CGFloat) -> CGRect {
    let minX = floor(rect.minX * scale)
    let minY = floor(rect.minY * scale)
    let maxX = ceil(rect.maxX * scale)
    let maxY = ceil(rect.maxY * scale)
    return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
  }

  private static func isValid(rect: CGRect) -> Bool {
    rect.origin.x.isFinite && rect.origin.y.isFinite
      && rect.width.isFinite && rect.height.isFinite
      && rect.width > 0 && rect.height > 0
  }
}

struct ScreenCaptureDisplaySnapshot: Equatable, Sendable {
  let displayID: CGDirectDisplayID
  let pointSize: CGSize
  let pointPixelScale: CGFloat
}

enum ScreenCaptureRequestValidator {
  static func validate(
    _ request: ScreenCaptureRequest,
    against display: ScreenCaptureDisplaySnapshot
  ) throws {
    let size = display.pointSize
    guard display.displayID == request.displayID,
      size.width.isFinite, size.height.isFinite,
      size.width > 0, size.height > 0,
      sizesMatch(size, request.expectedDisplayPointSize),
      display.pointPixelScale.isFinite,
      abs(display.pointPixelScale - request.backingScale) < 0.01,
      request.sourceRect.minX >= 0, request.sourceRect.minY >= 0,
      request.sourceRect.maxX <= size.width,
      request.sourceRect.maxY <= size.height
    else {
      throw ScreenCaptureError.displayConfigurationChanged
    }
  }

  private static func sizesMatch(_ first: CGSize, _ second: CGSize) -> Bool {
    abs(first.width - second.width) < 0.01 && abs(first.height - second.height) < 0.01
  }
}

struct ScreenCaptureKitClient: Sendable {
  typealias Capture = @Sendable (ScreenCaptureRequest) async throws -> CGImage?

  private let captureOperation: Capture

  init(_ capture: @escaping Capture) {
    captureOperation = capture
  }

  func capture(_ request: ScreenCaptureRequest) async throws -> CGImage? {
    try await captureOperation(request)
  }

  static let live = ScreenCaptureKitClient { request in
    let content = try await SCShareableContent.current
    guard let display = content.displays.first(where: { $0.displayID == request.displayID }) else {
      throw ScreenCaptureError.displayUnavailable
    }

    let filter = SCContentFilter(
      display: display,
      excludingApplications: [],
      exceptingWindows: []
    )
    let contentInfo = SCShareableContent.info(for: filter)
    let snapshot = ScreenCaptureDisplaySnapshot(
      displayID: display.displayID,
      pointSize: CGSize(width: display.width, height: display.height),
      pointPixelScale: CGFloat(contentInfo.pointPixelScale)
    )
    try ScreenCaptureRequestValidator.validate(request, against: snapshot)

    let configuration = SCStreamConfiguration()
    configuration.sourceRect = request.sourceRect
    configuration.width = request.pixelWidth
    configuration.height = request.pixelHeight
    configuration.pixelFormat = kCVPixelFormatType_32BGRA
    configuration.showsCursor = request.showsCursor
    configuration.capturesAudio = request.capturesAudio

    return try await SCScreenshotManager.captureImage(
      contentFilter: filter,
      configuration: configuration
    )
  }
}

actor SystemScreenCaptureService: ScreenCaptureService {
  private let client: ScreenCaptureKitClient

  init(client: ScreenCaptureKitClient = .live) {
    self.client = client
  }

  func capture(_ selection: SelectionResult) async throws -> CGImage {
    let request = try ScreenCaptureRequestPlanner.request(for: selection)
    let image: CGImage?
    do {
      image = try await client.capture(request)
    } catch {
      throw Self.map(error)
    }

    guard let image else {
      throw ScreenCaptureError.emptyOutput
    }
    guard image.width == request.pixelWidth, image.height == request.pixelHeight else {
      throw ScreenCaptureError.unexpectedImageDimensions(
        expectedWidth: request.pixelWidth,
        expectedHeight: request.pixelHeight,
        actualWidth: image.width,
        actualHeight: image.height
      )
    }
    return image
  }

  private static func map(_ error: any Error) -> ScreenCaptureError {
    if let captureError = error as? ScreenCaptureError {
      return captureError
    }

    let error = error as NSError
    guard error.domain == SCStreamErrorDomain else {
      return .frameworkFailure(code: error.code)
    }

    switch error.code {
    case SCStreamError.Code.userDeclined.rawValue:
      return .permissionDenied
    case SCStreamError.Code.noDisplayList.rawValue,
      SCStreamError.Code.noCaptureSource.rawValue:
      return .displayUnavailable
    default:
      return .frameworkFailure(code: error.code)
    }
  }
}
