import CryptoKit
import Foundation

public enum MathSampleClass: String, Codable, CaseIterable, Hashable, Sendable {
  case cleanCommon = "clean_common"
  case inline
  case display
  case fractions
  case roots
  case superscripts
  case subscripts
  case greekSymbols = "greek_symbols"
  case operators
  case delimiters
  case alignedEquations = "aligned_equations"
  case matrices
  case degraded
  case lowResolution = "low_resolution"

  public static let requiredPositiveClasses = allCases
}

public enum EvaluationSampleKind: String, Codable, Sendable {
  case positive
  case negative
}

public struct EvaluationSample: Codable, Equatable, Sendable {
  public var id: String
  public var relativeImagePath: String
  public var imageSHA256: String
  public var kind: EvaluationSampleKind
  public var classes: [MathSampleClass]

  public init(
    id: String,
    relativeImagePath: String,
    imageSHA256: String,
    kind: EvaluationSampleKind,
    classes: [MathSampleClass]
  ) {
    self.id = id
    self.relativeImagePath = relativeImagePath
    self.imageSHA256 = imageSHA256
    self.kind = kind
    self.classes = classes
  }
}

public struct EvaluationCorpus: Codable, Equatable, Sendable {
  public var schemaVersion: Int
  public var samples: [EvaluationSample]

  public init(schemaVersion: Int, samples: [EvaluationSample]) {
    self.schemaVersion = schemaVersion
    self.samples = samples
  }
}

public struct CorpusSummary: Codable, Equatable, Sendable {
  public let sampleCount: Int
  public let positiveCount: Int
  public let negativeCount: Int
  public let classCounts: [String: Int]
}

public enum CandidateRuntimeKind: String, Codable, Sendable {
  case coreML = "core_ml"
  case reference
  case nonCoreML = "non_core_ml"
}

public struct CandidateDesignFreeze: Codable, Equatable, Sendable {
  public var id: String
  public var runtimeKind: CandidateRuntimeKind
  public var modelSHA256: String
  public var configurationSHA256: String
  public var preprocessingSHA256: String
  public var decoderSHA256: String

  public init(
    id: String,
    runtimeKind: CandidateRuntimeKind,
    modelSHA256: String,
    configurationSHA256: String,
    preprocessingSHA256: String,
    decoderSHA256: String
  ) {
    self.id = id
    self.runtimeKind = runtimeKind
    self.modelSHA256 = modelSHA256
    self.configurationSHA256 = configurationSHA256
    self.preprocessingSHA256 = preprocessingSHA256
    self.decoderSHA256 = decoderSHA256
  }
}

public struct EvaluationFreeze: Codable, Equatable, Sendable {
  public var schemaVersion: Int
  public var corpusManifestSHA256: String
  public var sealedLabelsSHA256: String
  public var scorerSHA256: String
  public var protocolSHA256: String
  public var candidate: CandidateDesignFreeze

  public init(
    schemaVersion: Int,
    corpusManifestSHA256: String,
    sealedLabelsSHA256: String,
    scorerSHA256: String,
    protocolSHA256: String,
    candidate: CandidateDesignFreeze
  ) {
    self.schemaVersion = schemaVersion
    self.corpusManifestSHA256 = corpusManifestSHA256
    self.sealedLabelsSHA256 = sealedLabelsSHA256
    self.scorerSHA256 = scorerSHA256
    self.protocolSHA256 = protocolSHA256
    self.candidate = candidate
  }
}

public struct VerifiedInputDigests: Codable, Equatable, Sendable {
  public var corpusManifestSHA256: String
  public var sealedLabelsSHA256: String
  public var scorerSHA256: String
  public var protocolSHA256: String
  public var modelSHA256: String
  public var configurationSHA256: String
  public var preprocessingSHA256: String
  public var decoderSHA256: String

  public init(
    corpusManifestSHA256: String,
    sealedLabelsSHA256: String,
    scorerSHA256: String,
    protocolSHA256: String,
    modelSHA256: String,
    configurationSHA256: String,
    preprocessingSHA256: String,
    decoderSHA256: String
  ) {
    self.corpusManifestSHA256 = corpusManifestSHA256
    self.sealedLabelsSHA256 = sealedLabelsSHA256
    self.scorerSHA256 = scorerSHA256
    self.protocolSHA256 = protocolSHA256
    self.modelSHA256 = modelSHA256
    self.configurationSHA256 = configurationSHA256
    self.preprocessingSHA256 = preprocessingSHA256
    self.decoderSHA256 = decoderSHA256
  }
}

public struct EvaluationLabel: Codable, Equatable, Sendable {
  public var id: String
  public var expectedLaTeX: String?
  public var acceptedStructuralForms: [String]

  public init(
    id: String,
    expectedLaTeX: String?,
    acceptedStructuralForms: [String]
  ) {
    self.id = id
    self.expectedLaTeX = expectedLaTeX
    self.acceptedStructuralForms = acceptedStructuralForms
  }
}

public enum BenchmarkArchitecture: String, Codable, CaseIterable, Sendable {
  case arm64
  case x8664 = "x86_64"
}

public struct BenchmarkEnvironment: Codable, Equatable, Sendable {
  public var hardwareModel: String
  public var memoryBytes: Int
  public var macOSVersion: String
  public var onACPower: Bool
  public var lowPowerModeEnabled: Bool
  public var thermalPressureNominal: Bool
  public var qualifyingPerformanceHardware: Bool
  public var warmupCount: Int

