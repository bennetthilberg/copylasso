import CoreGraphics

enum CodeSymbology: Equatable, Hashable, Sendable {
  case qr
  case code128
  case dataMatrix
  case pdf417
  case aztec
  case unsupported(String)

  var isSupported: Bool {
    switch self {
    case .qr, .code128, .dataMatrix, .pdf417, .aztec:
      true
    case .unsupported:
      false
    }
  }

  var stableName: String {
    switch self {
    case .qr:
      "qr"
    case .code128:
      "code128"
    case .dataMatrix:
      "data-matrix"
    case .pdf417:
      "pdf417"
    case .aztec:
      "aztec"
    case .unsupported(let name):
      "unsupported:\(name)"
    }
  }
}

struct RecognizedCodeObservation: Equatable, Sendable {
  let payload: String?
  let symbology: CodeSymbology
  let confidence: Float
  let boundingBox: CGRect
}
