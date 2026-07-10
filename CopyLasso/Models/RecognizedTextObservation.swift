import CoreGraphics

struct RecognizedTextObservation: Equatable, Sendable {
  let text: String
  let confidence: Float
  let boundingBox: CGRect
}
