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
    case "validate-protocol":
      guard let protocolPath = arguments.popFirst(), arguments.isEmpty else {
        throw CommandError.usage
      }
      try ProtocolValidator.validateSupported(read(protocolPath))
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
        let artifactManifestPath = arguments.popFirst(),
        let artifactRootPath = arguments.popFirst(),
        let evidencePath = arguments.popFirst(),
        arguments.isEmpty
      else {
        throw CommandError.usage
      }
      let corpusData = try read(corpusPath)
      let labelsData = try read(labelsPath)
      let protocolData = try read(protocolPath)
      let artifactManifestData = try read(artifactManifestPath)
      let corpus = try JSONDecoder().decode(EvaluationCorpus.self, from: corpusData)
      let freeze: EvaluationFreeze = try decode(freezePath)
      try ProtocolValidator.validateSupported(protocolData)
      try CorpusValidator.validateImages(
        for: corpus,
        under: URL(fileURLWithPath: imageRootPath, isDirectory: true)
      )
      try ArtifactManifestValidator.validate(
        try JSONDecoder().decode(
          CandidateArtifactManifest.self,
          from: artifactManifestData
        ),
        runtimeKind: freeze.candidate.runtimeKind,
        under: URL(fileURLWithPath: artifactRootPath, isDirectory: true)
      )
      let executableURL = try currentExecutableURL()
      let report = try CandidateGateEvaluator.evaluate(
        corpus: corpus,
        labels: try JSONDecoder().decode([EvaluationLabel].self, from: labelsData),
        freeze: freeze,
        binding: VerifiedInputDigests(
          corpusManifestSHA256: ArtifactDigest.sha256(corpusData),
          sealedLabelsSHA256: ArtifactDigest.sha256(labelsData),
          scorerSHA256: try ArtifactDigest.sha256(fileURL: executableURL),
          protocolSHA256: ArtifactDigest.sha256(protocolData),
          artifactManifestSHA256: ArtifactDigest.sha256(artifactManifestData)
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

  private static func currentExecutableURL() throws -> URL {
    var bufferSize: UInt32 = 0
    _ = _NSGetExecutablePath(nil, &bufferSize)
    guard bufferSize > 0 else {
      throw CommandError.executablePathUnavailable
    }
    var buffer = [CChar](repeating: 0, count: Int(bufferSize))
    guard _NSGetExecutablePath(&buffer, &bufferSize) == 0 else {
      throw CommandError.executablePathUnavailable
    }
    let path = String(
      decoding: buffer.prefix(while: { $0 != 0 }).map { UInt8(bitPattern: $0) },
      as: UTF8.self
    )
    guard !path.isEmpty else {
      throw CommandError.executablePathUnavailable
    }
    return URL(fileURLWithPath: path)
      .resolvingSymlinksInPath()
      .standardizedFileURL
  }
}

private enum CommandError: Error, CustomStringConvertible {
  case executablePathUnavailable
  case usage

  var description: String {
    switch self {
    case .executablePathUnavailable:
      "The scorer executable path is unavailable."
    case .usage:
      """
      Usage:
        latex-feasibility validate-protocol <protocol.json>
        latex-feasibility validate-corpus <corpus.json> <image-root>
        latex-feasibility score <corpus.json> <image-root> <labels.json> <freeze.json> <protocol.json> <artifact-manifest.json> <artifact-root> <evidence.json>
      """
    }
  }
}
