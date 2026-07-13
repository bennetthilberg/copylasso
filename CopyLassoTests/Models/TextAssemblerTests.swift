import CoreGraphics
import XCTest

@testable import CopyLasso

final class TextAssemblerTests: XCTestCase {
  private struct LayoutCase {
    let name: String
    let observations: [RecognizedTextObservation]
    let expected: String
  }

  func testParameterizedOrdinaryLayouts() {
    let cases = [
      LayoutCase(name: "empty", observations: [], expected: ""),
      LayoutCase(
        name: "whitespace only",
        observations: [observation(" \n\t ", x: 0.1, y: 0.8)],
        expected: ""
      ),
      LayoutCase(
        name: "one line unordered words",
        observations: [
          observation("world", x: 0.32, y: 0.8),
          observation("Hello", x: 0.08, y: 0.8),
        ],
        expected: "Hello world"
      ),
      LayoutCase(
        name: "internal whitespace normalized",
        observations: [observation("  hello\n\tworld  ", x: 0.1, y: 0.8)],
        expected: "hello world"
      ),
      LayoutCase(
        name: "multiple lines",
        observations: [
          observation("Bottom line", x: 0.1, y: 0.70, height: 0.06),
          observation("Top line", x: 0.1, y: 0.80, height: 0.06),
        ],
        expected: "Top line\nBottom line"
      ),
      LayoutCase(
        name: "uneven baseline words",
        observations: [
          observation("baseline", x: 0.28, y: 0.78, height: 0.08),
          observation("Uneven", x: 0.05, y: 0.80, height: 0.06),
        ],
        expected: "Uneven baseline"
      ),
      LayoutCase(
        name: "two vertically separated blocks",
        observations: [
          observation("Second paragraph", x: 0.08, y: 0.30, height: 0.06),
          observation("First paragraph line two", x: 0.08, y: 0.70, height: 0.06),
          observation("First paragraph line one", x: 0.08, y: 0.80, height: 0.06),
        ],
        expected: "First paragraph line one\nFirst paragraph line two\n\nSecond paragraph"
      ),
      LayoutCase(
        name: "literal plain text",
        observations: [observation("**bold**   <b>tag</b>", x: 0.1, y: 0.8)],
        expected: "**bold** <b>tag</b>"
      ),
    ]

    let assembler = TextAssembler()
    for layout in cases {
      XCTAssertEqual(
        assembler.assemble(layout.observations),
        layout.expected,
        "Layout: \(layout.name)"
      )
    }
  }

  func testExactDuplicateDetectionIsEmittedOnce() {
    let bounds = CGRect(x: 0.1, y: 0.8, width: 0.2, height: 0.06)
    let observations = [
      RecognizedTextObservation(text: "duplicate", confidence: 0.3, boundingBox: bounds),
      RecognizedTextObservation(text: " duplicate ", confidence: 0.9, boundingBox: bounds),
      RecognizedTextObservation(text: "duplicate", confidence: 0.7, boundingBox: bounds),
    ]

    XCTAssertEqual(TextAssembler().assemble(observations), "duplicate")
  }

  func testRepeatedTextAtDifferentPositionsIsPreserved() {
    let observations = [
      observation("echo", x: 0.1, y: 0.8),
      observation("echo", x: 0.4, y: 0.8),
    ]

    XCTAssertEqual(TextAssembler().assemble(observations), "echo echo")
  }

  func testLowConfidenceNonemptyTextIsNeverSilentlyDropped() {
    let observations = [
      observation("certain", confidence: 0.99, x: 0.1, y: 0.8),
      observation("uncertain", confidence: 0.01, x: 0.4, y: 0.8),
    ]

    XCTAssertEqual(TextAssembler().assemble(observations), "certain uncertain")
  }

  func testEveryHighConfidenceObservationAppearsExactlyOnce() {
    let observations = (0..<20).map { index in
      observation(
        "item-\(index)",
        confidence: 0.99,
        x: Double(index % 4) * 0.2,
        y: 0.9 - (Double(index / 4) * 0.12)
      )
    }

    let output = TextAssembler().assemble(observations)
    let outputItems = output.split(whereSeparator: \.isWhitespace).map(String.init)
    for index in 0..<20 {
      XCTAssertEqual(outputItems.filter { $0 == "item-\(index)" }.count, 1)
    }
  }

  func testUnsupportedMultiColumnLayoutIsDeterministicAcrossInputOrder() {
    let observations = [
      observation("Left top", x: 0.05, y: 0.82),
      observation("Right top", x: 0.58, y: 0.82),
      observation("Left bottom", x: 0.05, y: 0.68),
      observation("Right bottom", x: 0.58, y: 0.68),
    ]
    let assembler = TextAssembler()
    let expected = "Left top Right top\nLeft bottom Right bottom"

    XCTAssertEqual(assembler.assemble(observations), expected)
    XCTAssertEqual(assembler.assemble(Array(observations.reversed())), expected)
    XCTAssertEqual(
      assembler.assemble([observations[2], observations[0], observations[3], observations[1]]),
      expected
    )
  }

  func testInvalidAndZeroGeometryFailGracefullyWithoutDroppingText() {
    let observations = [
      observation("valid", x: 0.1, y: 0.8),
      RecognizedTextObservation(
        text: "zero",
        confidence: 0.9,
        boundingBox: .zero
      ),
      RecognizedTextObservation(
        text: "nan",
        confidence: 0.9,
        boundingBox: CGRect(x: .nan, y: 0, width: 0.1, height: 0.1)
      ),
    ]

    XCTAssertEqual(TextAssembler().assemble(observations), "valid\n\nnan\nzero")
  }

  func testSlightOverlapBelowLineThresholdProducesSeparateLines() {
    let observations = [
      observation("upper", x: 0.1, y: 0.80, height: 0.10),
      observation("lower", x: 0.1, y: 0.72, height: 0.10),
    ]

    XCTAssertEqual(TextAssembler().assemble(observations), "upper\nlower")
  }

  func testProjectFixtureLayoutsProduceExpectedPlainTextWithoutVision() {
    let cleanFixture = [
      observation("Process all text offline", x: 0.1, y: 0.56),
      observation("Read every visible line", x: 0.1, y: 0.84),
      observation("Keep the original order", x: 0.1, y: 0.70),
    ]
    let appFixture = [
      observation("Save Changes", x: 0.1, y: 0.40),
      observation("Recognition stays on this Mac", x: 0.1, y: 0.54),
      observation("CopyLasso Settings", x: 0.1, y: 0.82),
      observation("Capture text from any screen", x: 0.1, y: 0.68),
    ]
    let assembler = TextAssembler()

    XCTAssertEqual(
      assembler.assemble(cleanFixture),
      "Read every visible line\nKeep the original order\nProcess all text offline"
    )
    XCTAssertEqual(
      assembler.assemble(appFixture),
      "CopyLasso Settings\nCapture text from any screen\nRecognition stays on this Mac\nSave Changes"
    )
  }

  private func observation(
    _ text: String,
    confidence: Float = 0.9,
    x: Double,
    y: Double,
    width: Double = 0.18,
    height: Double = 0.06
  ) -> RecognizedTextObservation {
    RecognizedTextObservation(
      text: text,
      confidence: confidence,
      boundingBox: CGRect(x: x, y: y, width: width, height: height)
    )
  }
}
