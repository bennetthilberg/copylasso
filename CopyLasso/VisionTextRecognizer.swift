import CoreGraphics
import ImageIO
import Vision

struct VisionTextObservation: Equatable, Sendable {
  let text: String
  let confidence: Float
  let boundingBox: CGRect
}

struct VisionTextRecognizer: Sendable {
  struct Configuration: Equatable, Sendable {
    let usesLanguageCorrection: Bool

    static let englishAccurate = Configuration(usesLanguageCorrection: true)
  }

  typealias Performer =
    @Sendable (
      _ image: CGImage,
      _ orientation: CGImagePropertyOrientation,
      _ configuration: Configuration
    ) throws -> [VisionTextObservation]

  private let configuration: Configuration
  private let performer: Performer

  init(configuration: Configuration = .englishAccurate) {
    self.configuration = configuration
    self.performer = Self.performRecognition
  }

  init(
    configuration: Configuration = .englishAccurate,
    performer: @escaping Performer
  ) {
    self.configuration = configuration
    self.performer = performer
  }

  func recognize(
    _ image: CGImage,
    orientation: CGImagePropertyOrientation = .up
  ) async throws -> [VisionTextObservation] {
    let configuration = configuration
    let performer = performer

    return try await Task.detached(priority: .userInitiated) {
      try performer(image, orientation, configuration)
    }.value
  }

  private static func performRecognition(
    image: CGImage,
    orientation: CGImagePropertyOrientation,
    configuration: Configuration
  ) throws -> [VisionTextObservation] {
    let request = VNRecognizeTextRequest()
    request.revision = VNRecognizeTextRequestRevision3
    request.recognitionLevel = .accurate
    request.recognitionLanguages = ["en-US"]
    request.automaticallyDetectsLanguage = false
    request.usesLanguageCorrection = configuration.usesLanguageCorrection
    request.minimumTextHeight = 0

    let handler = VNImageRequestHandler(
      cgImage: image,
      orientation: orientation,
      options: [:]
    )
    try handler.perform([request])

    return (request.results ?? []).compactMap { observation in
      guard let candidate = observation.topCandidates(1).first else {
        return nil
      }

      return VisionTextObservation(
        text: candidate.string,
        confidence: candidate.confidence,
        boundingBox: observation.boundingBox
      )
    }
  }
}
