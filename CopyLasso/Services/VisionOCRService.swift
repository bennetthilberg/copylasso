import CoreGraphics
import CoreML
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

  static let englishAccurate = VisionOCRConfiguration(
    revision: VNRecognizeTextRequestRevision3,
    recognitionLevel: .accurate,
    recognitionLanguages: ["en-US"],
    automaticallyDetectsLanguage: false,
    usesLanguageCorrection: true
  )

  static func recognition(
    preferences: OCRRecognitionPreferences
  ) -> VisionOCRConfiguration {
    VisionOCRConfiguration(
      revision: VNRecognizeTextRequestRevision3,
      recognitionLevel: .accurate,
      recognitionLanguages: preferences.languageIdentifiers,
      automaticallyDetectsLanguage: preferences.automaticallyDetectsLanguage,
      usesLanguageCorrection: true
    )
  }
}

enum VisionOCRError: Error, Equatable, Sendable {
  case cancelled
  case recognitionFailed
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
    self.performer = { image, configuration, cancellation in
      try Self.performRecognition(
        image: image, configuration: configuration, cancellation: cancellation
      )
    }
  }

  init(
    configuration: VisionOCRConfiguration = .englishAccurate,
    performer: @escaping Performer
  ) {
    self.configuration = configuration
    self.performer = performer
  }

  func recognizeText(in image: CGImage) async throws -> [RecognizedTextObservation] {
    try await recognizeText(in: image, configuration: configuration)
  }

  func recognizeText(
    in image: CGImage,
    preferences: OCRRecognitionPreferences
  ) async throws -> [RecognizedTextObservation] {
    try await recognizeText(
      in: image,
      configuration: .recognition(preferences: preferences)
    )
  }

  private func recognizeText(
    in image: CGImage,
    configuration: VisionOCRConfiguration
  ) async throws -> [RecognizedTextObservation] {
    let performer = performer
    let cancellation = VisionOCRCancellation()

    do {
      return try await withTaskCancellationHandler {
        try await Task.detached(priority: .userInitiated) {
          guard !cancellation.isCancelled else {
            throw VisionOCRError.cancelled
          }
          do {
            let observations = try performer(image, configuration, cancellation)
            guard !cancellation.isCancelled else {
              throw VisionOCRError.cancelled
            }
            return observations
          } catch {
            if cancellation.isCancelled {
              throw VisionOCRError.cancelled
            }
            throw error
          }
        }.value
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

  static func performRecognition(
    image: CGImage,
    configuration: VisionOCRConfiguration,
    cancellation: VisionOCRCancellation,
    requestPerformer: @Sendable (CGImage, VNRecognizeTextRequest) throws -> Void = {
      image, request in
      try VNImageRequestHandler(cgImage: image, orientation: .up, options: [:]).perform([request])
    },
    supportedComputeDevices:
      @Sendable (VNRecognizeTextRequest) throws -> [VNComputeStage: [MLComputeDevice]] = {
        try $0.supportedComputeStageDevices
      }
  ) throws -> [RecognizedTextObservation] {
    var request = makeRequest(configuration: configuration)
    do {
      try perform(request, image: image, cancellation: cancellation, using: requestPerformer)
    } catch {
      guard !cancellation.isCancelled else {
        throw VisionOCRError.cancelled
      }
      guard canRetryOnCPU(error) else { throw error }

      // A request can retain failed engine state. Retry with a fresh request and
      // only devices Vision reports as supported for this exact configuration.
      let retry = makeRequest(configuration: configuration)
      let supported = try? supportedComputeDevices(retry)
      guard !cancellation.isCancelled else {
        throw VisionOCRError.cancelled
      }
      guard let supported, !supported.isEmpty else { throw error }
      for (stage, devices) in supported {
        guard
          let cpu = devices.first(where: {
            if case .cpu = $0 { return true }
            return false
          })
        else { throw error }
        retry.setComputeDevice(cpu, for: stage)
      }
      try perform(retry, image: image, cancellation: cancellation, using: requestPerformer)
      request = retry
    }

    guard !cancellation.isCancelled else {
      throw VisionOCRError.cancelled
    }
    return (request.results ?? []).compactMap { observation in
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

  private static func canRetryOnCPU(_ error: Error) -> Bool {
    let error = error as NSError
    guard error.domain == VNErrorDomain else { return false }
    switch error.code {
    case VNErrorCode.operationFailed.rawValue, VNErrorCode.internalError.rawValue,
      VNErrorCode.unsupportedComputeDevice.rawValue:
      return true
    default:
      return false
    }
  }

  private static func makeRequest(configuration: VisionOCRConfiguration) -> VNRecognizeTextRequest {
    let request = VNRecognizeTextRequest()
    request.revision = configuration.revision
    switch configuration.recognitionLevel {
    case .accurate:
      request.recognitionLevel = .accurate
    }
    request.recognitionLanguages = configuration.recognitionLanguages
    request.automaticallyDetectsLanguage = configuration.automaticallyDetectsLanguage
    request.usesLanguageCorrection = configuration.usesLanguageCorrection
    request.minimumTextHeight = 0
    return request
  }

  private static func perform(
    _ request: VNRecognizeTextRequest,
    image: CGImage,
    cancellation: VisionOCRCancellation,
    using requestPerformer: @Sendable (CGImage, VNRecognizeTextRequest) throws -> Void
  ) throws {
    guard cancellation.install(request) else {
      throw VisionOCRError.cancelled
    }
    defer { cancellation.clear(request) }

    do {
      try requestPerformer(image, request)
    } catch {
      if cancellation.isCancelled {
        throw VisionOCRError.cancelled
      }
      throw error
    }

    guard !cancellation.isCancelled else {
      throw VisionOCRError.cancelled
    }
  }
}
