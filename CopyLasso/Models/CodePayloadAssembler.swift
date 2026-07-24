import CoreGraphics

enum CodePayloadAssemblyResult: Equatable, Sendable {
  case content(String)
  case noCode
  case ambiguous
}

protocol CodePayloadAssembling: Sendable {
  func assemble(_ observations: [RecognizedCodeObservation]) -> CodePayloadAssemblyResult
}

struct CodePayloadAssembler: CodePayloadAssembling {
  private let minimumRowOverlapRatio = 0.35

  func assemble(_ observations: [RecognizedCodeObservation]) -> CodePayloadAssemblyResult {
    let candidates = observations.compactMap(Candidate.init).sorted(by: candidatePrecedes)
    let orderedPayloads = deduplicatedPayloads(from: rows(for: candidates))

    guard let firstPayload = orderedPayloads.first else {
      return .noCode
    }
    guard orderedPayloads.count > 1 else {
      return .content(firstPayload)
    }
    guard !orderedPayloads.contains(where: containsLineBreak) else {
      return .ambiguous
    }
    return .content(orderedPayloads.joined(separator: "\n"))
  }

  private func rows(for candidates: [Candidate]) -> [Row] {
    var rows: [Row] = []
    for candidate in candidates {
      var bestIndex: Int?
      var bestOverlap = minimumRowOverlapRatio
      for index in rows.indices {
        let overlap = rows[index].maximumOverlapRatio(with: candidate)
        if overlap > bestOverlap || (overlap == bestOverlap && bestIndex == nil) {
          bestIndex = index
          bestOverlap = overlap
        }
      }
      if let bestIndex {
        rows[bestIndex].candidates.append(candidate)
      } else {
        rows.append(Row(candidates: [candidate]))
      }
    }
    // Candidates arrive top-to-bottom, so each row is created in final visual order.
    return rows
  }

  private func deduplicatedPayloads(from rows: [Row]) -> [String] {
    var seen: Set<String> = []
    var payloads: [String] = []
    for candidate in rows.flatMap(\.orderedCandidates) where seen.insert(candidate.payload).inserted
    {
      payloads.append(candidate.payload)
    }
    return payloads
  }

  private func candidatePrecedes(_ lhs: Candidate, _ rhs: Candidate) -> Bool {
    if lhs.bounds.maxY != rhs.bounds.maxY {
      return lhs.bounds.maxY > rhs.bounds.maxY
    }
    if lhs.bounds.minX != rhs.bounds.minX {
      return lhs.bounds.minX < rhs.bounds.minX
    }
    return stableTiePrecedes(lhs, rhs)
  }

  private func stableTiePrecedes(_ lhs: Candidate, _ rhs: Candidate) -> Bool {
    if lhs.payload != rhs.payload {
      return lhs.payload < rhs.payload
    }
    if lhs.symbology.stableName != rhs.symbology.stableName {
      return lhs.symbology.stableName < rhs.symbology.stableName
    }
    let lhsConfidence = Self.confidenceRank(lhs.confidence)
    let rhsConfidence = Self.confidenceRank(rhs.confidence)
    if lhsConfidence != rhsConfidence {
      return lhsConfidence > rhsConfidence
    }
    return lhs.geometryBits.lexicographicallyPrecedes(rhs.geometryBits)
  }

  private func containsLineBreak(_ payload: String) -> Bool {
    payload.contains("\n") || payload.contains("\r")
  }

  private static func confidenceRank(_ confidence: Float) -> UInt32 {
    confidence.isNaN ? 0 : confidence.bitPattern
  }
}

private struct Candidate {
  let payload: String
  let symbology: CodeSymbology
  let confidence: Float
  let bounds: CGRect

  init?(_ observation: RecognizedCodeObservation) {
    guard
      observation.symbology.isSupported,
      let payload = observation.payload,
      !payload.isEmpty,
      observation.boundingBox.origin.x.isFinite,
      observation.boundingBox.origin.y.isFinite,
      observation.boundingBox.width.isFinite,
      observation.boundingBox.height.isFinite,
      observation.boundingBox.width > 0,
      observation.boundingBox.height > 0
    else {
      return nil
    }
    self.payload = payload
    self.symbology = observation.symbology
    self.confidence = observation.confidence
    self.bounds = observation.boundingBox
  }

  var geometryBits: [UInt64] {
    [
      Self.bitPattern(bounds.origin.x),
      Self.bitPattern(bounds.origin.y),
      Self.bitPattern(bounds.width),
      Self.bitPattern(bounds.height),
    ]
  }

  private static func bitPattern(_ value: CGFloat) -> UInt64 {
    let value = Double(value)
    return value == 0 ? 0 : value.bitPattern
  }
}

private struct Row {
  var candidates: [Candidate]

  var orderedCandidates: [Candidate] {
    candidates.sorted { lhs, rhs in
      if lhs.bounds.minX != rhs.bounds.minX {
        return lhs.bounds.minX < rhs.bounds.minX
      }
      if lhs.bounds.maxY != rhs.bounds.maxY {
        return lhs.bounds.maxY > rhs.bounds.maxY
      }
      if lhs.payload != rhs.payload {
        return lhs.payload < rhs.payload
      }
      if lhs.symbology.stableName != rhs.symbology.stableName {
        return lhs.symbology.stableName < rhs.symbology.stableName
      }
      return lhs.geometryBits.lexicographicallyPrecedes(rhs.geometryBits)
    }
  }

  func maximumOverlapRatio(with candidate: Candidate) -> Double {
    candidates.map { Self.overlapRatio($0.bounds, candidate.bounds) }.max() ?? 0
  }

  private static func overlapRatio(_ lhs: CGRect, _ rhs: CGRect) -> Double {
    let overlap = max(0, min(lhs.maxY, rhs.maxY) - max(lhs.minY, rhs.minY))
    return Double(overlap / min(lhs.height, rhs.height))
  }
}
