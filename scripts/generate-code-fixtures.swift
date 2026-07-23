#!/usr/bin/env xcrun swift
import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

enum CodeFixtureGenerationError: Error {
  case descriptorCreationFailed
  case filterCreationFailed(String)
  case imageCreationFailed(String)
  case imageEncodingFailed(String)
}

struct CodeFixture {
  let filename: String
  let payload: String
  let filter: () throws -> CIImage
}

let outputDirectory: URL = {
  if CommandLine.arguments.count > 1 {
    return URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
  }
  return URL(fileURLWithPath: "CopyLassoTests/Fixtures", isDirectory: true)
}()

try FileManager.default.createDirectory(
  at: outputDirectory,
  withIntermediateDirectories: true
)

func generatedImage(
  filterName: String,
  parameters: [String: Any]
) throws -> CIImage {
  guard
    let filter = CIFilter(name: filterName, parameters: parameters),
    let outputImage = filter.outputImage
  else {
    throw CodeFixtureGenerationError.filterCreationFailed(filterName)
  }
  return outputImage
}

func reedSolomonECC200(data: [UInt8], count: Int) -> [UInt8] {
  let factors: [UInt8]
  switch count {
  case 5:
    factors = [228, 48, 15, 111, 62]
  case 7:
    factors = [23, 68, 144, 134, 240, 92, 254]
  default:
    preconditionFailure("Unsupported Data Matrix ECC 200 factor set")
  }
  var exponents = Array(repeating: UInt8(0), count: 255)
  var logarithms = Array(repeating: UInt8(0), count: 256)
  var value = 1
  for index in 0..<255 {
    exponents[index] = UInt8(value)
    logarithms[value] = UInt8(index)
    value <<= 1
    if value & 0x100 != 0 {
      value ^= 0x12D
    }
  }
  func multiply(_ lhs: UInt8, _ rhs: UInt8) -> UInt8 {
    guard lhs != 0, rhs != 0 else {
      return 0
    }
    let exponent = (Int(logarithms[Int(lhs)]) + Int(logarithms[Int(rhs)])) % 255
    return exponents[exponent]
  }

  var ecc = Array(repeating: UInt8(0), count: count)
  for codeword in data {
    let factor = ecc[count - 1] ^ codeword
    for index in stride(from: count - 1, through: 1, by: -1) {
      if factor != 0, factors[index] != 0 {
        ecc[index] = ecc[index - 1] ^ multiply(factor, factors[index])
      } else {
        ecc[index] = ecc[index - 1]
      }
    }
    ecc[0] = factor == 0 ? 0 : multiply(factor, factors[0])
  }
  return Array(ecc.reversed())
}

func dataMatrixImage(payload: String) throws -> CIImage {
  precondition(payload == "DM", "The fixture encoder is intentionally scoped to DM")
  let encoded: [UInt8] = [69, 78, 129]
  let errorCorrected = encoded + reedSolomonECC200(data: encoded, count: 5)
  precondition(
    errorCorrected == [69, 78, 129, 217, 160, 67, 156, 213],
    "The project-authored ECC 200 encoder must remain deterministic"
  )
  let rows = [
    "1010101010",
    "1010010111",
    "1001100010",
    "1110100011",
    "1001000000",
    "1100011101",
    "1001101010",
    "1111010101",
    "1000001110",
    "1111111111",
  ]
  guard
    let context = CGContext(
      data: nil,
      width: 10,
      height: 10,
      bitsPerComponent: 8,
      bytesPerRow: 0,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )
  else {
    throw CodeFixtureGenerationError.imageCreationFailed("code-data-matrix.png")
  }
  context.setFillColor(CGColor(gray: 1, alpha: 1))
  context.fill(CGRect(x: 0, y: 0, width: 10, height: 10))
  context.setFillColor(CGColor(gray: 0, alpha: 1))
  for (rowIndex, row) in rows.enumerated() {
    for (columnIndex, module) in row.enumerated() where module == "1" {
      context.fill(
        CGRect(
          x: CGFloat(columnIndex),
          y: CGFloat(9 - rowIndex),
          width: 1,
          height: 1
        )
      )
    }
  }
  guard let image = context.makeImage() else {
    throw CodeFixtureGenerationError.imageCreationFailed("code-data-matrix.png")
  }
  return CIImage(cgImage: image)
}

