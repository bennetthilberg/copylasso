@MainActor
protocol RegionSelectionService: AnyObject {
  func prepareForSelectionTransition()
  func selectRegion() async throws -> SelectionOutcome
  func cancelSelection()
}

extension RegionSelectionService {
  func prepareForSelectionTransition() {}
}
