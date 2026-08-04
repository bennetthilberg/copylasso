import CoreGraphics
import Foundation
import ImageIO
import Vision

enum VisionOCRRecognitionLevel: Equatable, Sendable {
  case accurate
}

struct VisionOCRConfiguration: Equatable, Sendable {
  let revision: Int
  let recognitionLevel: VisionOCRRecognitionLevel
  let recognitionLanguages: [String]
  let automaticallyDetectsLanguage: Bool
  let usesLanguageCorrection: Bool
  let minimumTextHeight: Float
  let maximumObservationCount: Int
  let maximumRecognizedTextLength: Int
  let recognitionTimeout: Duration

  static let englishAccurate = VisionOCRConfiguration(
    revision: VNRecognizeTextRequestRevision3,
    recognitionLevel: .accurate,
    recognitionLanguages: ["en-US"],
    automaticallyDetectsLanguage: false,
    usesLanguageCorrection: true,
    minimumTextHeight: 0.01,
    maximumObservationCount: 500,
    maximumRecognizedTextLength: 20_000,
    recognitionTimeout: .seconds(8)
  )
}

enum VisionOCRError: Error, Equatable, Sendable {
  case cancelled
  case recognitionFailed
  case timedOut
}

protocol VisionRequestCancelling: AnyObject {
  func cancel()
}

extension VNRequest: VisionRequestCancelling {}

final class VisionOCRCancellation: @unchecked Sendable {
  private let lock = NSLock()
  private var activeRequest: (any VisionRequestCancelling)?
  private var cancellationRequested = false

  var isCancelled: Bool {
    lock.withLock { cancellationRequested }
  }

  @discardableResult
  func install(_ request: any VisionRequestCancelling) -> Bool {
    let shouldCancel = lock.withLock {
      if cancellationRequested {
        return true
      }
      activeRequest = request
      return false
    }
    if shouldCancel {
      request.cancel()
      return false
    }
    return true
  }

  func clear(_ request: any VisionRequestCancelling) {
    lock.withLock {
      if activeRequest === request {
        activeRequest = nil
      }
    }
  }

  func cancel() {
    let request = lock.withLock {
      guard !cancellationRequested else {
        return Optional<any VisionRequestCancelling>.none
      }
      cancellationRequested = true
      let request = activeRequest
      activeRequest = nil
      return request
    }
    request?.cancel()
  }
}

struct VisionOCRService: OCRService {
  typealias Performer =
    @Sendable (
      _ image: CGImage,
      _ configuration: VisionOCRConfiguration,
      _ cancellation: VisionOCRCancellation
    ) throws -> [RecognizedTextObservation]

  private let configuration: VisionOCRConfiguration
  private let performer: Performer

  init(configuration: VisionOCRConfiguration = .englishAccurate) {
    self.configuration = configuration
    self.performer = Self.performRecognition
  }

  init(
    configuration: VisionOCRConfiguration = .englishAccurate,
    performer: @escaping Performer
  ) {
    self.configuration = configuration
    self.performer = performer
  }

  func recognizeText(in image: CGImage) async throws -> [RecognizedTextObservation] {
    let configuration = configuration
    let performer = performer
    let cancellation = VisionOCRCancellation()

    do {
      return try await withTaskCancellationHandler {
        try await withThrowingTaskGroup(of: [RecognizedTextObservation].self) { group in
          let recognitionTask = Task.detached(priority: .userInitiated) {
            guard !cancellation.isCancelled else {
              throw VisionOCRError.cancelled
            }
            do {
              let observations = try performer(image, configuration, cancellation)
              guard !cancellation.isCancelled else {
                throw VisionOCRError.cancelled
              }
              return Self.limitedObservations(observations, configuration: configuration)
            } catch {
              if cancellation.isCancelled {
                throw VisionOCRError.cancelled
              }
              throw error
            }
          }

          group.addTask {
            defer { recognitionTask.cancel() }
            return try await recognitionTask.value
          }
          group.addTask {
            try await Task.sleep(for: configuration.recognitionTimeout)
            cancellation.cancel()
            recognitionTask.cancel()
            throw VisionOCRError.timedOut
          }

          let observations = try await group.next() ?? []
          group.cancelAll()
          return observations
        }
      } onCancel: {
        cancellation.cancel()
      }
    } catch let error as VisionOCRError {
      throw error
    } catch is CancellationError {
      throw VisionOCRError.cancelled
    } catch {
      throw VisionOCRError.recognitionFailed
    }
  }

  private static func performRecognition(
    image: CGImage,
    configuration: VisionOCRConfiguration,
    cancellation: VisionOCRCancellation
  ) throws -> [RecognizedTextObservation] {
    let request = VNRecognizeTextRequest()
    request.revision = configuration.revision
    switch configuration.recognitionLevel {
    case .accurate:
      request.recognitionLevel = .accurate
    }
    request.recognitionLanguages = configuration.recognitionLanguages
    request.automaticallyDetectsLanguage = configuration.automaticallyDetectsLanguage
    request.usesLanguageCorrection = configuration.usesLanguageCorrection
    request.minimumTextHeight = configuration.minimumTextHeight

    guard cancellation.install(request) else {
      throw VisionOCRError.cancelled
    }
    defer { cancellation.clear(request) }

    let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
    do {
      try handler.perform([request])
    } catch {
      if cancellation.isCancelled {
        throw VisionOCRError.cancelled
      }
      throw error
    }

    guard !cancellation.isCancelled else {
      throw VisionOCRError.cancelled
    }
    return limitedObservations(
      request.results ?? [],
      configuration: configuration
    ) { observation in
      guard let candidate = observation.topCandidates(1).first else {
        return nil
      }
      return RecognizedTextObservation(
        text: candidate.string,
        confidence: candidate.confidence,
        boundingBox: observation.boundingBox
      )
    }
  }

  private static func limitedObservations(
    _ observations: [RecognizedTextObservation],
    configuration: VisionOCRConfiguration
  ) -> [RecognizedTextObservation] {
    limitedObservations(observations, configuration: configuration) { $0 }
  }

  private static func limitedObservations<Observation>(
    _ observations: [Observation],
    configuration: VisionOCRConfiguration,
    transform: (Observation) -> RecognizedTextObservation?
  ) -> [RecognizedTextObservation] {
    var limited: [RecognizedTextObservation] = []
    limited.reserveCapacity(min(observations.count, configuration.maximumObservationCount))
    var remainingTextLength = configuration.maximumRecognizedTextLength

    for observation in observations {
      guard limited.count < configuration.maximumObservationCount, remainingTextLength > 0 else {
        break
      }
      guard var recognized = transform(observation) else {
        continue
      }
      if recognized.text.count > remainingTextLength {
        recognized = RecognizedTextObservation(
          text: String(recognized.text.prefix(remainingTextLength)),
          confidence: recognized.confidence,
          boundingBox: recognized.boundingBox
        )
      }
      remainingTextLength -= recognized.text.count
      limited.append(recognized)
    }
    return limited
  }
}