  public init(
    hardwareModel: String,
    memoryBytes: Int,
    macOSVersion: String,
    onACPower: Bool,
    lowPowerModeEnabled: Bool,
    thermalPressureNominal: Bool,
    qualifyingPerformanceHardware: Bool,
    warmupCount: Int
  ) {
    self.hardwareModel = hardwareModel
    self.memoryBytes = memoryBytes
    self.macOSVersion = macOSVersion
    self.onACPower = onACPower
    self.lowPowerModeEnabled = lowPowerModeEnabled
    self.thermalPressureNominal = thermalPressureNominal
    self.qualifyingPerformanceHardware = qualifyingPerformanceHardware
    self.warmupCount = warmupCount
  }
}

public struct SampleMeasurement: Codable, Equatable, Sendable {
  public var id: String
  public var output: String?
  public var warmLatencyMilliseconds: Double

  public init(id: String, output: String?, warmLatencyMilliseconds: Double) {
    self.id = id
    self.output = output
    self.warmLatencyMilliseconds = warmLatencyMilliseconds
  }
}

public struct ArchitectureRun: Codable, Equatable, Sendable {
  public var candidateID: String
  public var modelSHA256: String
  public var configurationSHA256: String
  public var preprocessingSHA256: String
  public var decoderSHA256: String
  public var architecture: BenchmarkArchitecture
  public var environment: BenchmarkEnvironment
  public var coldLoadMilliseconds: Double
  public var baselinePeakResidentBytes: Int
  public var peakResidentBytes: Int
  public var samples: [SampleMeasurement]

  public init(
    candidateID: String,
    modelSHA256: String,
    configurationSHA256: String,
    preprocessingSHA256: String,
    decoderSHA256: String,
    architecture: BenchmarkArchitecture,
    environment: BenchmarkEnvironment,
    coldLoadMilliseconds: Double,
    baselinePeakResidentBytes: Int,
    peakResidentBytes: Int,
    samples: [SampleMeasurement]
  ) {
    self.candidateID = candidateID
    self.modelSHA256 = modelSHA256
    self.configurationSHA256 = configurationSHA256
    self.preprocessingSHA256 = preprocessingSHA256
    self.decoderSHA256 = decoderSHA256
    self.architecture = architecture
    self.environment = environment
    self.coldLoadMilliseconds = coldLoadMilliseconds
    self.baselinePeakResidentBytes = baselinePeakResidentBytes
    self.peakResidentBytes = peakResidentBytes
    self.samples = samples
  }
}

public struct CandidateEvidence: Codable, Equatable, Sendable {
  public var schemaVersion: Int
  public var candidateID: String
  public var installedSizeGrowthBytes: Int
  public var licenseIsRedistributable: Bool
  public var provenanceIsReproducible: Bool
  public var networkingDeniedRecognitionPassed: Bool
  public var persistedUserContent: Bool
  public var hasCloudFallback: Bool
  public var hasAnalyticsOrTelemetry: Bool
  public var supportsMacOS14: Bool
  public var isUniversal2Deployable: Bool
  public var sandboxCompatible: Bool
  public var runs: [ArchitectureRun]

  public init(
    schemaVersion: Int,
    candidateID: String,
    installedSizeGrowthBytes: Int,
    licenseIsRedistributable: Bool,
    provenanceIsReproducible: Bool,
    networkingDeniedRecognitionPassed: Bool,
    persistedUserContent: Bool,
    hasCloudFallback: Bool,
    hasAnalyticsOrTelemetry: Bool,
    supportsMacOS14: Bool,
    isUniversal2Deployable: Bool,
    sandboxCompatible: Bool,
    runs: [ArchitectureRun]
  ) {
    self.schemaVersion = schemaVersion
    self.candidateID = candidateID
    self.installedSizeGrowthBytes = installedSizeGrowthBytes
    self.licenseIsRedistributable = licenseIsRedistributable
    self.provenanceIsReproducible = provenanceIsReproducible
    self.networkingDeniedRecognitionPassed = networkingDeniedRecognitionPassed
    self.persistedUserContent = persistedUserContent
    self.hasCloudFallback = hasCloudFallback
    self.hasAnalyticsOrTelemetry = hasAnalyticsOrTelemetry
    self.supportsMacOS14 = supportsMacOS14
    self.isUniversal2Deployable = isUniversal2Deployable
    self.sandboxCompatible = sandboxCompatible
    self.runs = runs
  }
}

public struct ClassAccuracyMetrics: Codable, Equatable, Sendable {
  public let sampleCount: Int
  public let normalizedExactMatches: Int
  public let normalizedExactRate: Double
}

public struct AccuracyMetrics: Codable, Equatable, Sendable {
  public let positiveCount: Int
  public let normalizedExactMatches: Int
  public let overallExactRate: Double
  public let cleanCommonCount: Int
  public let cleanStructuralMatches: Int
  public let cleanStructuralRate: Double
  public let negativeCount: Int
  public let negativeFalseSuccesses: Int
  public let negativeFalseSuccessRate: Double
  public let classes: [String: ClassAccuracyMetrics]
}

public struct ArchitectureGateReport: Codable, Equatable, Sendable {
  public let architecture: BenchmarkArchitecture
  public let accuracy: AccuracyMetrics
  public let measurementCount: Int
  public let warmP50Milliseconds: Double
  public let warmP95Milliseconds: Double
  public let coldLoadMilliseconds: Double
  public let addedPeakMemoryBytes: Int
}

public struct CandidateGateReport: Codable, Equatable, Sendable {
  public let candidateID: String
  public let freeze: EvaluationFreeze
  public let passed: Bool
  public let failures: [String]
  public let installedSizeGrowthBytes: Int
  public let architectureReports: [ArchitectureGateReport]
}

public struct PairedAccuracyImprovement: Codable, Equatable, Sendable {
  public var architecture: BenchmarkArchitecture
  public var metric: String
  public var improvement: Double
  public var lower95ConfidenceBound: Double
  public var upper95ConfidenceBound: Double

