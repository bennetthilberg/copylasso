import SwiftUI

#if DEBUG
  struct DebugRuntimeOptions {
    private let arguments: [String]

    init(arguments: [String]) {
      self.arguments = arguments
    }

    var isUITesting: Bool {
      arguments.contains("--g10-g11-ui-testing")
    }

    var isLiveSelectionTesting: Bool {
      arguments.contains("--g13-live-selection")
    }

    var isLiveCaptureTesting: Bool {
      arguments.contains("--g14-live-capture")
    }

    var usesDebugCaptureService: Bool {
      (isUITesting || isLiveSelectionTesting) && !isLiveCaptureTesting
    }
  }
#endif

@main
@MainActor
struct CopyLassoApp: App {
  private let commandHandler: MenuBarCommandHandler
  private let settingsController: SettingsController
  private let globalShortcutController: GlobalShortcutController

  init() {
    let settingsStore = UserDefaultsSettingsStore()
    let shortcutStore = KeyboardShortcutsStore()
    let launchAtLoginService: any LaunchAtLoginServicing
    let permissionService: any ScreenCapturePermissionService
    let selectionService: any RegionSelectionService
    let screenCaptureService: any ScreenCaptureService

    #if DEBUG
      let arguments = ProcessInfo.processInfo.arguments
      let runtimeOptions = DebugRuntimeOptions(arguments: arguments)
      if runtimeOptions.isUITesting {
        launchAtLoginService = DebugLaunchAtLoginService(
          status: Self.debugLaunchAtLoginStatus(arguments: arguments)
        )
      } else {
        launchAtLoginService = SystemLaunchAtLoginService()
      }
      if arguments.contains("--g10-g11-reset-settings") {
        if !runtimeOptions.isUITesting {
          try? launchAtLoginService.disable()
        }
        settingsStore.reset()
        shortcutStore.reset()
      }
      if arguments.contains("--g10-g11-complete-onboarding") {
        settingsStore.completedOnboardingVersion = SettingsController.currentOnboardingVersion
      }
      permissionService =
        runtimeOptions.isUITesting || runtimeOptions.isLiveSelectionTesting
        ? DebugScreenCapturePermissionService(arguments: arguments)
        : SystemScreenCapturePermissionService(historyStore: settingsStore)
      selectionService =
        runtimeOptions.isUITesting && !runtimeOptions.isLiveSelectionTesting
        ? DebugRegionSelectionService()
        : AppKitRegionSelectionService()
      screenCaptureService =
        runtimeOptions.usesDebugCaptureService
        ? DebugScreenCaptureService()
        : SystemScreenCaptureService()
    #else
      launchAtLoginService = SystemLaunchAtLoginService()
      permissionService = SystemScreenCapturePermissionService(historyStore: settingsStore)
      selectionService = AppKitRegionSelectionService()
      screenCaptureService = SystemScreenCaptureService()
    #endif

    settingsController = SettingsController(
      settingsStore: settingsStore,
      launchAtLoginService: launchAtLoginService,
      shortcutStore: shortcutStore
    )
    let coordinator = CaptureCoordinator()
    let recoveryController = PermissionRecoveryPanelController(
      permissionService: permissionService
    )
    let captureCommand = CaptureCommand(
      coordinator: coordinator,
      permissionService: permissionService,
      selectionService: selectionService,
      screenCaptureService: screenCaptureService,
      ocrService: PendingOCRService(),
      recoveryPresenter: recoveryController
    )
    recoveryController.captureRequester = captureCommand
    commandHandler = MenuBarCommandHandler(
      captureCommand: captureCommand,
      applicationTerminator: SystemApplicationTerminator()
    )
    globalShortcutController = GlobalShortcutController(
      captureCommand: captureCommand,
      eventSource: KeyboardShortcutsEventSource()
    )
    globalShortcutController.start()
  }

  var body: some Scene {
    MenuBarExtra {
      MenuBarMenuView(commandHandler: commandHandler)
    } label: {
      MenuBarLabelView(settingsController: settingsController)
    }
    .menuBarExtraStyle(.menu)

    Settings {
      SettingsView(
        settingsController: settingsController,
        metadata: AboutMetadata(bundle: .main)
      )
    }
    .defaultSize(width: 520, height: 560)

    Window("Welcome to CopyLasso", id: "onboarding") {
      OnboardingView(settingsController: settingsController)
    }
    .windowResizability(.contentSize)

    Window("About CopyLasso", id: "about") {
      AboutView(metadata: AboutMetadata(bundle: .main))
    }
    .windowResizability(.contentSize)
  }

  #if DEBUG
    private static func debugLaunchAtLoginStatus(arguments: [String]) -> LaunchAtLoginStatus {
      guard
        let argument = arguments.first(where: {
          $0.hasPrefix("--g10-g11-login-status=")
        })
      else {
        return .disabled
      }

      switch argument.split(separator: "=", maxSplits: 1).last {
      case "enabled":
        return .enabled
      case "requires-approval":
        return .requiresApproval
      case "unavailable":
        return .unavailable
      default:
        return .disabled
      }
    }
  #endif
}
