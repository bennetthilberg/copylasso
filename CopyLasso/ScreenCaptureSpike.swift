import Combine
import CoreGraphics
import CoreVideo
import Foundation
import ScreenCaptureKit

enum ScreenCaptureAuthorizationObservation: Equatable {
  case granted
  case notGrantedNeverRequested
  case notGrantedAfterRequest
  case notGrantedAfterPreviouslyGranted

  var message: String {
    switch self {
    case .granted:
      "Granted."
    case .notGrantedNeverRequested:
      "Not granted; CopyLasso has not requested access in this preferences history."
    case .notGrantedAfterRequest:
      "Not granted after a prior request; macOS does not expose whether access is denied or pending."
    case .notGrantedAfterPreviouslyGranted:
      "Not granted after previously observed access; access may have been revoked."
    }
  }
}

struct ScreenCapturePermissionHistory: Equatable {
  var hasRequested = false
  var hasObservedGranted = false

  func observation(preflightGranted: Bool) -> ScreenCaptureAuthorizationObservation {
    if preflightGranted {
      return .granted
    }
    if hasObservedGranted {
      return .notGrantedAfterPreviouslyGranted
    }
    if hasRequested {
      return .notGrantedAfterRequest
    }
    return .notGrantedNeverRequested
  }
}

enum ScreenCaptureSpikeError: Error, Equatable, LocalizedError {
  case permissionNotGranted
  case mainDisplayUnavailable
  case invalidGeometry
  case captureFailed(code: Int)

  var errorDescription: String? {
    switch self {
    case .permissionNotGranted:
      "Screen Recording access is not granted. Use System Settings to review access, then reopen CopyLasso if macOS requests it."
    case .mainDisplayUnavailable:
      "The main display is not available to ScreenCaptureKit."
    case .invalidGeometry:
      "The selected display does not provide valid capture geometry."
    case .captureFailed(let code):
      "ScreenCaptureKit could not capture the region (error code \(code))."
    }
  }
}

struct ScreenCaptureRegion: Equatable {
  let sourceRect: CGRect
  let pixelWidth: Int
  let pixelHeight: Int
}

enum ScreenCaptureRegionPlanner {
  static let requestedSize = CGSize(width: 640, height: 360)

  static func centeredRegion(
    displaySize: CGSize,
    pointPixelScale: CGFloat
  ) throws -> ScreenCaptureRegion {
    guard displaySize.width > 0, displaySize.height > 0, pointPixelScale > 0 else {
      throw ScreenCaptureSpikeError.invalidGeometry
    }

    let width = min(requestedSize.width, displaySize.width)
    let height = min(requestedSize.height, displaySize.height)
    let sourceRect = CGRect(
      x: (displaySize.width - width) / 2,
      y: (displaySize.height - height) / 2,
      width: width,
      height: height
    )
    let pixelWidth = Int((width * pointPixelScale).rounded())
    let pixelHeight = Int((height * pointPixelScale).rounded())

    guard pixelWidth > 0, pixelHeight > 0 else {
      throw ScreenCaptureSpikeError.invalidGeometry
    }

    return ScreenCaptureRegion(
      sourceRect: sourceRect,
      pixelWidth: pixelWidth,
      pixelHeight: pixelHeight
    )
  }
}

@MainActor
protocol ScreenCaptureHistoryStoring: AnyObject {
  var hasRequested: Bool { get set }
  var hasObservedGranted: Bool { get set }
  func reset()
}

@MainActor
final class UserDefaultsScreenCaptureHistoryStore: ScreenCaptureHistoryStoring {
  private enum Key {
    static let hasRequested = "g06.screenCapture.hasRequested"
    static let hasObservedGranted = "g06.screenCapture.hasObservedGranted"
  }

  private let defaults: UserDefaults

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  var hasRequested: Bool {
    get { defaults.bool(forKey: Key.hasRequested) }
    set { defaults.set(newValue, forKey: Key.hasRequested) }
  }

  var hasObservedGranted: Bool {
    get { defaults.bool(forKey: Key.hasObservedGranted) }
    set { defaults.set(newValue, forKey: Key.hasObservedGranted) }
  }

  func reset() {
    defaults.removeObject(forKey: Key.hasRequested)
    defaults.removeObject(forKey: Key.hasObservedGranted)
  }
}

@MainActor
struct ScreenCapturePermissionClient {
  let preflight: () -> Bool
  let request: () -> Bool

  static let live = ScreenCapturePermissionClient(
    preflight: { CGPreflightScreenCaptureAccess() },
    request: { CGRequestScreenCaptureAccess() }
  )
}

@MainActor
struct ScreenCaptureImageClient {
  let capture: () async throws -> CGImage

