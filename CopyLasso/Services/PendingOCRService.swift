import CoreGraphics

enum PendingOCRError: Error, Equatable, Sendable {
  case unavailableUntilG15
}

actor PendingOCRService: OCRService {
  func recognizeText(in image: CGImage) async throws -> [RecognizedTextObservation] {
    throw PendingOCRError.unavailableUntilG15
  }
}
