import CoreGraphics

protocol OCRService: Sendable {
  func recognizeText(in image: CGImage) async throws -> [RecognizedTextObservation]
  func recognizeText(
    in image: CGImage,
    preferences: OCRRecognitionPreferences
  ) async throws -> [RecognizedTextObservation]
}

extension OCRService {
  func recognizeText(
    in image: CGImage,
    preferences _: OCRRecognitionPreferences
  ) async throws -> [RecognizedTextObservation] {
    try await recognizeText(in: image)
  }
}