  static let live = ScreenCaptureImageClient(capture: {
    do {
      let shareableContent = try await SCShareableContent.current
      let mainDisplayID = CGMainDisplayID()
      guard let display = shareableContent.displays.first(where: { $0.displayID == mainDisplayID })
      else {
        throw ScreenCaptureSpikeError.mainDisplayUnavailable
      }

      let filter = SCContentFilter(
        display: display,
        excludingApplications: [],
        exceptingWindows: []
      )
      let contentInfo = SCShareableContent.info(for: filter)
      let region = try ScreenCaptureRegionPlanner.centeredRegion(
        displaySize: CGSize(width: display.width, height: display.height),
        pointPixelScale: CGFloat(contentInfo.pointPixelScale)
      )

      let configuration = SCStreamConfiguration()
      configuration.sourceRect = region.sourceRect
      configuration.width = region.pixelWidth
      configuration.height = region.pixelHeight
      configuration.pixelFormat = kCVPixelFormatType_32BGRA
      configuration.showsCursor = false
      configuration.capturesAudio = false

      return try await SCScreenshotManager.captureImage(
        contentFilter: filter,
        configuration: configuration
      )
    } catch {
      throw ScreenCaptureSpikeError.from(error)
    }
  })
}

extension ScreenCaptureSpikeError {
  static func from(_ error: Error) -> ScreenCaptureSpikeError {
    if let spikeError = error as? ScreenCaptureSpikeError {
      return spikeError
    }

    let nsError = error as NSError
    if nsError.domain == SCStreamErrorDomain,
      nsError.code == SCStreamError.Code.userDeclined.rawValue
    {
      return .permissionNotGranted
    }
    return .captureFailed(code: nsError.code)
  }
}

@MainActor
final class ScreenCaptureSpikeModel: ObservableObject {
  @Published private(set) var authorizationObservation: ScreenCaptureAuthorizationObservation
  @Published private(set) var previewImage: CGImage?
  @Published private(set) var lastError: ScreenCaptureSpikeError?
  @Published private(set) var isBusy = false

  private let permissionClient: ScreenCapturePermissionClient
  private let imageClient: ScreenCaptureImageClient
  private let historyStore: any ScreenCaptureHistoryStoring

  init(
    permissionClient: ScreenCapturePermissionClient,
    imageClient: ScreenCaptureImageClient,
    historyStore: any ScreenCaptureHistoryStoring
  ) {
    self.permissionClient = permissionClient
    self.imageClient = imageClient
    self.historyStore = historyStore

    let isGranted = permissionClient.preflight()
    if isGranted {
      historyStore.hasObservedGranted = true
    }
    authorizationObservation = ScreenCapturePermissionHistory(
      hasRequested: historyStore.hasRequested,
      hasObservedGranted: historyStore.hasObservedGranted
    ).observation(preflightGranted: isGranted)
  }

  static func live() -> ScreenCaptureSpikeModel {
    ScreenCaptureSpikeModel(
      permissionClient: .live,
      imageClient: .live,
      historyStore: UserDefaultsScreenCaptureHistoryStore()
    )
  }

  func requestAndCapture() async {
    guard !isBusy else { return }
    isBusy = true
    defer { isBusy = false }
    lastError = nil
    previewImage = nil

    if permissionClient.preflight() {
      recordGrantedAccess()
    } else {
      historyStore.hasRequested = true
      guard permissionClient.request() else {
        refreshAuthorizationObservation(preflightGranted: false)
        lastError = .permissionNotGranted
        return
      }
      recordGrantedAccess()
    }

    await performCapture()
  }

  func captureAgain() async {
    guard !isBusy else { return }
    isBusy = true
    defer { isBusy = false }
    lastError = nil
    previewImage = nil

    guard permissionClient.preflight() else {
      refreshAuthorizationObservation(preflightGranted: false)
      lastError = .permissionNotGranted
      return
    }

    recordGrantedAccess()
    await performCapture()
  }

  func clearPreview() {
    previewImage = nil
    lastError = nil
  }

  func resetLocalHistory() {
    historyStore.reset()
    clearPreview()
    refreshAuthorizationObservation(preflightGranted: permissionClient.preflight())
  }

  private func performCapture() async {
    do {
      previewImage = try await imageClient.capture()
    } catch {
      let spikeError = ScreenCaptureSpikeError.from(error)
      previewImage = nil
      lastError = spikeError
      if spikeError == .permissionNotGranted {
        authorizationObservation = .notGrantedAfterPreviouslyGranted
      }
    }
  }

  private func recordGrantedAccess() {
    historyStore.hasObservedGranted = true
    refreshAuthorizationObservation(preflightGranted: true)
  }

  private func refreshAuthorizationObservation(preflightGranted: Bool) {
    authorizationObservation = ScreenCapturePermissionHistory(
      hasRequested: historyStore.hasRequested,
      hasObservedGranted: historyStore.hasObservedGranted
    ).observation(preflightGranted: preflightGranted)
  }
}