  public init(
    architecture: BenchmarkArchitecture,
    metric: String,
    improvement: Double,
    lower95ConfidenceBound: Double,
    upper95ConfidenceBound: Double
  ) {
    self.architecture = architecture
    self.metric = metric
    self.improvement = improvement
    self.lower95ConfidenceBound = lower95ConfidenceBound
    self.upper95ConfidenceBound = upper95ConfidenceBound
  }
}

public enum RuntimeRecommendation: String, Codable, Equatable, Sendable {
  case coreML = "core_ml"
  case nonCoreML = "non_core_ml"
  case none
}

public struct RuntimeComparisonReport: Codable, Equatable, Sendable {
  public let coreMLPassesEveryAbsoluteGate: Bool
  public let challengerPassesEveryAbsoluteGate: Bool
  public let hasMeaningfulLatencyWin: Bool
  public let hasMeaningfulAccuracyWin: Bool
  public let recommendedRuntime: RuntimeRecommendation
}

public enum FeasibilityValidationError: Error, Equatable, Sendable {
  case unsupportedSchemaVersion(Int)
  case insufficientTotalSamples(actual: Int)
  case insufficientPositiveSamples(actual: Int)
  case insufficientNegativeSamples(actual: Int)
  case insufficientClassSamples(sampleClass: MathSampleClass, actual: Int)
  case emptySampleID
  case duplicateSampleID(String)
  case invalidSHA256(field: String)
  case duplicateImageDigest(String)
  case invalidRelativeImagePath(String)
  case missingImage(String)
  case imageDigestMismatch(String)
  case positiveSampleHasNoMathClass(String)
  case negativeSampleHasMathClasses(String)
  case emptyCandidateID
  case inputDigestMismatch(field: String)
  case labelIDsDoNotMatchCorpus
  case duplicateLabelID(String)
  case positiveLabelIsEmpty(String)
  case positiveLabelHasNoStructuralForms(String)
  case negativeLabelHasExpectedOutput(String)
  case negativeLabelHasStructuralForms(String)
  case unknownCandidateID(String)
  case mixedCandidateDesigns
  case duplicateArchitecture(BenchmarkArchitecture)
  case missingArchitecture(BenchmarkArchitecture)
  case invalidEnvironment(BenchmarkArchitecture)
  case invalidColdLoad(BenchmarkArchitecture)
  case invalidMemoryMeasurement(BenchmarkArchitecture)
  case duplicateResultID(String)
  case resultIDsDoNotMatchCorpus(BenchmarkArchitecture)
  case emptyLatencySeries
  case invalidLatency
  case invalidInstalledSize
  case invalidComparison
}

extension FeasibilityValidationError: CustomStringConvertible {
  public var description: String {
    switch self {
    case .unsupportedSchemaVersion(let version):
      "Unsupported schema version: \(version)"
    case .insufficientTotalSamples(let actual):
      "Evaluation corpus has \(actual) samples; at least 300 are required."
    case .insufficientPositiveSamples(let actual):
      "Evaluation corpus has \(actual) positive samples; at least 200 are required."
    case .insufficientNegativeSamples(let actual):
      "Evaluation corpus has \(actual) negative samples; at least 100 are required."
    case .insufficientClassSamples(let sampleClass, let actual):
      "Evaluation class \(sampleClass.rawValue) has only \(actual) samples."
    case .emptySampleID:
      "A corpus sample has an empty identifier."
    case .duplicateSampleID(let id):
      "Duplicate corpus sample identifier: \(id)"
    case .invalidSHA256(let field):
      "Invalid SHA-256 value for \(field)."
    case .duplicateImageDigest(let digest):
      "Duplicate corpus image digest: \(digest)"
    case .invalidRelativeImagePath(let path):
      "Corpus image path is unsafe or not relative: \(path)"
    case .missingImage(let id):
      "Corpus image is missing or not a regular file: \(id)"
    case .imageDigestMismatch(let id):
      "Corpus image digest does not match the manifest: \(id)"
    case .positiveSampleHasNoMathClass(let id):
      "Positive sample has no math class: \(id)"
    case .negativeSampleHasMathClasses(let id):
      "Negative sample declares a math class: \(id)"
    case .emptyCandidateID:
      "A candidate design has an empty identifier."
    case .inputDigestMismatch(let field):
      "A frozen input digest does not match the supplied bytes: \(field)"
    case .labelIDsDoNotMatchCorpus:
      "Revealed label identifiers do not exactly match the corpus."
    case .duplicateLabelID(let id):
      "Duplicate label identifier: \(id)"
    case .positiveLabelIsEmpty(let id):
      "Positive label is empty: \(id)"
    case .positiveLabelHasNoStructuralForms(let id):
      "Positive label has no accepted structural form: \(id)"
    case .negativeLabelHasExpectedOutput(let id):
      "Negative label has expected LaTeX: \(id)"
    case .negativeLabelHasStructuralForms(let id):
      "Negative label has accepted structural forms: \(id)"
    case .unknownCandidateID(let id):
      "Evidence references an unknown candidate: \(id)"
    case .mixedCandidateDesigns:
      "Evidence mixes candidate design identifiers or digests."
    case .duplicateArchitecture(let architecture):
      "Evidence contains duplicate architecture \(architecture.rawValue)."
    case .missingArchitecture(let architecture):
      "Evidence is missing architecture \(architecture.rawValue)."
    case .invalidEnvironment(let architecture):
      "Evidence has an invalid environment for \(architecture.rawValue)."
    case .invalidColdLoad(let architecture):
      "Evidence has an invalid cold-load measurement for \(architecture.rawValue)."
    case .invalidMemoryMeasurement(let architecture):
      "Evidence has an invalid memory measurement for \(architecture.rawValue)."
    case .duplicateResultID(let id):
      "Duplicate sample result identifier: \(id)"
    case .resultIDsDoNotMatchCorpus(let architecture):
      "Result identifiers do not match the corpus for \(architecture.rawValue)."
    case .emptyLatencySeries:
      "A latency series is empty."
    case .invalidLatency:
      "A latency measurement is negative or non-finite."
    case .invalidInstalledSize:
      "Installed-size growth must be nonnegative."
    case .invalidComparison:
      "Runtime comparison inputs are incomplete, duplicated, or non-finite."
    }
  }
}

