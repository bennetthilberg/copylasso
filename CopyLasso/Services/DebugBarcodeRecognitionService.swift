#if DEBUG
  import CoreGraphics
  import Foundation

  actor DebugBarcodeRecognitionService: BarcodeRecognitionService {
    private let result: Result<[RecognizedCodeObservation], VisionBarcodeError>

    init(arguments: [String]) {
      switch arguments.first(where: { $0.hasPrefix("--g38-code-result=") })?
        .split(separator: "=", maxSplits: 1).last
      {
      case "success":
        result = .success([
          RecognizedCodeObservation(
            payload: "COPYLASSO UI CODE",
            symbology: .qr,
            confidence: 1,
            boundingBox: CGRect(x: 0.2, y: 0.2, width: 0.6, height: 0.6)
          )
        ])
      case "ambiguous":
        result = .success([
          RecognizedCodeObservation(
            payload: "FIRST\nLINE",
            symbology: .qr,
            confidence: 1,
            boundingBox: CGRect(x: 0.1, y: 0.6, width: 0.3, height: 0.3)
          ),
          RecognizedCodeObservation(
            payload: "SECOND",
            symbology: .code128,
            confidence: 1,
            boundingBox: CGRect(x: 0.6, y: 0.1, width: 0.3, height: 0.3)
          ),
        ])
      case "failure":
        result = .failure(.recognitionFailed)
      default:
        result = .success([])
      }
    }

    func recognizeCodes(in image: CGImage) async throws -> [RecognizedCodeObservation] {
      try result.get()
    }
  }
#endif
