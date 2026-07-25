import Foundation
import XCTest

@testable import LaTeXFeasibilityCore

final class LaTeXFeasibilityCoreTests: XCTestCase {
  private let mebibyte = 1_024 * 1_024

  func testConservativeNormalizationChangesOnlyRegisteredSurfaceDifferences() {
    XCTAssertEqual(
      LaTeXNormalizer.normalize(" \r\n\\[  \t \\\\frac{1}{2} \r\n\\]  "),
      "\\\\frac{1}{2}"
    )
    XCTAssertEqual(LaTeXNormalizer.normalize("$$x  +\n y$$"), "x + y")
    XCTAssertEqual(LaTeXNormalizer.normalize("\\(x^2\\)"), "x^2")
    XCTAssertEqual(LaTeXNormalizer.normalize("$x_1$"), "x_1")
    XCTAssertEqual(LaTeXNormalizer.normalize("$x$ + $y$"), "$x$ + $y$")
    XCTAssertEqual(LaTeXNormalizer.normalize("$$x$$ + $$y$$"), "$$x$$ + $$y$$")
    XCTAssertEqual(LaTeXNormalizer.normalize("$$x\\$$$"), "x\\$")
    XCTAssertEqual(LaTeXNormalizer.normalize("\\(x\\) + \\(y\\)"), "\\(x\\) + \\(y\\)")
    XCTAssertEqual(LaTeXNormalizer.normalize("\\dfrac{1}{2}"), "\\dfrac{1}{2}")
    XCTAssertEqual(LaTeXNormalizer.normalize("x+y"), "x+y")
    XCTAssertNil(LaTeXNormalizer.normalize(" \r\n\t "))
  }

  func testNearestRankP95UsesDeterministicBoundaryAndRejectsInvalidInputs() throws {
    XCTAssertEqual(
      try Percentile.nearestRank50((1...20).map(Double.init)),
      10
    )
    XCTAssertEqual(
      try Percentile.nearestRank95((1...20).map(Double.init)),
      19
    )
    XCTAssertEqual(
      try Percentile.nearestRank95((1...100).map(Double.init)),
      95
    )
    XCTAssertEqual(try Percentile.nearestRank95([2_000]), 2_000)

    assertValidationError(.emptyLatencySeries) {
      _ = try Percentile.nearestRank95([])
    }
    assertValidationError(.invalidLatency) {
      _ = try Percentile.nearestRank95([1, -.infinity])
    }
    assertValidationError(.invalidLatency) {
      _ = try Percentile.nearestRank95([1, -0.1])
    }
  }

  func testCorpusImageBytesAreBoundToSafeRelativePathsAndDigests() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let imageData = Data("fixture".utf8)
    let imageURL = root.appendingPathComponent("fixture.bin")
    try imageData.write(to: imageURL)
    var corpus = EvaluationCorpus(
      schemaVersion: 1,
      samples: [
        EvaluationSample(
          id: "bound-image",
          relativeImagePath: "fixture.bin",
          imageSHA256: ArtifactDigest.sha256(imageData),
          kind: .positive,
          classes: [.cleanCommon]
        )
      ]
    )

    XCTAssertNoThrow(try CorpusValidator.validateImages(for: corpus, under: root))

    corpus.samples[0].imageSHA256 = digest(123)
    assertValidationError(.imageDigestMismatch("bound-image")) {
      try CorpusValidator.validateImages(for: corpus, under: root)
    }

