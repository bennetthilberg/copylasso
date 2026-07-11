enum PendingRegionSelectionError: Error, Equatable, Sendable {
  case unavailableUntilG13
}

@MainActor
final class PendingRegionSelectionService: RegionSelectionService {
  func selectRegion() async throws -> SelectionOutcome {
    throw PendingRegionSelectionError.unavailableUntilG13
  }

  func cancelSelection() {}
}
