import CoreGraphics
import Foundation
import Vision

struct VisionBarcodeConfiguration: Equatable, Sendable {
  let revision: Int
  let symbologies: [CodeSymbology]

  var visionSymbologies: [VNBarcodeSymbology] {
    symbologies.compactMap(\.visionSymbology)
  }

  static let copyLasso = VisionBarcodeConfiguration(
    revision: VNDetectBarcodesRequestRevision3,
    symbologies: [.qr, .code128, .dataMatrix, .pdf417, .aztec]
  )
}

enum VisionBarcodeError: Error, Equatable, Sendable {
  case cancelled
  case recognitionFailed
}

typealias VisionBarcodeCancellation = VisionOCRCancellation

protocol BarcodeRecognitionService: Sendable {
  func recognizeCodes(in image: CGImage) async throws -> [RecognizedCodeObservation]
}

struct VisionBarcodeService: BarcodeRecognitionService {
  typealias Performer =
    @Sendable (
      _ image: CGImage,
      _ configuration: VisionBarcodeConfiguration,
      _ cancellation: VisionBarcodeCancellation
    ) throws -> [RecognizedCodeObservation]

  private let configuration: VisionBarcodeConfiguration
  private let performer: Performer

  init(configuration: VisionBarcodeConfiguration = .copyLasso) {
    self.configuration = configuration
    self.performer = Self.performRecognition
  }

  init(
    configuration: VisionBarcodeConfiguration = .copyLasso,
    performer: @escaping Performer
  ) {
    self.configuration = configuration
    self.performer = performer
  }

  func recognizeCodes(in image: CGImage) async throws -> [RecognizedCodeObservation] {
    let configuration = configuration
    let performer = performer
    let cancellation = VisionBarcodeCancellation()

    do {
      return try await withTaskCancellationHandler {
        try await Task.detached(priority: .userInitiated) {
          guard !cancellation.isCancelled else {
            throw VisionBarcodeError.cancelled
          }
          do {
            let observations = try performer(image, configuration, cancellation)
            guard !cancellation.isCancelled else {
              throw VisionBarcodeError.cancelled
            }
            return observations
          } catch {
            if cancellation.isCancelled {
              throw VisionBarcodeError.cancelled
            }
            throw error
          }
        }.value
      } onCancel: {
        cancellation.cancel()
      }
    } catch let error as VisionBarcodeError {
      throw error
    } catch is CancellationError {
      throw VisionBarcodeError.cancelled
    } catch {
      throw VisionBarcodeError.recognitionFailed
    }
  }

  private static func performRecognition(
    image: CGImage,
    configuration: VisionBarcodeConfiguration,
    cancellation: VisionBarcodeCancellation
  ) throws -> [RecognizedCodeObservation] {
    let request = VNDetectBarcodesRequest()
    request.revision = configuration.revision
    request.symbologies = configuration.visionSymbologies

    guard cancellation.install(request) else {
      throw VisionBarcodeError.cancelled
    }
    defer { cancellation.clear(request) }

    let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
    do {
      try handler.perform([request])
    } catch {
      if cancellation.isCancelled {
        throw VisionBarcodeError.cancelled
      }
      throw error
    }

    guard !cancellation.isCancelled else {
      throw VisionBarcodeError.cancelled
    }
    return (request.results ?? []).map { observation in
      RecognizedCodeObservation(
        payload: observation.payloadStringValue,
        symbology: CodeSymbology(visionSymbology: observation.symbology),
        confidence: observation.confidence,
        boundingBox: observation.boundingBox
      )
    }
  }
}

extension CodeSymbology {
  fileprivate var visionSymbology: VNBarcodeSymbology? {
    switch self {
    case .qr:
      .qr
    case .code128:
      .code128
    case .dataMatrix:
      .dataMatrix
    case .pdf417:
      .pdf417
    case .aztec:
      .aztec
    case .unsupported:
      nil
    }
  }

  fileprivate init(visionSymbology: VNBarcodeSymbology) {
    switch visionSymbology {
    case .qr:
      self = .qr
    case .code128:
      self = .code128
    case .dataMatrix:
      self = .dataMatrix
    case .pdf417:
      self = .pdf417
    case .aztec:
      self = .aztec
    default:
      self = .unsupported(visionSymbology.rawValue)
    }
  }
}