public enum LaTeXNormalizer {
  public static func normalize(_ value: String?) -> String? {
    guard var value else { return nil }
    value = value.precomposedStringWithCanonicalMapping
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else { return nil }

    let delimiterPairs = [
      ("$$", "$$"),
      (#"\["#, #"\]"#),
      (#"\("#, #"\)"#),
      ("$", "$"),
    ]
    for (prefix, suffix) in delimiterPairs
    where value.hasPrefix(prefix)
      && value.hasSuffix(suffix)
      && value.count >= prefix.count + suffix.count
    {
      value.removeFirst(prefix.count)
      value.removeLast(suffix.count)
      value = value.trimmingCharacters(in: .whitespacesAndNewlines)
      break
    }

    value =
      value
      .components(separatedBy: .whitespacesAndNewlines)
      .filter { !$0.isEmpty }
      .joined(separator: " ")
    return value.isEmpty ? nil : value
  }
}

public enum Percentile {
  public static func nearestRank50(_ measurements: [Double]) throws -> Double {
    try nearestRank(measurements, percentile: 0.50)
  }

  public static func nearestRank95(_ measurements: [Double]) throws -> Double {
    try nearestRank(measurements, percentile: 0.95)
  }

  private static func nearestRank(
    _ measurements: [Double],
    percentile: Double
  ) throws -> Double {
    guard !measurements.isEmpty else {
      throw FeasibilityValidationError.emptyLatencySeries
    }
    guard measurements.allSatisfy({ $0.isFinite && $0 >= 0 }) else {
      throw FeasibilityValidationError.invalidLatency
    }
    let ordered = measurements.sorted()
    let rank = Int(ceil(percentile * Double(ordered.count)))
    return ordered[max(0, rank - 1)]
  }
}

public enum ArtifactDigest {
  public static func sha256(_ data: Data) -> String {
    SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
  }

  public static func sha256(fileURL: URL) throws -> String {
    sha256(try Data(contentsOf: fileURL, options: [.mappedIfSafe]))
  }
}

public enum CorpusValidator {
  public static func validate(_ corpus: EvaluationCorpus) throws -> CorpusSummary {
    guard corpus.schemaVersion == 1 else {
      throw FeasibilityValidationError.unsupportedSchemaVersion(corpus.schemaVersion)
    }
    guard corpus.samples.count >= 300 else {
      throw FeasibilityValidationError.insufficientTotalSamples(actual: corpus.samples.count)
    }

    var identifiers = Set<String>()
    var imageDigests = Set<String>()
    var positiveCount = 0
    var negativeCount = 0
    var classCounts: [MathSampleClass: Int] = [:]

    for sample in corpus.samples {
      guard !sample.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw FeasibilityValidationError.emptySampleID
      }
      guard identifiers.insert(sample.id).inserted else {
        throw FeasibilityValidationError.duplicateSampleID(sample.id)
      }
      try validateSHA256(sample.imageSHA256, field: "sample.imageSHA256")
      guard imageDigests.insert(sample.imageSHA256).inserted else {
        throw FeasibilityValidationError.duplicateImageDigest(sample.imageSHA256)
      }
      let uniqueClasses = Set(sample.classes)
      switch sample.kind {
      case .positive:
        positiveCount += 1
        guard !uniqueClasses.isEmpty else {
          throw FeasibilityValidationError.positiveSampleHasNoMathClass(sample.id)
        }
        for sampleClass in uniqueClasses {
          classCounts[sampleClass, default: 0] += 1
        }
      case .negative:
        negativeCount += 1
        guard uniqueClasses.isEmpty else {
          throw FeasibilityValidationError.negativeSampleHasMathClasses(sample.id)
        }
      }
    }

    guard positiveCount >= 200 else {
      throw FeasibilityValidationError.insufficientPositiveSamples(actual: positiveCount)
    }
    guard negativeCount >= 100 else {
      throw FeasibilityValidationError.insufficientNegativeSamples(actual: negativeCount)
    }
    for sampleClass in MathSampleClass.requiredPositiveClasses {
      let requiredCount = sampleClass == .cleanCommon ? 100 : 15
      let actualCount = classCounts[sampleClass, default: 0]
      guard actualCount >= requiredCount else {
        throw FeasibilityValidationError.insufficientClassSamples(
          sampleClass: sampleClass,
          actual: actualCount
        )
      }
    }

    return CorpusSummary(
      sampleCount: corpus.samples.count,
      positiveCount: positiveCount,
      negativeCount: negativeCount,
      classCounts: Dictionary(
        uniqueKeysWithValues: classCounts.map { ($0.key.rawValue, $0.value) }
      )
    )
  }

  public static func validateImages(
    for corpus: EvaluationCorpus,
    under imageRoot: URL
  ) throws {
    let resolvedRoot = imageRoot.resolvingSymlinksInPath().standardizedFileURL
    let rootPrefix =
      resolvedRoot.path.hasSuffix("/")
      ? resolvedRoot.path
      : resolvedRoot.path + "/"

    for sample in corpus.samples {
      let relativePath = sample.relativeImagePath
      let components = relativePath.split(separator: "/", omittingEmptySubsequences: false)
      guard
        !relativePath.isEmpty,
        !relativePath.hasPrefix("/"),
        !components.contains("..")
      else {
        throw FeasibilityValidationError.invalidRelativeImagePath(relativePath)
      }

      let imageURL =
        resolvedRoot
        .appendingPathComponent(relativePath)
        .resolvingSymlinksInPath()
        .standardizedFileURL
      guard imageURL.path.hasPrefix(rootPrefix) else {
        throw FeasibilityValidationError.invalidRelativeImagePath(relativePath)
      }
      let values = try? imageURL.resourceValues(forKeys: [.isRegularFileKey])
      guard values?.isRegularFile == true else {
        throw FeasibilityValidationError.missingImage(sample.id)
      }
      guard try ArtifactDigest.sha256(fileURL: imageURL) == sample.imageSHA256 else {
        throw FeasibilityValidationError.imageDigestMismatch(sample.id)
      }
    }
  }
}

public enum FreezeValidator {
  public static func validate(_ freeze: EvaluationFreeze) throws {
    guard freeze.schemaVersion == 1 else {
      throw FeasibilityValidationError.unsupportedSchemaVersion(freeze.schemaVersion)
    }
    try validateSHA256(freeze.corpusManifestSHA256, field: "freeze.corpusManifestSHA256")
    try validateSHA256(freeze.sealedLabelsSHA256, field: "freeze.sealedLabelsSHA256")
    try validateSHA256(freeze.scorerSHA256, field: "freeze.scorerSHA256")
    try validateSHA256(freeze.protocolSHA256, field: "freeze.protocolSHA256")
    let candidate = freeze.candidate
    guard !candidate.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      throw FeasibilityValidationError.emptyCandidateID
    }
    try validateSHA256(candidate.modelSHA256, field: "candidate.modelSHA256")
    try validateSHA256(candidate.configurationSHA256, field: "candidate.configurationSHA256")
    try validateSHA256(candidate.preprocessingSHA256, field: "candidate.preprocessingSHA256")
    try validateSHA256(candidate.decoderSHA256, field: "candidate.decoderSHA256")
  }

