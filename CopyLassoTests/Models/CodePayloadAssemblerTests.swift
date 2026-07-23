import CoreGraphics
import XCTest

@testable import CopyLasso

final class CodePayloadAssemblerTests: XCTestCase {
  private let assembler = CodePayloadAssembler()

  func testNoEligibleObservationsProducesNoCode() {
    XCTAssertEqual(
      assembler.assemble([
        observation(payload: nil, symbology: .qr, x: 0.1, y: 0.8),
        observation(payload: "", symbology: .code128, x: 0.3, y: 0.8),
        observation(
          payload: "unsupported",
          symbology: .unsupported("fixture"),
          x: 0.5,
          y: 0.8
        ),
        observation(
          payload: "malformed",
          symbology: .qr,
          bounds: CGRect(x: .nan, y: 0.2, width: 0.2, height: 0.2)
        ),
        observation(
          payload: "malformed-y",
          symbology: .qr,
          bounds: CGRect(x: 0.2, y: .infinity, width: 0.2, height: 0.2)
        ),
        observation(
          payload: "malformed-width",
          symbology: .qr,
          bounds: CGRect(x: 0.2, y: 0.2, width: .nan, height: 0.2)
        ),
        observation(
          payload: "malformed-height",
          symbology: .qr,
          bounds: CGRect(x: 0.2, y: 0.2, width: 0.2, height: .infinity)
        ),
        observation(
          payload: "zero-width",
          symbology: .qr,
          bounds: CGRect(x: 0.2, y: 0.2, width: 0, height: 0.2)
        ),
        observation(
          payload: "zero-height",
          symbology: .qr,
          bounds: CGRect(x: 0.2, y: 0.2, width: 0.2, height: 0)
        ),
      ]),
      .noCode
    )
  }

  func testSinglePayloadIsPreservedExactlyIncludingWhitespaceAndLineBreaks() {
    let payload = "  first line\r\nsecond\tline  "

    XCTAssertEqual(
      assembler.assemble([
        observation(payload: payload, symbology: .qr, x: 0.2, y: 0.6)
      ]),
      .content(payload)
    )
  }

  func testVisualRowsSortTopToBottomAndLeftToRight() {
    XCTAssertEqual(
      assembler.assemble([
        observation(payload: "bottom", symbology: .aztec, x: 0.2, y: 0.15),
        observation(payload: "top-right", symbology: .dataMatrix, x: 0.65, y: 0.72),
        observation(payload: "top-left", symbology: .pdf417, x: 0.1, y: 0.7),
      ]),
      .content("top-left\ntop-right\nbottom")
    )
  }

  func testExactDuplicatesAreRemovedAfterVisualOrdering() {
    XCTAssertEqual(
      assembler.assemble([
        observation(payload: "duplicate", symbology: .qr, x: 0.7, y: 0.2),
        observation(payload: "middle", symbology: .code128, x: 0.4, y: 0.5),
        observation(payload: "duplicate", symbology: .aztec, x: 0.1, y: 0.8),
      ]),
      .content("duplicate\nmiddle")
    )
  }

  func testDuplicateMultilinePayloadBecomesOneExactResultBeforeAmbiguityDecision() {
    let payload = "line one\nline two"

    XCTAssertEqual(
      assembler.assemble([
        observation(payload: payload, symbology: .qr, x: 0.1, y: 0.8),
        observation(payload: payload, symbology: .dataMatrix, x: 0.1, y: 0.2),
      ]),
      .content(payload)
    )
  }

  func testMultipleUniquePayloadsWithAnyLineBreakAreAmbiguous() {
    XCTAssertEqual(
      assembler.assemble([
        observation(payload: "first", symbology: .code128, x: 0.1, y: 0.8),
        observation(payload: "second\rvalue", symbology: .qr, x: 0.1, y: 0.2),
      ]),
      .ambiguous
    )
  }

