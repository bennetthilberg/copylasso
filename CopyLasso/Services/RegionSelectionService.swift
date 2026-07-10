@MainActor
protocol RegionSelectionService: AnyObject {
  func selectRegion() async throws -> SelectionOutcome
  func cancelSelection()
}
