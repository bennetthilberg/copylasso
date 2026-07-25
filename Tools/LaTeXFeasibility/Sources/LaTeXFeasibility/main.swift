import Darwin
import Foundation
import LaTeXFeasibilityCore

@main
struct LaTeXFeasibilityCommand {
  static func main() throws {
    var arguments = CommandLine.arguments.dropFirst()
    guard let command = arguments.popFirst() else {
      throw CommandError.usage
    }

    switch command {
    case "validate-corpus":
      guard
        let corpusPath = arguments.popFirst(),
        let imageRootPath = arguments.popFirst(),
        arguments.isEmpty
      else {
        throw CommandError.usage
      }
      let corpus: EvaluationCorpus = try decode(corpusPath)
      let summary = try CorpusValidator.validate(corpus)
      try CorpusValidator.validateImages(
        for: corpus,
        under: URL(fileURLWithPath: imageRootPath, isDirectory: true)
      )
      try writeJSON(summary)
    case "score":
      guard
        let corpusPath = arguments.popFirst(),
        let imageRootPath = arguments.popFirst(),
        let labelsPath = arguments.popFirst(),
        let freezePath = arguments.popFirst(),
        let protocolPath = arguments.popFirst(),
        let modelPath = arguments.popFirst(),
        let configurationPath = arguments.popFirst(),
        let preprocessingPath = arguments.popFirst(),
        let decoderPath = arguments.popFirst(),
        let evidencePath = arguments.popFirst(),
        arguments.isEmpty
      else {
        throw CommandError.usage
      }
      let corpusData = try read(corpusPath)
      let labelsData = try read(labelsPath)
      let protocolData = try read(protocolPath)
      let corpus = try JSONDecoder().decode(EvaluationCorpus.self, from: corpusData)
      try CorpusValidator.validateImages(
        for: corpus,
        under: URL(fileURLWithPath: imageRootPath, isDirectory: true)
      )
      let executableURL =
        URL(fileURLWithPath: CommandLine.arguments[0])
        .resolvingSymlinksInPath()
        .standardizedFileURL
      let report = try CandidateGateEvaluator.evaluate(
        corpus: corpus,
        labels: try JSONDecoder().decode([EvaluationLabel].self, from: labelsData),
        freeze: try decode(freezePath),
        binding: VerifiedInputDigests(
          corpusManifestSHA256: ArtifactDigest.sha256(corpusData),
          sealedLabelsSHA256: ArtifactDigest.sha256(labelsData),
          scorerSHA256: try ArtifactDigest.sha256(fileURL: executableURL),
          protocolSHA256: ArtifactDigest.sha256(protocolData),
          modelSHA256: try ArtifactDigest.sha256(
            fileURL: URL(fileURLWithPath: modelPath)
          ),
          configurationSHA256: try ArtifactDigest.sha256(
            fileURL: URL(fileURLWithPath: configurationPath)
          ),
          preprocessingSHA256: try ArtifactDigest.sha256(
            fileURL: URL(fileURLWithPath: preprocessingPath)
          ),
          decoderSHA256: try ArtifactDigest.sha256(
            fileURL: URL(fileURLWithPath: decoderPath)
          )
        ),
        evidence: try decode(evidencePath)
      )
      try writeJSON(report)
      if !report.passed {
        exit(2)
      }
    default:
      throw CommandError.usage
    }
  }

  private static func decode<Value: Decodable>(_ path: String) throws -> Value {
    try JSONDecoder().decode(Value.self, from: read(path))
  }

  private static func read(_ path: String) throws -> Data {
    try Data(contentsOf: URL(fileURLWithPath: path), options: [.mappedIfSafe])
  }

  private static func writeJSON<Value: Encodable>(_ value: Value) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let data = try encoder.encode(value)
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data([0x0A]))
  }
}

private enum CommandError: Error, CustomStringConvertible {
  case usage

  var description: String {
    """
    Usage:
      latex-feasibility validate-corpus <corpus.json> <image-root>
      latex-feasibility score <corpus.json> <image-root> <labels.json> <freeze.json> <protocol.json> <model> <configuration> <preprocessing> <decoder> <evidence.json>
    """
  }
}