let fixtures = [
  CodeFixture(
    filename: "code-qr.png",
    payload: "https://copylasso.com/g38?mode=qr"
  ) {
    try generatedImage(
      filterName: "CIQRCodeGenerator",
      parameters: [
        "inputMessage": Data("https://copylasso.com/g38?mode=qr".utf8),
        "inputCorrectionLevel": "H",
      ]
    )
  },
  CodeFixture(
    filename: "code-code128.png",
    payload: "COPYLASSO-CODE128"
  ) {
    try generatedImage(
      filterName: "CICode128BarcodeGenerator",
      parameters: [
        "inputMessage": Data("COPYLASSO-CODE128".utf8),
        "inputQuietSpace": 7,
      ]
    )
  },
  CodeFixture(
    filename: "code-data-matrix.png",
    payload: "DM"
  ) {
    try dataMatrixImage(payload: "DM")
  },
  CodeFixture(
    filename: "code-pdf417.png",
    payload: "COPYLASSO PDF417"
  ) {
    try generatedImage(
      filterName: "CIPDF417BarcodeGenerator",
      parameters: [
        "inputMessage": Data("COPYLASSO PDF417".utf8),
        "inputCorrectionLevel": 4,
      ]
    )
  },
  CodeFixture(
    filename: "code-aztec.png",
    payload: "COPYLASSO AZTEC"
  ) {
    try generatedImage(
      filterName: "CIAztecCodeGenerator",
      parameters: [
        "inputMessage": Data("COPYLASSO AZTEC".utf8),
        "inputCorrectionLevel": 35,
      ]
    )
  },
]

let coreImageContext = CIContext(options: [.useSoftwareRenderer: true])

func writeFixture(_ fixture: CodeFixture) throws {
  let generated = try fixture.filter()
  guard
    let barcode = coreImageContext.createCGImage(generated, from: generated.extent)
  else {
    throw CodeFixtureGenerationError.imageCreationFailed(fixture.filename)
  }

  let canvasWidth = fixture.filename == "code-code128.png" ? 900 : 640
  let canvasHeight = fixture.filename == "code-code128.png" ? 360 : 640
  guard
    let canvas = CGContext(
      data: nil,
      width: canvasWidth,
      height: canvasHeight,
      bitsPerComponent: 8,
      bytesPerRow: 0,
      space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )
  else {
    throw CodeFixtureGenerationError.imageCreationFailed(fixture.filename)
  }

  canvas.setFillColor(CGColor(gray: 1, alpha: 1))
  canvas.fill(CGRect(x: 0, y: 0, width: canvasWidth, height: canvasHeight))
  canvas.interpolationQuality = .none

  let availableWidth = canvasWidth - 96
  let availableHeight = canvasHeight - 96
  let integerScale = max(
    1,
    min(availableWidth / barcode.width, availableHeight / barcode.height)
  )
  let renderWidth = barcode.width * integerScale
  let renderHeight = barcode.height * integerScale
  canvas.draw(
    barcode,
    in: CGRect(
      x: (canvasWidth - renderWidth) / 2,
      y: (canvasHeight - renderHeight) / 2,
      width: renderWidth,
      height: renderHeight
    )
  )

  guard
    let image = canvas.makeImage(),
    let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:])
  else {
    throw CodeFixtureGenerationError.imageEncodingFailed(fixture.filename)
  }
  try data.write(
    to: outputDirectory.appendingPathComponent(fixture.filename),
    options: .atomic
  )
}

for fixture in fixtures {
  try writeFixture(fixture)
}
