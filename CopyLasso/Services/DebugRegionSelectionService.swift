#if DEBUG
  @MainActor
  final class DebugRegionSelectionService: RegionSelectionService {
    private let outcome: SelectionOutcome

    init(outcome: SelectionOutcome = .cancelled(.escape)) {
      self.outcome = outcome
    }

    func selectRegion() async throws -> SelectionOutcome {
      outcome
    }

    func cancelSelection() {}
  }
#endif