  public static func validateBinding(
    _ binding: VerifiedInputDigests,
    against freeze: EvaluationFreeze
  ) throws {
    let candidate = freeze.candidate
    let checks = [
      ("corpusManifestSHA256", binding.corpusManifestSHA256, freeze.corpusManifestSHA256),
      ("sealedLabelsSHA256", binding.sealedLabelsSHA256, freeze.sealedLabelsSHA256),
      ("scorerSHA256", binding.scorerSHA256, freeze.scorerSHA256),
      ("protocolSHA256", binding.protocolSHA256, freeze.protocolSHA256),
      ("modelSHA256", binding.modelSHA256, candidate.modelSHA256),
      ("configurationSHA256", binding.configurationSHA256, candidate.configurationSHA256),
      ("preprocessingSHA256", binding.preprocessingSHA256, candidate.preprocessingSHA256),
      ("decoderSHA256", binding.decoderSHA256, candidate.decoderSHA256),
    ]
    for (field, actual, expected) in checks {
      try validateSHA256(actual, field: "binding.\(field)")
      guard actual == expected else {
        throw FeasibilityValidationError.inputDigestMismatch(field: field)
      }
    }
  }
}

public enum LabelValidator {
  public static func validate(
    _ labels: [EvaluationLabel],
    for corpus: EvaluationCorpus
  ) throws {
    var labelsByID: [String: EvaluationLabel] = [:]
    for label in labels {
      guard labelsByID.updateValue(label, forKey: label.id) == nil else {
        throw FeasibilityValidationError.duplicateLabelID(label.id)
      }
    }
    let corpusIDs = Set(corpus.samples.map(\.id))
    guard Set(labelsByID.keys) == corpusIDs, labels.count == corpus.samples.count else {
      throw FeasibilityValidationError.labelIDsDoNotMatchCorpus
    }

    for sample in corpus.samples {
      guard let label = labelsByID[sample.id] else {
        throw FeasibilityValidationError.labelIDsDoNotMatchCorpus
      }
      switch sample.kind {
      case .positive:
        guard let expected = LaTeXNormalizer.normalize(label.expectedLaTeX) else {
          throw FeasibilityValidationError.positiveLabelIsEmpty(sample.id)
        }
        let accepted = Set(label.acceptedStructuralForms.compactMap(LaTeXNormalizer.normalize))
        guard !accepted.isEmpty, accepted.contains(expected) else {
          throw FeasibilityValidationError.positiveLabelHasNoStructuralForms(sample.id)
        }
      case .negative:
        guard LaTeXNormalizer.normalize(label.expectedLaTeX) == nil else {
          throw FeasibilityValidationError.negativeLabelHasExpectedOutput(sample.id)
        }
        guard label.acceptedStructuralForms.isEmpty else {
          throw FeasibilityValidationError.negativeLabelHasStructuralForms(sample.id)
        }
      }
    }
  }
}

public enum CandidateGateEvaluator {
  private static let maximumArmLatencyMilliseconds = 2_000.0
  private static let maximumIntelLatencyMilliseconds = 4_000.0
  private static let maximumAddedPeakMemoryBytes = 750 * 1_024 * 1_024
  private static let maximumInstalledSizeGrowthBytes = 200 * 1_024 * 1_024

