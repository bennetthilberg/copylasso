#if DEBUG
  @MainActor
  final class DebugScreenCapturePermissionService: ScreenCapturePermissionService {
    private let currentResults: [ScreenCaptureAuthorizationObservation]
    private let requestResult: ScreenCaptureAuthorizationObservation
    private let settingsOpenResult: Bool
    private var currentIndex = 0

    init(arguments: [String]) {
      let sequence = Self.argumentValue(
        prefix: "--g12-permission-sequence=",
        arguments: arguments
      )?
      .split(separator: ",")
      .compactMap { Self.observation(named: String($0)) }

      if let sequence, !sequence.isEmpty {
        currentResults = sequence
      } else {
        let value = Self.argumentValue(
          prefix: "--g12-permission=",
          arguments: arguments
        )
        currentResults = [Self.observation(named: value ?? "granted") ?? .granted]
      }

      let requestValue = Self.argumentValue(
        prefix: "--g12-request=",
        arguments: arguments
      )
      requestResult =
        Self.observation(named: requestValue ?? "after-request")
        ?? .notGrantedAfterRequest
      settingsOpenResult = !arguments.contains("--g12-settings-open=failure")
    }

    func currentObservation() -> ScreenCaptureAuthorizationObservation {
      let result = currentResults[min(currentIndex, currentResults.count - 1)]
      if currentIndex < currentResults.count - 1 {
        currentIndex += 1
      }
      return result
    }

    func requestAccess() -> ScreenCaptureAuthorizationObservation {
      requestResult
    }

    func openSystemSettings() -> Bool {
      settingsOpenResult
    }

    private static func argumentValue(prefix: String, arguments: [String]) -> String? {
      arguments.last(where: { $0.hasPrefix(prefix) })?
        .dropFirst(prefix.count)
        .description
    }

    private static func observation(
      named name: String
    ) -> ScreenCaptureAuthorizationObservation? {
      switch name {
      case "granted":
        .granted
      case "never-requested":
        .notGrantedNeverRequested
      case "after-request":
        .notGrantedAfterRequest
      case "previously-granted":
        .notGrantedAfterPreviouslyGranted
      default:
        nil
      }
    }
  }
#endif
