@MainActor
protocol ClipboardService: AnyObject {
  func writePlainText(_ text: String) throws
}
