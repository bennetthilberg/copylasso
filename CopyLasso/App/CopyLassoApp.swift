import SwiftUI

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

    #if DEBUG
      let arguments = ProcessInfo.processInfo.arguments
      let isUITesting = arguments.contains("--g10-g11-ui-testing")
      if isUITesting {
        launchAtLoginService = DebugLaunchAtLoginService(
          status: Self.debugLaunchAtLoginStatus(arguments: arguments)
        )
      } else {
        launchAtLoginService = SystemLaunchAtLoginService()
      }
      if arguments.contains("--g10-g11-reset-settings") {
        if !isUITesting {
          try? launchAtLoginService.disable()
        }
        settingsStore.reset()
        shortcutStore.reset()
      }
      if arguments.contains("--g10-g11-complete-onboarding") {
        settingsStore.completedOnboardingVersion = SettingsController.currentOnboardingVersion
      }
      permissionService =
        isUITesting
        ? DebugScreenCapturePermissionService(arguments: arguments)
        : SystemScreenCapturePermissionService(historyStore: settingsStore)
    #else
      launchAtLoginService = SystemLaunchAtLoginService()
      permissionService = SystemScreenCapturePermissionService(historyStore: settingsStore)
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
      selectionService: PendingRegionSelectionService(),
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