  func testOrderingIsStableAcrossInputPermutationsAndExactGeometryTies() {
    let observations = [
      observation(payload: "charlie", symbology: .qr, x: 0.2, y: 0.6),
      observation(payload: "alpha", symbology: .aztec, x: 0.2, y: 0.6),
      observation(payload: "bravo", symbology: .pdf417, x: 0.2, y: 0.6),
    ]

    let expected = CodePayloadAssemblyResult.content("alpha\nbravo\ncharlie")
    XCTAssertEqual(assembler.assemble(observations), expected)
    XCTAssertEqual(assembler.assemble(observations.reversed()), expected)
    XCTAssertEqual(
      assembler.assemble([observations[1], observations[2], observations[0]]),
      expected
    )
  }

  func testCandidateTieBreakersCoverSymbologyConfidenceNaNAndGeometryBits() {
    let observations = [
      observation(
        payload: "same",
        symbology: .qr,
        confidence: .nan,
        bounds: CGRect(x: -0.0, y: 0.5, width: 0.25, height: 0.25)
      ),
      observation(
        payload: "same",
        symbology: .aztec,
        confidence: 0.8,
        bounds: CGRect(x: 0.0, y: 0.5, width: 0.375, height: 0.25)
      ),
      observation(
        payload: "same",
        symbology: .qr,
        confidence: 0.9,
        bounds: CGRect(x: 0.0, y: 0.375, width: 0.3125, height: 0.375)
      ),
      observation(
        payload: "same",
        symbology: .qr,
        confidence: 0.8,
        bounds: CGRect(x: 0.0, y: 0.25, width: 0.25, height: 0.5)
      ),
    ]

    XCTAssertEqual(assembler.assemble(observations), .content("same"))
    XCTAssertEqual(assembler.assemble(observations.reversed()), .content("same"))
  }

  func testWithinRowTieBreakersRemainStableAcrossEveryComparisonLevel() {
    let observations = [
      observation(
        payload: "bravo",
        symbology: .qr,
        confidence: 0.9,
        bounds: CGRect(x: 0.25, y: 0.5, width: 0.25, height: 0.25)
      ),
      observation(
        payload: "alpha",
        symbology: .qr,
        confidence: 0.9,
        bounds: CGRect(x: 0.25, y: 0.625, width: 0.25, height: 0.125)
      ),
      observation(
        payload: "duplicate",
        symbology: .qr,
        confidence: 0.9,
        bounds: CGRect(x: 0.25, y: 0.5, width: 0.25, height: 0.25)
      ),
      observation(
        payload: "duplicate",
        symbology: .aztec,
        confidence: 0.9,
        bounds: CGRect(x: 0.25, y: 0.5, width: 0.375, height: 0.25)
      ),
      observation(
        payload: "duplicate",
        symbology: .aztec,
        confidence: 0.8,
        bounds: CGRect(x: 0.25, y: 0.375, width: 0.5, height: 0.375)
      ),
    ]

    let expected = CodePayloadAssemblyResult.content("alpha\nbravo\nduplicate")
    XCTAssertEqual(assembler.assemble(observations), expected)
    XCTAssertEqual(assembler.assemble(observations.reversed()), expected)
  }

  private func observation(
    payload: String?,
    symbology: CodeSymbology,
    x: CGFloat,
    y: CGFloat
  ) -> RecognizedCodeObservation {
    observation(
      payload: payload,
      symbology: symbology,
      bounds: CGRect(x: x, y: y, width: 0.2, height: 0.2)
    )
  }

  private func observation(
    payload: String?,
    symbology: CodeSymbology,
    bounds: CGRect
  ) -> RecognizedCodeObservation {
    observation(payload: payload, symbology: symbology, confidence: 0.9, bounds: bounds)
  }

  private func observation(
    payload: String?,
    symbology: CodeSymbology,
    confidence: Float,
    bounds: CGRect
  ) -> RecognizedCodeObservation {
    RecognizedCodeObservation(
      payload: payload,
      symbology: symbology,
      confidence: confidence,
      boundingBox: bounds
    )
  }
}