  public static func evaluate(
    corpus: EvaluationCorpus,
    labels: [EvaluationLabel],
    freeze: EvaluationFreeze,
    binding: VerifiedInputDigests,
    evidence: CandidateEvidence
  ) throws -> CandidateGateReport {
    _ = try CorpusValidator.validate(corpus)
    try FreezeValidator.validate(freeze)
    try FreezeValidator.validateBinding(binding, against: freeze)
    try LabelValidator.validate(labels, for: corpus)
    guard evidence.schemaVersion == 1 else {
      throw FeasibilityValidationError.unsupportedSchemaVersion(evidence.schemaVersion)
    }
    guard evidence.installedSizeGrowthBytes >= 0 else {
      throw FeasibilityValidationError.invalidInstalledSize
    }
    let candidate = freeze.candidate
    guard candidate.id == evidence.candidateID else {
      throw FeasibilityValidationError.unknownCandidateID(evidence.candidateID)
    }

    let runs = try validatedRuns(
      evidence.runs,
      candidate: candidate,
      corpus: corpus
    )
    let labelsByID = Dictionary(uniqueKeysWithValues: labels.map { ($0.id, $0) })
    var failures: [String] = []
    var architectureReports: [ArchitectureGateReport] = []

    for architecture in BenchmarkArchitecture.allCases {
      guard let run = runs[architecture] else {
        throw FeasibilityValidationError.missingArchitecture(architecture)
      }
      let accuracy = calculateAccuracy(
        corpus: corpus,
        labelsByID: labelsByID,
        measurements: Dictionary(uniqueKeysWithValues: run.samples.map { ($0.id, $0) })
      )
      let latencies = run.samples.map(\.warmLatencyMilliseconds)
      let p50 = try Percentile.nearestRank50(latencies)
      let p95 = try Percentile.nearestRank95(latencies)
      let addedPeakMemory = run.peakResidentBytes - run.baselinePeakResidentBytes
      architectureReports.append(
        ArchitectureGateReport(
          architecture: architecture,
          accuracy: accuracy,
          measurementCount: run.samples.count,
          warmP50Milliseconds: p50,
          warmP95Milliseconds: p95,
          coldLoadMilliseconds: run.coldLoadMilliseconds,
          addedPeakMemoryBytes: addedPeakMemory
        )
      )

      let prefix = architecture.rawValue
      if accuracy.overallExactRate < 0.85 {
        failures.append("\(prefix) overall normalized exact accuracy is below 85%.")
      }
      if accuracy.cleanStructuralRate < 0.95 {
        failures.append("\(prefix) clean-common structural accuracy is below 95%.")
      }
      for sampleClass in MathSampleClass.requiredPositiveClasses {
        let rate = accuracy.classes[sampleClass.rawValue]?.normalizedExactRate ?? 0
        if rate < 0.70 {
          failures.append("\(prefix) \(sampleClass.rawValue) exact accuracy is below 70%.")
        }
      }
      if accuracy.negativeFalseSuccessRate > 0.01 {
        failures.append("\(prefix) negative false-success rate exceeds 1%.")
      }
      let maximumLatency =
        architecture == .arm64
        ? maximumArmLatencyMilliseconds
        : maximumIntelLatencyMilliseconds
      if p95 > maximumLatency {
        failures.append("\(prefix) warm p95 exceeds \(Int(maximumLatency)) ms.")
      }
      if addedPeakMemory > maximumAddedPeakMemoryBytes {
        failures.append("\(prefix) added peak memory exceeds 750 MiB.")
      }
      if !run.environment.qualifyingPerformanceHardware {
        failures.append("\(prefix) hardware is not a qualifying reference or slower system.")
      }
      if !run.environment.onACPower {
        failures.append("\(prefix) benchmark was not measured on AC power.")
      }
      if run.environment.lowPowerModeEnabled {
        failures.append("\(prefix) benchmark was measured with Low Power Mode enabled.")
      }
      if !run.environment.thermalPressureNominal {
        failures.append("\(prefix) benchmark reported thermal pressure.")
      }
      if run.environment.macOSVersion.split(separator: ".").first != "14" {
        failures.append("\(prefix) benchmark was not measured on macOS 14.")
      }
    }

    if evidence.installedSizeGrowthBytes > maximumInstalledSizeGrowthBytes {
      failures.append("The complete installed-size growth exceeds 200 MiB.")
    }
    if !evidence.licenseIsRedistributable {
      failures.append("Licensing is not redistributable with CopyLasso.")
    }
    if !evidence.provenanceIsReproducible {
      failures.append("Model or runtime provenance is not reproducible.")
    }
    if !evidence.networkingDeniedRecognitionPassed {
      failures.append("Recognition did not pass with networking denied.")
    }
    if evidence.persistedUserContent {
      failures.append("The candidate persisted evaluation content.")
    }
    if evidence.hasCloudFallback {
      failures.append("The candidate has a cloud fallback.")
    }
    if evidence.hasAnalyticsOrTelemetry {
      failures.append("The candidate has analytics or telemetry.")
    }
    if !evidence.supportsMacOS14 {
      failures.append("The deployable design does not support macOS 14.")
    }
    if !evidence.isUniversal2Deployable {
      failures.append("The deployable design is not Universal 2.")
    }
    if !evidence.sandboxCompatible {
      failures.append("The deployable design is not App Sandbox compatible.")
    }

    return CandidateGateReport(
      candidateID: evidence.candidateID,
      freeze: freeze,
      passed: failures.isEmpty,
      failures: failures,
      installedSizeGrowthBytes: evidence.installedSizeGrowthBytes,
      architectureReports: architectureReports
    )
  }

