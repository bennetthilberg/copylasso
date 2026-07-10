import CoreGraphics

protocol OCRService: Sendable {
  func recognizeText(in image: CGImage) async throws -> [RecognizedTextObservation]
}
