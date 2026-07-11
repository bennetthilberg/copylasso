import CoreGraphics

protocol TextAssembling: Sendable {
  func assemble(_ observations: [RecognizedTextObservation]) -> String
}

struct TextAssembler: TextAssembling {
  private let minimumLineOverlapRatio = 0.35
  private let blockGapHeightMultiplier = 1.5

  func assemble(_ observations: [RecognizedTextObservation]) -> String {
    let candidates = deduplicatedCandidates(from: observations)
    let positioned = candidates.filter(\.isPositioned).sorted(by: candidatePrecedes)
    let unpositioned = candidates.filter { !$0.isPositioned }.sorted(by: candidatePrecedes)

    let positionedText = assemblePositioned(positioned)
    let unpositionedText = unpositioned.map(\.text).joined(separator: "\n")
    switch (positionedText.isEmpty, unpositionedText.isEmpty) {
    case (false, false):
      return positionedText + "\n\n" + unpositionedText
    case (false, true):
      return positionedText
    case (true, false):
      return unpositionedText
    case (true, true):
      return ""
    }
  }

  private func assemblePositioned(_ candidates: [Candidate]) -> String {
    var lines: [Line] = []
    for candidate in candidates {
      var bestIndex: Int?
      var bestOverlap = minimumLineOverlapRatio
      for index in lines.indices {
        let overlap = lines[index].maximumOverlapRatio(with: candidate)
        if overlap > bestOverlap || (overlap == bestOverlap && bestIndex == nil) {
          bestIndex = index
          bestOverlap = overlap
        }
      }
      if let bestIndex {
        lines[bestIndex].candidates.append(candidate)
      } else {
        lines.append(Line(candidates: [candidate]))
      }
    }

    lines.sort(by: linePrecedes)
    var result = ""
    for index in lines.indices {
      if index > 0 {
        let upper = lines[index - 1]
        let lower = lines[index]
        let verticalGap = max(0, upper.bottom - lower.top)
        let blockThreshold =
          blockGapHeightMultiplier * max(upper.typicalHeight, lower.typicalHeight)
        result += verticalGap > blockThreshold ? "\n\n" : "\n"
      }
      result += lines[index].text
    }
    return result
  }

  private func deduplicatedCandidates(
    from observations: [RecognizedTextObservation]
  ) -> [Candidate] {
    var candidatesByKey: [CandidateKey: Candidate] = [:]
    for observation in observations {
      let text = Self.normalizedText(observation.text)
      guard !text.isEmpty else {
        continue
      }
      let candidate = Candidate(
        text: text,
        confidence: observation.confidence,
        bounds: observation.boundingBox
      )
      if let existing = candidatesByKey[candidate.key],
        Self.confidenceRank(existing.confidence) >= Self.confidenceRank(candidate.confidence)
      {
        continue
      }
      candidatesByKey[candidate.key] = candidate
    }
    return Array(candidatesByKey.values)
  }

  private func candidatePrecedes(_ lhs: Candidate, _ rhs: Candidate) -> Bool {
    if lhs.isPositioned != rhs.isPositioned {
      return lhs.isPositioned
    }
    if lhs.isPositioned {
      if lhs.bounds.maxY != rhs.bounds.maxY {
        return lhs.bounds.maxY > rhs.bounds.maxY
      }
      if lhs.bounds.minX != rhs.bounds.minX {
        return lhs.bounds.minX < rhs.bounds.minX
      }
      if lhs.bounds.minY != rhs.bounds.minY {
        return lhs.bounds.minY > rhs.bounds.minY
      }
      if lhs.bounds.width != rhs.bounds.width {
        return lhs.bounds.width < rhs.bounds.width
      }
      if lhs.bounds.height != rhs.bounds.height {
        return lhs.bounds.height < rhs.bounds.height
      }
    }
    if lhs.text != rhs.text {
      return lhs.text < rhs.text
    }
    let lhsConfidence = Self.confidenceRank(lhs.confidence)
    let rhsConfidence = Self.confidenceRank(rhs.confidence)
    if lhsConfidence != rhsConfidence {
      return lhsConfidence > rhsConfidence
    }
    return lhs.key.geometryBits.lexicographicallyPrecedes(rhs.key.geometryBits)
  }

  private func linePrecedes(_ lhs: Line, _ rhs: Line) -> Bool {
    if lhs.top != rhs.top {
      return lhs.top > rhs.top
    }
    if lhs.left != rhs.left {
      return lhs.left < rhs.left
    }
    return lhs.text < rhs.text
  }

  private static func normalizedText(_ text: String) -> String {
    text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
  }

  private static func confidenceRank(_ confidence: Float) -> UInt32 {
    if confidence.isNaN {
      return 0
    }
    return confidence.bitPattern
  }
}

private struct Candidate {
  let text: String
  let confidence: Float
  let bounds: CGRect

  var isPositioned: Bool {
    bounds.origin.x.isFinite && bounds.origin.y.isFinite
      && bounds.width.isFinite && bounds.height.isFinite
      && bounds.width > 0 && bounds.height > 0
  }

  var key: CandidateKey {
    CandidateKey(text: text, bounds: bounds)
  }
}

private struct CandidateKey: Hashable {
  let text: String
  let x: UInt64
  let y: UInt64
  let width: UInt64
  let height: UInt64

  init(text: String, bounds: CGRect) {
    self.text = text
    self.x = Self.bitPattern(bounds.origin.x)
    self.y = Self.bitPattern(bounds.origin.y)
    self.width = Self.bitPattern(bounds.width)
    self.height = Self.bitPattern(bounds.height)
  }

  var geometryBits: [UInt64] {
    [x, y, width, height]
  }

  private static func bitPattern(_ value: CGFloat) -> UInt64 {
    let value = Double(value)
    return value == 0 ? 0 : value.bitPattern
  }
}

private struct Line {
  var candidates: [Candidate]

  var top: CGFloat {
    candidates.map(\.bounds.maxY).max() ?? 0
  }

  var bottom: CGFloat {
    candidates.map(\.bounds.minY).min() ?? 0
  }

  var left: CGFloat {
    candidates.map(\.bounds.minX).min() ?? 0
  }

  var typicalHeight: CGFloat {
    candidates.map(\.bounds.height).max() ?? 0
  }

  var text: String {
    candidates.sorted(by: itemPrecedes).map(\.text).joined(separator: " ")
  }

  func maximumOverlapRatio(with candidate: Candidate) -> Double {
    candidates.map { Self.overlapRatio($0.bounds, candidate.bounds) }.max() ?? 0
  }

  private func itemPrecedes(_ lhs: Candidate, _ rhs: Candidate) -> Bool {
    if lhs.bounds.minX != rhs.bounds.minX {
      return lhs.bounds.minX < rhs.bounds.minX
    }
    if lhs.bounds.maxY != rhs.bounds.maxY {
      return lhs.bounds.maxY > rhs.bounds.maxY
    }
    return lhs.text < rhs.text
  }

  private static func overlapRatio(_ lhs: CGRect, _ rhs: CGRect) -> Double {
    let overlap = max(0, min(lhs.maxY, rhs.maxY) - max(lhs.minY, rhs.minY))
    return Double(overlap / min(lhs.height, rhs.height))
  }
}