  private static func validatedRuns(
    _ runs: [ArchitectureRun],
    candidate: CandidateDesignFreeze,
    corpus: EvaluationCorpus
  ) throws -> [BenchmarkArchitecture: ArchitectureRun] {
    var runsByArchitecture: [BenchmarkArchitecture: ArchitectureRun] = [:]
    let corpusIDs = Set(corpus.samples.map(\.id))

    for run in runs {
      guard
        run.candidateID == candidate.id,
        run.modelSHA256 == candidate.modelSHA256,
        run.configurationSHA256 == candidate.configurationSHA256,
        run.preprocessingSHA256 == candidate.preprocessingSHA256,
        run.decoderSHA256 == candidate.decoderSHA256
      else {
        throw FeasibilityValidationError.mixedCandidateDesigns
      }
      guard runsByArchitecture.updateValue(run, forKey: run.architecture) == nil else {
        throw FeasibilityValidationError.duplicateArchitecture(run.architecture)
      }
      guard
        !run.environment.hardwareModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        run.environment.memoryBytes > 0,
        !run.environment.macOSVersion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        run.environment.warmupCount > 0
      else {
        throw FeasibilityValidationError.invalidEnvironment(run.architecture)
      }
      guard run.coldLoadMilliseconds.isFinite, run.coldLoadMilliseconds >= 0 else {
        throw FeasibilityValidationError.invalidColdLoad(run.architecture)
      }
      guard
        run.baselinePeakResidentBytes >= 0,
        run.peakResidentBytes >= run.baselinePeakResidentBytes
      else {
        throw FeasibilityValidationError.invalidMemoryMeasurement(run.architecture)
      }

      var resultIDs = Set<String>()
      for measurement in run.samples {
        guard resultIDs.insert(measurement.id).inserted else {
          throw FeasibilityValidationError.duplicateResultID(measurement.id)
        }
        guard
          measurement.warmLatencyMilliseconds.isFinite,
          measurement.warmLatencyMilliseconds >= 0
        else {
          throw FeasibilityValidationError.invalidLatency
        }
      }
      guard resultIDs == corpusIDs, run.samples.count == corpus.samples.count else {
        throw FeasibilityValidationError.resultIDsDoNotMatchCorpus(run.architecture)
      }
    }

    for architecture in BenchmarkArchitecture.allCases where runsByArchitecture[architecture] == nil
    {
      throw FeasibilityValidationError.missingArchitecture(architecture)
    }
    return runsByArchitecture
  }

  private static func calculateAccuracy(
    corpus: EvaluationCorpus,
    labelsByID: [String: EvaluationLabel],
    measurements: [String: SampleMeasurement]
  ) -> AccuracyMetrics {
    var positiveCount = 0
    var normalizedExactMatches = 0
    var cleanCommonCount = 0
    var cleanStructuralMatches = 0
    var negativeCount = 0
    var negativeFalseSuccesses = 0
    var classTotals: [MathSampleClass: Int] = [:]
    var classMatches: [MathSampleClass: Int] = [:]

    for sample in corpus.samples {
      guard
        let label = labelsByID[sample.id],
        let measurement = measurements[sample.id]
      else {
        continue
      }
      let output = LaTeXNormalizer.normalize(measurement.output)
      switch sample.kind {
      case .positive:
        positiveCount += 1
        let expected = LaTeXNormalizer.normalize(label.expectedLaTeX)
        let isExact = output != nil && output == expected
        if isExact {
          normalizedExactMatches += 1
        }
        for sampleClass in Set(sample.classes) {
          classTotals[sampleClass, default: 0] += 1
          if isExact {
            classMatches[sampleClass, default: 0] += 1
          }
        }
        if sample.classes.contains(.cleanCommon) {
          cleanCommonCount += 1
          let accepted = Set(
            label.acceptedStructuralForms.compactMap(LaTeXNormalizer.normalize)
          )
          if let output, accepted.contains(output) {
            cleanStructuralMatches += 1
          }
        }
      case .negative:
        negativeCount += 1
        if output != nil {
          negativeFalseSuccesses += 1
        }
      }
    }

    var classMetrics: [String: ClassAccuracyMetrics] = [:]
    for sampleClass in MathSampleClass.requiredPositiveClasses {
      let total = classTotals[sampleClass, default: 0]
      let matches = classMatches[sampleClass, default: 0]
      classMetrics[sampleClass.rawValue] = ClassAccuracyMetrics(
        sampleCount: total,
        normalizedExactMatches: matches,
        normalizedExactRate: rate(numerator: matches, denominator: total)
      )
    }
    return AccuracyMetrics(
      positiveCount: positiveCount,
      normalizedExactMatches: normalizedExactMatches,
      overallExactRate: rate(
        numerator: normalizedExactMatches,
        denominator: positiveCount
      ),
      cleanCommonCount: cleanCommonCount,
      cleanStructuralMatches: cleanStructuralMatches,
      cleanStructuralRate: rate(
        numerator: cleanStructuralMatches,
        denominator: cleanCommonCount
      ),
      negativeCount: negativeCount,
      negativeFalseSuccesses: negativeFalseSuccesses,
      negativeFalseSuccessRate: rate(
        numerator: negativeFalseSuccesses,
        denominator: negativeCount
      ),
      classes: classMetrics
    )
  }

  private static func rate(numerator: Int, denominator: Int) -> Double {
    guard denominator > 0 else { return 0 }
    return Double(numerator) / Double(denominator)
  }
}

public enum RuntimeComparisonEvaluator {
  private static let difficultClassMetrics: Set<String> = [
    MathSampleClass.alignedEquations.rawValue,
    MathSampleClass.degraded.rawValue,
    MathSampleClass.lowResolution.rawValue,
    MathSampleClass.matrices.rawValue,
  ]

