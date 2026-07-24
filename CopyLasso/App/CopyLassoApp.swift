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
  private let feedbackController: FeedbackPanelController
  private let lifecycleController: ApplicationLifecycleController
  private let successSoundPlayer: SystemSuccessSoundPlayer
  private let updateController: UpdateController

  init() {
    let settingsStore = UserDefaultsSettingsStore()
    let shortcutStore = KeyboardShortcutsStore()
    let launchAtLoginService: any LaunchAtLoginServicing
    let permissionService: any ScreenCapturePermissionService
    let selectionService: any RegionSelectionService
    let screenCaptureService: any ScreenCaptureService
    let barcodeService: any BarcodeRecognitionService
    let updateService: any UpdateServicing

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
        ? DebugRegionSelectionService(arguments: arguments)
        : AppKitRegionSelectionService()
      screenCaptureService =
        runtimeOptions.usesDebugCaptureService
        ? DebugScreenCaptureService()
        : SystemScreenCaptureService()
      updateService =
        runtimeOptions.isUITesting
        ? DebugUpdateService()
        : SparkleUpdateService()
      barcodeService =
        runtimeOptions.isUITesting
        ? DebugBarcodeRecognitionService(arguments: arguments)
        : VisionBarcodeService()
    #else
      launchAtLoginService = SystemLaunchAtLoginService()
      permissionService = SystemScreenCapturePermissionService(historyStore: settingsStore)
      selectionService = AppKitRegionSelectionService()
      screenCaptureService = SystemScreenCaptureService()
      barcodeService = VisionBarcodeService()
      updateService = SparkleUpdateService()
    #endif

    let updateController = UpdateController(service: updateService)
    self.updateController = updateController
    updateController.start()

    settingsController = SettingsController(
      settingsStore: settingsStore,
      launchAtLoginService: launchAtLoginService,
      shortcutStore: shortcutStore
    )
    let coordinator = CaptureCoordinator()
    let feedbackController = FeedbackPanelController()
    self.feedbackController = feedbackController
    let successSoundPlayer = SystemSuccessSoundPlayer(preferences: settingsStore)
    self.successSoundPlayer = successSoundPlayer
    let recoveryController = PermissionRecoveryPanelController(
      permissionService: permissionService
    )
    let captureCommand = CaptureCommand(
      coordinator: coordinator,
      permissionService: permissionService,
      selectionService: selectionService,
      screenCaptureService: screenCaptureService,
      ocrService: VisionOCRService(),
      textAssembler: TextAssembler(),
      barcodeService: barcodeService,
      codePayloadAssembler: CodePayloadAssembler(),
      clipboardService: SystemClipboardService(),
      successSoundPlayer: successSoundPlayer,
      feedbackService: feedbackController,
      recoveryPresenter: recoveryController
    )
    recoveryController.captureRequester = captureCommand
    commandHandler = MenuBarCommandHandler(
      captureCommand: captureCommand,
      applicationTerminator: SystemApplicationTerminator()
    )
    let globalShortcutController = GlobalShortcutController(
      captureCommand: captureCommand,
      eventSource: SystemGlobalShortcutEventSource()
    )
    self.globalShortcutController = globalShortcutController
    let lifecycleController = ApplicationLifecycleController(
      eventSource: SystemApplicationLifecycleEventSource(),
      captureCanceller: captureCommand,
      recoveryPresenter: recoveryController,
      stopShortcutDelivery: { [weak globalShortcutController] in
        globalShortcutController?.stop()
      },
      logger: SystemCaptureLifecycleLogger()
    )
    self.lifecycleController = lifecycleController
    globalShortcutController.start()
    lifecycleController.start()
  }

  var body: some Scene {
    MenuBarExtra {
      MenuBarMenuView(
        commandHandler: commandHandler,
        updateController: updateController
      )
    } label: {
      MenuBarLabelView(
        settingsController: settingsController,
        feedbackModel: feedbackController.model
      )
    }
    .menuBarExtraStyle(.menu)
    .commands {
      CopyLassoApplicationCommands()
    }

    Settings {
      SettingsView(
        settingsController: settingsController,
        updateController: updateController,
        metadata: AboutMetadata(bundle: .main)
      )
    }
    .defaultSize(width: 520, height: 680)

    Window("Welcome to CopyLasso", id: "onboarding") {
      OnboardingView(settingsController: settingsController)
    }
    .windowResizability(.contentSize)

    Window("About CopyLasso", id: "about") {
      AboutView(
        metadata: AboutMetadata(bundle: .main),
        applicationIconSource: .application
      )
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

private struct CopyLassoApplicationCommands: Commands {
  @Environment(\.openWindow) private var openWindow

  var body: some Commands {
    CommandGroup(replacing: .appInfo) {
      Button("About CopyLasso") {
        openWindow(id: "about")
      }
    }
  }
}
