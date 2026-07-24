#if DEBUG
  import CoreGraphics

  @MainActor
  final class DebugRegionSelectionService: RegionSelectionService {
    private let outcome: SelectionOutcome

    init(outcome: SelectionOutcome = .cancelled(.escape)) {
      self.outcome = outcome
    }

    convenience init(arguments: [String]) {
      guard arguments.contains("--g38-selection=selected") else {
        self.init()
        return
      }
      self.init(
        outcome: .selected(
          SelectionResult(
            displayID: 1,
            displayPointSize: CGSize(width: 800, height: 600),
            appKitGlobalRect: CGRect(x: 100, y: 100, width: 100, height: 100),
            displayLocalRect: CGRect(x: 100, y: 100, width: 100, height: 100),
            coreGraphicsGlobalRect: CGRect(x: 100, y: 400, width: 100, height: 100),
            coreGraphicsDisplayLocalRect: CGRect(
              x: 100,
              y: 400,
              width: 100,
              height: 100
            ),
            backingPixelRect: CGRect(x: 100, y: 400, width: 100, height: 100),
            backingScale: 1
          )
        )
      )
    }

    func selectRegion() async throws -> SelectionOutcome {
      outcome
    }

    func cancelSelection() {}
  }
#endif