  public static func evaluate(
    coreMLReport: CandidateGateReport,
    challengerReport: CandidateGateReport,
    pairedAccuracyImprovements: [PairedAccuracyImprovement]
  ) throws -> RuntimeComparisonReport {
    guard
      coreMLReport.freeze.candidate.runtimeKind == .coreML,
      challengerReport.freeze.candidate.runtimeKind == .nonCoreML,
      coreMLReport.candidateID == coreMLReport.freeze.candidate.id,
      challengerReport.candidateID == challengerReport.freeze.candidate.id,
      coreMLReport.candidateID != challengerReport.candidateID,
      coreMLReport.freeze.corpusManifestSHA256
        == challengerReport.freeze.corpusManifestSHA256,
      coreMLReport.freeze.sealedLabelsSHA256
        == challengerReport.freeze.sealedLabelsSHA256,
      coreMLReport.freeze.scorerSHA256 == challengerReport.freeze.scorerSHA256,
      coreMLReport.freeze.protocolSHA256 == challengerReport.freeze.protocolSHA256
    else {
      throw FeasibilityValidationError.invalidComparison
    }

    let coreMetrics = try validatedArchitectureReports(coreMLReport)
    let challengerMetrics = try validatedArchitectureReports(challengerReport)
    let latencyChanges: [(improvement: Double, regression: Double, saved: Double)] =
      BenchmarkArchitecture.allCases.map { architecture in
        let core = coreMetrics[architecture]!
        let challenger = challengerMetrics[architecture]!
        let difference =
          core.warmP95Milliseconds - challenger.warmP95Milliseconds
        return (
          improvement: difference / core.warmP95Milliseconds,
          regression: -difference / core.warmP95Milliseconds,
          saved: difference
        )
      }
    var hasMeaningfulLatencyWin = false
    for (index, change) in latencyChanges.enumerated()
    where change.improvement >= 0.20 && change.saved >= 100 {
      let otherArchitectureIsAcceptable = latencyChanges.enumerated().allSatisfy {
        otherIndex, otherChange in
        otherIndex == index || otherChange.regression <= 0.10
      }
      if otherArchitectureIsAcceptable {
        hasMeaningfulLatencyWin = true
        break
      }
    }

    var hasMeaningfulAccuracyWin = false
    var comparedMetrics = Set<String>()
    for interval in pairedAccuracyImprovements {
      let comparisonKey = "\(interval.architecture.rawValue):\(interval.metric)"
      guard
        !interval.metric.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
        interval.metric == "overall" || difficultClassMetrics.contains(interval.metric),
        comparedMetrics.insert(comparisonKey).inserted,
        interval.improvement.isFinite,
        interval.lower95ConfidenceBound.isFinite,
        interval.upper95ConfidenceBound.isFinite,
        interval.lower95ConfidenceBound <= interval.upper95ConfidenceBound,
        interval.lower95ConfidenceBound <= interval.improvement,
        interval.improvement <= interval.upper95ConfidenceBound,
        let core = coreMetrics[interval.architecture],
        let challenger = challengerMetrics[interval.architecture],
        let expectedImprovement = accuracyImprovement(
          metric: interval.metric,
          coreML: core,
          challenger: challenger
        ),
        abs(interval.improvement - expectedImprovement) <= 0.000_000_001
      else {
        throw FeasibilityValidationError.invalidComparison
      }
      let requiredImprovement = interval.metric == "overall" ? 0.03 : 0.05
      if interval.improvement >= requiredImprovement
        && interval.lower95ConfidenceBound > 0
      {
        hasMeaningfulAccuracyWin = true
      }
    }

    let recommendation: RuntimeRecommendation
    if challengerReport.passed
      && (hasMeaningfulLatencyWin || hasMeaningfulAccuracyWin)
    {
      recommendation = .nonCoreML
    } else if coreMLReport.passed {
      recommendation = .coreML
    } else {
      recommendation = .none
    }
    return RuntimeComparisonReport(
      coreMLPassesEveryAbsoluteGate: coreMLReport.passed,
      challengerPassesEveryAbsoluteGate: challengerReport.passed,
      hasMeaningfulLatencyWin: hasMeaningfulLatencyWin,
      hasMeaningfulAccuracyWin: hasMeaningfulAccuracyWin,
      recommendedRuntime: recommendation
    )
  }

  private static func validatedArchitectureReports(
    _ report: CandidateGateReport
  ) throws -> [BenchmarkArchitecture: ArchitectureGateReport] {
    var reports: [BenchmarkArchitecture: ArchitectureGateReport] = [:]
    for architectureReport in report.architectureReports {
      let accuracy = architectureReport.accuracy
      guard
        architectureReport.warmP95Milliseconds.isFinite,
        architectureReport.warmP95Milliseconds > 0,
        accuracy.overallExactRate.isFinite,
        (0...1).contains(accuracy.overallExactRate),
        accuracy.classes.values.allSatisfy({
          $0.normalizedExactRate.isFinite
            && (0...1).contains($0.normalizedExactRate)
        }),
        reports.updateValue(
          architectureReport,
          forKey: architectureReport.architecture
        ) == nil
      else {
        throw FeasibilityValidationError.invalidComparison
      }
    }
    guard
      reports.count == BenchmarkArchitecture.allCases.count,
      BenchmarkArchitecture.allCases.allSatisfy({ reports[$0] != nil })
    else {
      throw FeasibilityValidationError.invalidComparison
    }
    return reports
  }

  private static func accuracyImprovement(
    metric: String,
    coreML: ArchitectureGateReport,
    challenger: ArchitectureGateReport
  ) -> Double? {
    if metric == "overall" {
      return challenger.accuracy.overallExactRate - coreML.accuracy.overallExactRate
    }
    guard
      let coreRate = coreML.accuracy.classes[metric]?.normalizedExactRate,
      let challengerRate = challenger.accuracy.classes[metric]?.normalizedExactRate
    else {
      return nil
    }
    return challengerRate - coreRate
  }
}

private func validateSHA256(_ value: String, field: String) throws {
  let valid =
    value.utf8.count == 64
    && value.utf8.allSatisfy {
      ($0 >= Character("0").asciiValue! && $0 <= Character("9").asciiValue!)
        || ($0 >= Character("a").asciiValue! && $0 <= Character("f").asciiValue!)
    }
  guard valid else {
    throw FeasibilityValidationError.invalidSHA256(field: field)
  }
}
