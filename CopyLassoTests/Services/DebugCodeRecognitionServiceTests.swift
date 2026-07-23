#if DEBUG
  import CoreGraphics
  import XCTest

  @testable import CopyLasso

  final class DebugCodeRecognitionServiceTests: XCTestCase {
    func testDebugBarcodeResultsCoverEverySignedUIOutcome() async throws {
      let image = try XCTUnwrap(Self.makeImage())

      let success = try await DebugBarcodeRecognitionService(
        arguments: ["--g38-code-result=success"]
      ).recognizeCodes(in: image)
      XCTAssertEqual(success.map(\.payload), ["COPYLASSO UI CODE"])

      let noCode = try await DebugBarcodeRecognitionService(
        arguments: ["--g38-code-result=no-code"]
      ).recognizeCodes(in: image)
      XCTAssertTrue(noCode.isEmpty)

      let ambiguous = try await DebugBarcodeRecognitionService(
        arguments: ["--g38-code-result=ambiguous"]
      ).recognizeCodes(in: image)
      XCTAssertEqual(ambiguous.map(\.payload), ["FIRST\nLINE", "SECOND"])

      do {
        _ = try await DebugBarcodeRecognitionService(
          arguments: ["--g38-code-result=failure"]
        ).recognizeCodes(in: image)
        XCTFail("Expected the deterministic UI failure")
      } catch {
        XCTAssertEqual(error as? VisionBarcodeError, .recognitionFailed)
      }
    }

    @MainActor
    func testDebugSelectionArgumentsPreserveCancellationAndEnableSelectedFlow() async throws {
      let cancelled = try await DebugRegionSelectionService(arguments: []).selectRegion()
      XCTAssertEqual(cancelled, .cancelled(.escape))

      let selected = try await DebugRegionSelectionService(
        arguments: ["--g38-selection=selected"]
      ).selectRegion()
      guard case .selected(let selection) = selected else {
        return XCTFail("Expected deterministic selected geometry")
      }
      XCTAssertEqual(selection.backingPixelRect, CGRect(x: 100, y: 400, width: 100, height: 100))
    }

    private static func makeImage() -> CGImage? {
      CGContext(
        data: nil,
        width: 1,
        height: 1,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )?.makeImage()
    }
  }
#endif