    corpus.samples[0].relativeImagePath = "../fixture.bin"
    assertValidationError(.invalidRelativeImagePath("../fixture.bin")) {
      try CorpusValidator.validateImages(for: corpus, under: root)
    }
  }

  func testCorpusValidationAcceptsExactMinimums() throws {
    let corpus = makeMinimumCorpus()

    let summary = try CorpusValidator.validate(corpus)

    XCTAssertEqual(summary.sampleCount, 300)
    XCTAssertEqual(summary.positiveCount, 200)
    XCTAssertEqual(summary.negativeCount, 100)
    XCTAssertEqual(summary.classCounts[MathSampleClass.cleanCommon.rawValue], 100)
    for sampleClass in MathSampleClass.requiredPositiveClasses {
      XCTAssertGreaterThanOrEqual(summary.classCounts[sampleClass.rawValue, default: 0], 15)
    }
  }

  func testCorpusValidationRejectsCountsBelowEveryContractMinimum() {
    var totalTooSmall = makeMinimumCorpus()
    totalTooSmall.samples.removeLast()
    totalTooSmall.samples.removeLast()
    totalTooSmall.samples.removeFirst()
    assertValidationError(.insufficientTotalSamples(actual: 297)) {
      _ = try CorpusValidator.validate(totalTooSmall)
    }

    var positivesTooSmall = makeMinimumCorpus()
    positivesTooSmall.samples[199] = makeNegative(index: 200)
    assertValidationError(.insufficientPositiveSamples(actual: 199)) {
      _ = try CorpusValidator.validate(positivesTooSmall)
    }

    var negativesTooSmall = makeMinimumCorpus()
    negativesTooSmall.samples[200] = makePositive(index: 201)
    assertValidationError(.insufficientNegativeSamples(actual: 99)) {
      _ = try CorpusValidator.validate(negativesTooSmall)
    }

    var cleanTooSmall = makeMinimumCorpus()
    cleanTooSmall.samples[99].classes.removeAll { $0 == .cleanCommon }
    assertValidationError(.insufficientClassSamples(sampleClass: .cleanCommon, actual: 99)) {
      _ = try CorpusValidator.validate(cleanTooSmall)
    }

    var classTooSmall = makeMinimumCorpus()
    classTooSmall.samples[114].classes.removeAll { $0 == .fractions }
    assertValidationError(.insufficientClassSamples(sampleClass: .fractions, actual: 14)) {
      _ = try CorpusValidator.validate(classTooSmall)
    }
  }

  func testCorpusValidationRejectsDuplicateIdentityDigestAndInvalidClassShape() {
    var duplicateID = makeMinimumCorpus()
    duplicateID.samples[1].id = duplicateID.samples[0].id
    assertValidationError(.duplicateSampleID(duplicateID.samples[0].id)) {
      _ = try CorpusValidator.validate(duplicateID)
    }

    var duplicateDigest = makeMinimumCorpus()
    duplicateDigest.samples[1].imageSHA256 = duplicateDigest.samples[0].imageSHA256
    assertValidationError(.duplicateImageDigest(duplicateDigest.samples[0].imageSHA256)) {
      _ = try CorpusValidator.validate(duplicateDigest)
    }

    var negativeWithClass = makeMinimumCorpus()
    negativeWithClass.samples[200].classes = [.operators]
    assertValidationError(.negativeSampleHasMathClasses(negativeWithClass.samples[200].id)) {
      _ = try CorpusValidator.validate(negativeWithClass)
    }

    var positiveWithoutClass = makeMinimumCorpus()
    positiveWithoutClass.samples[150].classes = []
    assertValidationError(.positiveSampleHasNoMathClass(positiveWithoutClass.samples[150].id)) {
      _ = try CorpusValidator.validate(positiveWithoutClass)
    }
  }

  func testFreezeRequiresOneCompleteSelectedCandidateDesign() throws {
    let freeze = makeFreeze()
    XCTAssertNoThrow(try FreezeValidator.validate(freeze))

    var emptyCandidate = freeze
    emptyCandidate.candidate.id = " "
    assertValidationError(.emptyCandidateID) {
      try FreezeValidator.validate(emptyCandidate)
    }

    var badDigest = freeze
    badDigest.candidate.artifactManifestSHA256 = "not-a-digest"
    assertValidationError(.invalidSHA256(field: "candidate.artifactManifestSHA256")) {
      try FreezeValidator.validate(badDigest)
    }

    var mismatchedBinding = makeBinding(for: freeze)
    mismatchedBinding.protocolSHA256 = digest(99_999)
    assertValidationError(.inputDigestMismatch(field: "protocolSHA256")) {
      try FreezeValidator.validateBinding(mismatchedBinding, against: freeze)
    }
  }

  func testLabelsMustExactlyMatchCorpusAndRespectPositiveNegativeShapes() throws {
    let corpus = makeMinimumCorpus()
    let labels = makeLabels(for: corpus)
    XCTAssertNoThrow(try LabelValidator.validate(labels, for: corpus))

    var missing = labels
    missing.removeLast()
    assertValidationError(.labelIDsDoNotMatchCorpus) {
      try LabelValidator.validate(missing, for: corpus)
    }

    var duplicate = labels
    duplicate[1].id = duplicate[0].id
    assertValidationError(.duplicateLabelID(duplicate[0].id)) {
      try LabelValidator.validate(duplicate, for: corpus)
    }

    var emptyPositive = labels
    emptyPositive[0].expectedLaTeX = " "
    assertValidationError(.positiveLabelIsEmpty(emptyPositive[0].id)) {
      try LabelValidator.validate(emptyPositive, for: corpus)
    }

    var negativeOutput = labels
    negativeOutput[200].expectedLaTeX = "x"
    assertValidationError(.negativeLabelHasExpectedOutput(negativeOutput[200].id)) {
      try LabelValidator.validate(negativeOutput, for: corpus)
    }
  }

  func testCandidateAtEveryExactAbsoluteBoundaryPasses() throws {
    let corpus = makeMinimumCorpus()
    let labels = makeLabels(for: corpus)
    let freeze = makeFreeze()
    let evidence = makePassingEvidence(
      corpus: corpus,
      labels: labels,
      freeze: freeze,
      armLatency: 2_000,
      intelLatency: 4_000,
      addedPeakMemoryBytes: 750 * mebibyte,
      installedSizeGrowthBytes: 200 * mebibyte
    )

    let report = try CandidateGateEvaluator.evaluate(
      corpus: corpus,
      labels: labels,
      freeze: freeze,
      binding: makeBinding(for: freeze),
      evidence: evidence
    )

    XCTAssertTrue(report.passed)
    XCTAssertEqual(report.failures, [])
    XCTAssertEqual(report.architectureReports.count, 2)
    XCTAssertTrue(report.architectureReports.allSatisfy { $0.accuracy.overallExactRate == 1 })
    XCTAssertTrue(report.architectureReports.allSatisfy { $0.measurementCount == 300 })
    XCTAssertEqual(report.architectureReports[0].warmP50Milliseconds, 2_000)
    XCTAssertEqual(
      report.architectureReports[0].accuracy.classes["clean_common"]?.sampleCount,
      100
    )
  }

  func testNonCoreMLRequiresAConfiguredMeaningfulWinAndEveryAbsoluteGate() throws {
    let corpus = makeMinimumCorpus()
    let labels = makeLabels(for: corpus)
    let coreFreeze = makeFreeze()
    let challengerFreeze = makeFreeze(
      candidateID: "onnx-candidate",
      runtimeKind: .nonCoreML,
      modelSeed: 32_000
    )
    let coreReport = try report(
      corpus,
      labels,
      coreFreeze,
      makePassingEvidence(
        corpus: corpus,
        labels: labels,
        freeze: coreFreeze,
        armLatency: 1_000,
        intelLatency: 2_000
      )
    )
    let latencyChallengerReport = try report(
      corpus,
      labels,
      challengerFreeze,
      makePassingEvidence(
        corpus: corpus,
        labels: labels,
        freeze: challengerFreeze,
        armLatency: 800,
        intelLatency: 2_190
      )
    )
    let latencyWin = try RuntimeComparisonEvaluator.evaluate(
      coreMLReport: coreReport,
      challengerReport: latencyChallengerReport
    )
    XCTAssertTrue(latencyWin.hasMeaningfulLatencyWin)
    XCTAssertEqual(latencyWin.recommendedRuntime, .nonCoreML)

    let practicalTie = try RuntimeComparisonEvaluator.evaluate(
      coreMLReport: coreReport,
      challengerReport: try report(
        corpus,
        labels,
        challengerFreeze,
        makePassingEvidence(
          corpus: corpus,
          labels: labels,
          freeze: challengerFreeze,
          armLatency: 900,
          intelLatency: 2_000
        )
      )
    )
    XCTAssertFalse(practicalTie.hasMeaningfulLatencyWin)
    XCTAssertEqual(practicalTie.recommendedRuntime, .coreML)

    var failedChallengerEvidence = makePassingEvidence(
      corpus: corpus,
      labels: labels,
      freeze: challengerFreeze,
      armLatency: 700,
      intelLatency: 1_500
    )
    failedChallengerEvidence.licenseIsRedistributable = false
    let failedChallengerReport = try report(
      corpus,
      labels,
      challengerFreeze,
      failedChallengerEvidence
    )
    let failedChallenger = try RuntimeComparisonEvaluator.evaluate(
      coreMLReport: coreReport,
      challengerReport: failedChallengerReport
    )
    XCTAssertFalse(failedChallenger.hasMeaningfulLatencyWin)
    XCTAssertEqual(failedChallenger.recommendedRuntime, .coreML)

    let zeroLatencyChallengerReport = try report(
      corpus,
      labels,
      challengerFreeze,
      makePassingEvidence(
        corpus: corpus,
        labels: labels,
        freeze: challengerFreeze,
        armLatency: 0,
        intelLatency: 0
      )
    )
    let zeroLatencyWin = try RuntimeComparisonEvaluator.evaluate(
      coreMLReport: coreReport,
      challengerReport: zeroLatencyChallengerReport
    )
    XCTAssertTrue(zeroLatencyWin.hasMeaningfulLatencyWin)
    XCTAssertEqual(zeroLatencyWin.recommendedRuntime, .nonCoreML)

    var failedCoreEvidence = makePassingEvidence(
      corpus: corpus,
      labels: labels,
      freeze: coreFreeze
    )
    failedCoreEvidence.sandboxCompatible = false
    let failedCoreReport = try report(
      corpus,
      labels,
      coreFreeze,
      failedCoreEvidence
    )
    let nonCoreMLWinAgainstUnqualifiedBaseline = try RuntimeComparisonEvaluator.evaluate(
      coreMLReport: failedCoreReport,
      challengerReport: latencyChallengerReport
    )
    XCTAssertEqual(nonCoreMLWinAgainstUnqualifiedBaseline.recommendedRuntime, .nonCoreML)

    let noQualifiedRecommendation = try RuntimeComparisonEvaluator.evaluate(
      coreMLReport: failedCoreReport,
      challengerReport: failedChallengerReport
    )
    XCTAssertEqual(noQualifiedRecommendation.recommendedRuntime, .none)

    var accuracyBaselineEvidence = makePassingEvidence(
      corpus: corpus,
      labels: labels,
      freeze: coreFreeze
    )
    for runIndex in accuracyBaselineEvidence.runs.indices {
      for index in 0..<6 {
        accuracyBaselineEvidence.runs[runIndex].samples[index].output = "struct-\(index)"
      }
    }
    let accuracyBaselineReport = try report(
      corpus,
      labels,
      coreFreeze,
      accuracyBaselineEvidence
    )
    let exactChallengerReport = try report(
      corpus,
      labels,
      challengerFreeze,
      makePassingEvidence(corpus: corpus, labels: labels, freeze: challengerFreeze)
    )
    let accuracyWin = try RuntimeComparisonEvaluator.evaluate(
      coreMLReport: accuracyBaselineReport,
      challengerReport: exactChallengerReport
    )
    XCTAssertTrue(accuracyWin.hasMeaningfulAccuracyWin)
    XCTAssertTrue(
      accuracyWin.pairedAccuracyImprovements.contains {
        $0.metric == "overall"
          && $0.improvement == 0.03
          && $0.lower95ConfidenceBound > 0
      }
    )
    XCTAssertEqual(accuracyWin.recommendedRuntime, .nonCoreML)

    var failedAccuracyEvidence = makePassingEvidence(
      corpus: corpus,
      labels: labels,
      freeze: challengerFreeze
    )
    failedAccuracyEvidence.licenseIsRedistributable = false
    let failedAccuracyWin = try RuntimeComparisonEvaluator.evaluate(
      coreMLReport: accuracyBaselineReport,
      challengerReport: try report(
        corpus,
        labels,
        challengerFreeze,
        failedAccuracyEvidence
      )
    )
    XCTAssertFalse(failedAccuracyWin.hasMeaningfulAccuracyWin)
    XCTAssertEqual(failedAccuracyWin.recommendedRuntime, .coreML)

    var mismatchedChallengerFreeze = challengerFreeze
    mismatchedChallengerFreeze.corpusManifestSHA256 = digest(32_999)
    let mismatchedChallengerReport = try report(
      corpus,
      labels,
      mismatchedChallengerFreeze,
      makePassingEvidence(
        corpus: corpus,
        labels: labels,
        freeze: mismatchedChallengerFreeze
      )
    )
    assertValidationError(.invalidComparison) {
      _ = try RuntimeComparisonEvaluator.evaluate(
        coreMLReport: coreReport,
        challengerReport: mismatchedChallengerReport
      )
    }

    var mismatchedOutcomes = exactChallengerReport.architectureReports
    let armIndex = try XCTUnwrap(
      mismatchedOutcomes.firstIndex { $0.architecture == .arm64 }
    )
    var armOutcomes = mismatchedOutcomes[armIndex].sampleOutcomes
    armOutcomes[0].id = "substituted-sample"
    mismatchedOutcomes[armIndex] = ArchitectureGateReport(
      architecture: mismatchedOutcomes[armIndex].architecture,
      accuracy: mismatchedOutcomes[armIndex].accuracy,
      sampleOutcomes: armOutcomes,
      measurementCount: mismatchedOutcomes[armIndex].measurementCount,
      warmP50Milliseconds: mismatchedOutcomes[armIndex].warmP50Milliseconds,
      warmP95Milliseconds: mismatchedOutcomes[armIndex].warmP95Milliseconds,
      coldLoadMilliseconds: mismatchedOutcomes[armIndex].coldLoadMilliseconds,
      addedPeakMemoryBytes: mismatchedOutcomes[armIndex].addedPeakMemoryBytes
    )
    let unboundChallengerReport = CandidateGateReport(
      candidateID: exactChallengerReport.candidateID,
      freeze: exactChallengerReport.freeze,
      passed: exactChallengerReport.passed,
      failures: exactChallengerReport.failures,
      installedSizeGrowthBytes: exactChallengerReport.installedSizeGrowthBytes,
      architectureReports: mismatchedOutcomes
    )
    assertValidationError(.invalidComparison) {
      _ = try RuntimeComparisonEvaluator.evaluate(
        coreMLReport: accuracyBaselineReport,
        challengerReport: unboundChallengerReport
      )
    }
  }

  func testProtocolValidationRejectsThresholdDrift() throws {
    let supported = try makeSupportedProtocolData()
    XCTAssertNoThrow(try ProtocolValidator.validateSupported(supported))

    let drifted = try XCTUnwrap(
      String(data: supported, encoding: .utf8)?
        .replacingOccurrences(
          of: #""overall_positive_exact_minimum": 0.85"#,
          with: #""overall_positive_exact_minimum": 0.90"#
        )
        .data(using: .utf8)
    )
    assertValidationError(.invalidProtocolContract) {
      try ProtocolValidator.validateSupported(drifted)
    }

    let normalizationDrift = try XCTUnwrap(
      String(data: supported, encoding: .utf8)?
        .replacingOccurrences(
          of: #""unicode_normalization": "NFC""#,
          with: #""unicode_normalization": "NFD""#
        )
        .data(using: .utf8)
    )
    assertValidationError(.invalidProtocolContract) {
      try ProtocolValidator.validateSupported(normalizationDrift)
    }

    let platformDrift = try XCTUnwrap(
      String(data: supported, encoding: .utf8)?
        .replacingOccurrences(
          of: #""macos_major": 14"#,
          with: #""macos_major": 15"#
        )
        .data(using: .utf8)
    )
    assertValidationError(.invalidProtocolContract) {
      try ProtocolValidator.validateSupported(platformDrift)
    }

    for (original, replacement) in [
      (#""minimum_samples": 300"#, #""minimum_samples": 300.5"#),
      (#""schema_version": 1"#, #""schema_version": true"#),
    ] {
      let malformedInteger = try XCTUnwrap(
        String(data: supported, encoding: .utf8)?
          .replacingOccurrences(of: original, with: replacement)
          .data(using: .utf8)
      )
      assertValidationError(.invalidProtocolContract) {
        try ProtocolValidator.validateSupported(malformedInteger)
      }
    }
  }

  func testArtifactManifestBindsCompleteFilesAndRuntimeDirectory() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let runtime = root.appendingPathComponent("runtime", isDirectory: true)
    try FileManager.default.createDirectory(at: runtime, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    try FileManager.default.createDirectory(
      at: root.appendingPathComponent("metadata", isDirectory: true),
      withIntermediateDirectories: false
    )
    let fileNames = [
      "model.bin",
      "metadata/configuration.json",
      "preprocess.json",
      "decoder.json",
    ]
    for name in fileNames {
      try Data(name.utf8).write(to: root.appendingPathComponent(name))
    }
    try Data("runtime".utf8).write(to: runtime.appendingPathComponent("engine.dylib"))
    let emptyRuntimeDirectory = runtime.appendingPathComponent("empty-cache", isDirectory: true)
    try FileManager.default.createDirectory(
      at: emptyRuntimeDirectory,
      withIntermediateDirectories: false
    )

    let manifest = CandidateArtifactManifest(
      schemaVersion: 1,
      systemRuntimeIdentifier: nil,
      artifacts: [
        artifact(.model, "model.bin", under: root),
        artifact(.configuration, "metadata/configuration.json", under: root),
        artifact(.preprocessing, "preprocess.json", under: root),
        artifact(.decoder, "decoder.json", under: root),
        CandidateArtifact(
          role: .runtime,
          kind: .directory,
          relativePath: "runtime",
          sha256: try ArtifactDigest.sha256Tree(directoryURL: runtime)
        ),
      ]
    )
    XCTAssertNoThrow(
      try ArtifactManifestValidator.validate(
        manifest,
        runtimeKind: .nonCoreML,
        under: root
      )
    )
    assertValidationError(.incompleteArtifactManifest) {
      try ArtifactManifestValidator.validate(
        manifest,
        runtimeKind: .coreML,
        under: root
      )
    }
    var mixedCoreML = manifest
    mixedCoreML.systemRuntimeIdentifier = "com.apple.CoreML"
    assertValidationError(.incompleteArtifactManifest) {
      try ArtifactManifestValidator.validate(
        mixedCoreML,
        runtimeKind: .coreML,
        under: root
      )
    }

    let unlistedURL = root.appendingPathComponent("unlisted.bin")
    try Data("unlisted".utf8).write(to: unlistedURL)
    assertValidationError(.unboundArtifact("unlisted.bin")) {
      try ArtifactManifestValidator.validate(
        manifest,
        runtimeKind: .nonCoreML,
        under: root
      )
    }
    try FileManager.default.removeItem(at: unlistedURL)

    for unboundPrefix in ["model", "run"] {
      let prefixURL = root.appendingPathComponent(unboundPrefix)
      try Data(unboundPrefix.utf8).write(to: prefixURL)
      assertValidationError(.unboundArtifact(unboundPrefix)) {
        try ArtifactManifestValidator.validate(
          manifest,
          runtimeKind: .nonCoreML,
          under: root
        )
      }
      try FileManager.default.removeItem(at: prefixURL)
    }

    let unlistedDirectory = root.appendingPathComponent("unlisted-directory", isDirectory: true)
    try FileManager.default.createDirectory(
      at: unlistedDirectory,
      withIntermediateDirectories: false
    )
    assertValidationError(.unboundArtifact("unlisted-directory/")) {
      try ArtifactManifestValidator.validate(
        manifest,
        runtimeKind: .nonCoreML,
        under: root
      )
    }
    try FileManager.default.removeItem(at: unlistedDirectory)

    try FileManager.default.removeItem(at: emptyRuntimeDirectory)
    assertValidationError(.artifactDigestMismatch("runtime")) {
      try ArtifactManifestValidator.validate(
        manifest,
        runtimeKind: .nonCoreML,
        under: root
      )
    }
    try FileManager.default.createDirectory(
      at: emptyRuntimeDirectory,
      withIntermediateDirectories: false
    )

    try Data("changed".utf8).write(to: runtime.appendingPathComponent("engine.dylib"))
    assertValidationError(.artifactDigestMismatch("runtime")) {
      try ArtifactManifestValidator.validate(
        manifest,
        runtimeKind: .nonCoreML,
        under: root
      )
    }

    var incomplete = manifest
    incomplete.artifacts.removeAll { $0.role == .runtime }
    assertValidationError(.incompleteArtifactManifest) {
      try ArtifactManifestValidator.validate(
        incomplete,
        runtimeKind: .nonCoreML,
        under: root
      )
    }

    try FileManager.default.removeItem(at: runtime)
    incomplete.systemRuntimeIdentifier = "com.apple.CoreML"
    XCTAssertNoThrow(
      try ArtifactManifestValidator.validate(
        incomplete,
        runtimeKind: .coreML,
        under: root
      )
    )
    incomplete.systemRuntimeIdentifier = "unreviewed.runtime"
    assertValidationError(.incompleteArtifactManifest) {
      try ArtifactManifestValidator.validate(
        incomplete,
        runtimeKind: .coreML,
        under: root
      )
    }
  }

  func testArtifactManifestRejectsNoncanonicalDuplicatePaths() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let runtime = root.appendingPathComponent("runtime", isDirectory: true)
    try FileManager.default.createDirectory(at: runtime, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    let model = root.appendingPathComponent("model.bin")
    try Data("model".utf8).write(to: model)
    try Data("runtime".utf8).write(to: runtime.appendingPathComponent("engine.dylib"))
    let modelDigest = try ArtifactDigest.sha256(fileURL: model)
    let manifest = CandidateArtifactManifest(
      schemaVersion: 1,
      systemRuntimeIdentifier: nil,
      artifacts: [
        CandidateArtifact(
          role: .model,
          kind: .file,
          relativePath: "model.bin",
          sha256: modelDigest
        ),
        CandidateArtifact(
          role: .configuration,
          kind: .file,
          relativePath: "./model.bin",
          sha256: modelDigest
        ),
        CandidateArtifact(
          role: .preprocessing,
          kind: .file,
          relativePath: ".//model.bin",
          sha256: modelDigest
        ),
        CandidateArtifact(
          role: .decoder,
          kind: .file,
          relativePath: "././model.bin",
          sha256: modelDigest
        ),
        CandidateArtifact(
          role: .runtime,
          kind: .directory,
          relativePath: "runtime",
          sha256: try ArtifactDigest.sha256Tree(directoryURL: runtime)
        ),
      ]
    )

    assertValidationError(.invalidArtifactPath("./model.bin")) {
      try ArtifactManifestValidator.validate(
        manifest,
        runtimeKind: .nonCoreML,
        under: root
      )
    }
  }

  func testReferenceRuntimeCannotEnterBlindGateScoring() throws {
    let corpus = makeMinimumCorpus()
    let labels = makeLabels(for: corpus)
    let freeze = makeFreeze(runtimeKind: .reference)
    let evidence = makePassingEvidence(corpus: corpus, labels: labels, freeze: freeze)

    assertValidationError(.ineligibleRuntimeKind(.reference)) {
      _ = try CandidateGateEvaluator.evaluate(
        corpus: corpus,
        labels: labels,
        freeze: freeze,
        binding: makeBinding(for: freeze),
        evidence: evidence
      )
    }
  }

  func testAccuracyMetricsApplyOverallStructureClassAndNegativeBoundaries() throws {
    let corpus = makeMinimumCorpus()
    let labels = makeLabels(for: corpus)
    let freeze = makeFreeze()
    var evidence = makePassingEvidence(corpus: corpus, labels: labels, freeze: freeze)

    // Exactly 85% overall exact, 95% clean structural, and 1% negative false success pass.
    for runIndex in evidence.runs.indices {
      for index in 0..<30 {
        evidence.runs[runIndex].samples[index].output = "struct-\(index)"
      }
      for index in 0..<5 {
        evidence.runs[runIndex].samples[index].output = "wrong-\(index)"
      }
      evidence.runs[runIndex].samples[200].output = "false-success"
    }
    var report = try CandidateGateEvaluator.evaluate(
      corpus: corpus,
      labels: labels,
      freeze: freeze,
      binding: makeBinding(for: freeze),
      evidence: evidence
    )
    XCTAssertTrue(report.passed)
    XCTAssertEqual(report.architectureReports[0].accuracy.overallExactRate, 0.85)
    XCTAssertEqual(report.architectureReports[0].accuracy.cleanStructuralRate, 0.95)
    XCTAssertEqual(report.architectureReports[0].accuracy.negativeFalseSuccessRate, 0.01)

    // One fewer exact match fails the overall gate.
    for runIndex in evidence.runs.indices {
      evidence.runs[runIndex].samples[30].output = "not-exact"
    }
    report = try CandidateGateEvaluator.evaluate(
      corpus: corpus,
      labels: labels,
      freeze: freeze,
      binding: makeBinding(for: freeze),
      evidence: evidence
    )
    XCTAssertTrue(report.failures.contains { $0.contains("overall normalized exact") })

    // Five wrong results among a 15-sample class fail the 70% class floor.
    evidence = makePassingEvidence(corpus: corpus, labels: labels, freeze: freeze)
    for runIndex in evidence.runs.indices {
      for index in 100..<105 {
        evidence.runs[runIndex].samples[index].output = "wrong-\(index)"
      }
    }
    report = try CandidateGateEvaluator.evaluate(
      corpus: corpus,
      labels: labels,
      freeze: freeze,
      binding: makeBinding(for: freeze),
      evidence: evidence
    )
    XCTAssertTrue(report.failures.contains { $0.contains("fractions exact") })

    // Two false successes among 100 negatives fail the 1% ceiling.
    evidence = makePassingEvidence(corpus: corpus, labels: labels, freeze: freeze)
    for runIndex in evidence.runs.indices {
      evidence.runs[runIndex].samples[200].output = "false-one"
      evidence.runs[runIndex].samples[201].output = "false-two"
    }
    report = try CandidateGateEvaluator.evaluate(
      corpus: corpus,
      labels: labels,
      freeze: freeze,
      binding: makeBinding(for: freeze),
      evidence: evidence
    )
    XCTAssertTrue(report.failures.contains { $0.contains("negative false-success") })
  }

  func testEveryPerformanceSizeAndPolicyGateFailsClosedAboveItsBoundary() throws {
    let corpus = makeMinimumCorpus()
    let labels = makeLabels(for: corpus)
    let freeze = makeFreeze()

    var evidence = makePassingEvidence(corpus: corpus, labels: labels, freeze: freeze)
    for index in evidence.runs[0].samples.indices {
      evidence.runs[0].samples[index].warmLatencyMilliseconds = 2_001
    }
    XCTAssertTrue(
      try report(corpus, labels, freeze, evidence).failures.contains {
        $0.contains("arm64 warm p95")
      })

    evidence = makePassingEvidence(corpus: corpus, labels: labels, freeze: freeze)
    evidence.runs[1].peakResidentBytes =
      evidence.runs[1].baselinePeakResidentBytes + (750 * mebibyte) + 1
    XCTAssertTrue(
      try report(corpus, labels, freeze, evidence).failures.contains {
        $0.contains("added peak memory")
      })

    evidence = makePassingEvidence(corpus: corpus, labels: labels, freeze: freeze)
    evidence.installedSizeGrowthBytes = (200 * mebibyte) + 1
    XCTAssertTrue(
      try report(corpus, labels, freeze, evidence).failures.contains {
        $0.contains("installed-size")
      })

    let policyMutations: [(inout CandidateEvidence) -> Void] = [
      { $0.licenseIsRedistributable = false },
      { $0.provenanceIsReproducible = false },
      { $0.networkingDeniedRecognitionPassed = false },
      { $0.persistedUserContent = true },
      { $0.hasCloudFallback = true },
      { $0.hasAnalyticsOrTelemetry = true },
      { $0.supportsMacOS14 = false },
      { $0.isUniversal2Deployable = false },
      { $0.sandboxCompatible = false },
    ]
    for mutate in policyMutations {
      evidence = makePassingEvidence(corpus: corpus, labels: labels, freeze: freeze)
      mutate(&evidence)
      XCTAssertFalse(try report(corpus, labels, freeze, evidence).passed)
    }
  }

  func testIncompleteAndMixedCandidateEvidenceIsRejected() {
    let corpus = makeMinimumCorpus()
    let labels = makeLabels(for: corpus)
    let freeze = makeFreeze()
    var incomplete = makePassingEvidence(corpus: corpus, labels: labels, freeze: freeze)
    incomplete.runs.removeLast()
    assertValidationError(.missingArchitecture(.x8664)) {
      _ = try CandidateGateEvaluator.evaluate(
        corpus: corpus,
        labels: labels,
        freeze: freeze,
        binding: makeBinding(for: freeze),
        evidence: incomplete
      )
    }

    var mixed = makePassingEvidence(corpus: corpus, labels: labels, freeze: freeze)
    mixed.runs[1].candidateID = "different-candidate"
    assertValidationError(.mixedCandidateDesigns) {
      _ = try CandidateGateEvaluator.evaluate(
        corpus: corpus,
        labels: labels,
        freeze: freeze,
        binding: makeBinding(for: freeze),
        evidence: mixed
      )
    }

    mixed = makePassingEvidence(corpus: corpus, labels: labels, freeze: freeze)
    mixed.runs[1].artifactManifestSHA256 = digest(32_000)
    assertValidationError(.mixedCandidateDesigns) {
      _ = try CandidateGateEvaluator.evaluate(
        corpus: corpus,
        labels: labels,
        freeze: freeze,
        binding: makeBinding(for: freeze),
        evidence: mixed
      )
    }

  }

  func testResultsMustContainEverySampleExactlyOnceWithFiniteMeasurements() {
    let corpus = makeMinimumCorpus()
    let labels = makeLabels(for: corpus)
    let freeze = makeFreeze()

    var missing = makePassingEvidence(corpus: corpus, labels: labels, freeze: freeze)
    missing.runs[0].samples.removeLast()
    assertValidationError(.resultIDsDoNotMatchCorpus(.arm64)) {
      _ = try CandidateGateEvaluator.evaluate(
        corpus: corpus,
        labels: labels,
        freeze: freeze,
        binding: makeBinding(for: freeze),
        evidence: missing
      )
    }

    var duplicate = makePassingEvidence(corpus: corpus, labels: labels, freeze: freeze)
    duplicate.runs[0].samples[1].id = duplicate.runs[0].samples[0].id
    assertValidationError(.duplicateResultID(duplicate.runs[0].samples[0].id)) {
      _ = try CandidateGateEvaluator.evaluate(
        corpus: corpus,
        labels: labels,
        freeze: freeze,
        binding: makeBinding(for: freeze),
        evidence: duplicate
      )
    }

    var invalidLatency = makePassingEvidence(corpus: corpus, labels: labels, freeze: freeze)
    invalidLatency.runs[0].samples[0].warmLatencyMilliseconds = .nan
    assertValidationError(.invalidLatency) {
      _ = try CandidateGateEvaluator.evaluate(
        corpus: corpus,
        labels: labels,
        freeze: freeze,
        binding: makeBinding(for: freeze),
        evidence: invalidLatency
      )
    }
  }

  private func report(
    _ corpus: EvaluationCorpus,
    _ labels: [EvaluationLabel],
    _ freeze: EvaluationFreeze,
    _ evidence: CandidateEvidence
  ) throws -> CandidateGateReport {
    try CandidateGateEvaluator.evaluate(
      corpus: corpus,
      labels: labels,
      freeze: freeze,
      binding: makeBinding(for: freeze),
      evidence: evidence
    )
  }

  private func makeMinimumCorpus() -> EvaluationCorpus {
    let positives = (0..<200).map(makePositive(index:))
    let negatives = (0..<100).map(makeNegative(index:))
    return EvaluationCorpus(schemaVersion: 1, samples: positives + negatives)
  }

  private func makePositive(index: Int) -> EvaluationSample {
    var classes: [MathSampleClass] = []
    if index < 100 {
      classes.append(.cleanCommon)
    }
    if (100..<115).contains(index) {
      classes.append(
        contentsOf: MathSampleClass.requiredPositiveClasses.filter {
          $0 != .cleanCommon
        })
    } else {
      classes.append(index.isMultiple(of: 2) ? .inline : .display)
    }
    return EvaluationSample(
      id: "positive-\(index)",
      relativeImagePath: "positive/\(index).png",
      imageSHA256: digest(index),
      kind: .positive,
      classes: Array(Set(classes)).sorted { $0.rawValue < $1.rawValue }
    )
  }

  private func makeNegative(index: Int) -> EvaluationSample {
    EvaluationSample(
      id: "negative-\(index)",
      relativeImagePath: "negative/\(index).png",
      imageSHA256: digest(10_000 + index),
      kind: .negative,
      classes: []
    )
  }

  private func makeLabels(for corpus: EvaluationCorpus) -> [EvaluationLabel] {
    corpus.samples.enumerated().map { index, sample in
      switch sample.kind {
      case .positive:
        return EvaluationLabel(
          id: sample.id,
          expectedLaTeX: "expected-\(index)",
          acceptedStructuralForms: ["expected-\(index)", "struct-\(index)"]
        )
      case .negative:
        return EvaluationLabel(
          id: sample.id,
          expectedLaTeX: nil,
          acceptedStructuralForms: []
        )
      }
    }
  }

  private func makeFreeze(
    candidateID: String = "coreml-candidate",
    runtimeKind: CandidateRuntimeKind = .coreML,
    modelSeed: Int = 31_000
  ) -> EvaluationFreeze {
    EvaluationFreeze(
      schemaVersion: 1,
      corpusManifestSHA256: digest(30_000),
      sealedLabelsSHA256: digest(30_001),
      scorerSHA256: digest(30_002),
      protocolSHA256: digest(30_003),
      candidate: CandidateDesignFreeze(
        id: candidateID,
        runtimeKind: runtimeKind,
        artifactManifestSHA256: digest(modelSeed)
      )
    )
  }

  private func makePassingEvidence(
    corpus: EvaluationCorpus,
    labels: [EvaluationLabel],
    freeze: EvaluationFreeze,
    armLatency: Double = 1_000,
    intelLatency: Double = 2_000,
    addedPeakMemoryBytes: Int = 100 * 1_024 * 1_024,
    installedSizeGrowthBytes: Int = 100 * 1_024 * 1_024
  ) -> CandidateEvidence {
    let candidate = freeze.candidate
    let labelsByID = Dictionary(uniqueKeysWithValues: labels.map { ($0.id, $0) })
    func run(_ architecture: BenchmarkArchitecture, latency: Double) -> ArchitectureRun {
      ArchitectureRun(
        candidateID: candidate.id,
        artifactManifestSHA256: candidate.artifactManifestSHA256,
        architecture: architecture,
        environment: BenchmarkEnvironment(
          hardwareModel: architecture == .arm64 ? "qualifying-arm64" : "qualifying-intel",
          memoryBytes: 8 * 1_024 * 1_024 * 1_024,
          macOSVersion: "14.7.6",
          onACPower: true,
          lowPowerModeEnabled: false,
          thermalPressureNominal: true,
          qualifyingPerformanceHardware: true,
          warmupCount: 10
        ),
        coldLoadMilliseconds: 500,
        baselinePeakResidentBytes: 50 * 1_024 * 1_024,
        peakResidentBytes: (50 * 1_024 * 1_024) + addedPeakMemoryBytes,
        samples: corpus.samples.map { sample in
          SampleMeasurement(
            id: sample.id,
            output: labelsByID[sample.id]?.expectedLaTeX,
            warmLatencyMilliseconds: latency
          )
        }
      )
    }

    return CandidateEvidence(
      schemaVersion: 1,
      candidateID: candidate.id,
      installedSizeGrowthBytes: installedSizeGrowthBytes,
      licenseIsRedistributable: true,
      provenanceIsReproducible: true,
      networkingDeniedRecognitionPassed: true,
      persistedUserContent: false,
      hasCloudFallback: false,
      hasAnalyticsOrTelemetry: false,
      supportsMacOS14: true,
      isUniversal2Deployable: true,
      sandboxCompatible: true,
      runs: [
        run(.arm64, latency: armLatency),
        run(.x8664, latency: intelLatency),
      ]
    )
  }

  private func makeBinding(for freeze: EvaluationFreeze) -> VerifiedInputDigests {
    VerifiedInputDigests(
      corpusManifestSHA256: freeze.corpusManifestSHA256,
      sealedLabelsSHA256: freeze.sealedLabelsSHA256,
      scorerSHA256: freeze.scorerSHA256,
      protocolSHA256: freeze.protocolSHA256,
      artifactManifestSHA256: freeze.candidate.artifactManifestSHA256
    )
  }

  private func artifact(
    _ role: CandidateArtifactRole,
    _ path: String,
    under root: URL
  ) -> CandidateArtifact {
    CandidateArtifact(
      role: role,
      kind: .file,
      relativePath: path,
      sha256: try! ArtifactDigest.sha256(fileURL: root.appendingPathComponent(path))
    )
  }

  private func makeSupportedProtocolData() throws -> Data {
    let repositoryRoot = (0..<5).reduce(URL(fileURLWithPath: #filePath)) { url, _ in
      url.deletingLastPathComponent()
    }
    return try Data(
      contentsOf: repositoryRoot.appendingPathComponent(
        "docs/latex-feasibility/protocol.json"
      )
    )
  }

  private func digest(_ value: Int) -> String {
    String(format: "%064x", value)
  }

  private func assertValidationError(
    _ expected: FeasibilityValidationError,
    file: StaticString = #filePath,
    line: UInt = #line,
    _ operation: () throws -> Void
  ) {
    XCTAssertThrowsError(try operation(), file: file, line: line) { error in
      XCTAssertEqual(error as? FeasibilityValidationError, expected, file: file, line: line)
    }
  }
}
