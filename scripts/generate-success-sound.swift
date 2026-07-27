import Foundation

private let sampleRate = 44_100
private let channelCount: UInt16 = 1
private let bitsPerSample: UInt16 = 16
private let duration = 0.188
private let frameCount = Int((duration * Double(sampleRate)).rounded())

guard CommandLine.arguments.count == 2 else {
  FileHandle.standardError.write(
    Data("Usage: xcrun swift scripts/generate-success-sound.swift OUTPUT.wav\n".utf8)
  )
  exit(64)
}

private struct SeededNoise {
  private var state: UInt64

  init(seed: UInt64) {
    state = seed
  }

  mutating func next() -> Double {
    state = (state &* 2_862_933_555_777_941_757) &+ 3_037_000_493
    let value = state >> 11
    return (Double(value) / Double(UInt64(1) << 53) * 2) - 1
  }
}

private func clamped(_ value: Double, minimum: Double = 0, maximum: Double = 1) -> Double {
  min(maximum, max(minimum, value))
}

private func smoothStep(_ value: Double) -> Double {
  let progress = clamped(value)
  return progress * progress * (3 - (2 * progress))
}

private func onset(_ localTime: Double, duration: Double) -> Double {
  guard localTime >= 0 else { return 0 }
  return smoothStep(localTime / duration)
}

private func softLimit(_ value: Double) -> Double {
  value / (1 + (0.22 * abs(value)))
}

private func filteredNoise(
  frameCount: Int,
  seed: UInt64,
  coefficient: Double
) -> [Double] {
  var generator = SeededNoise(seed: seed)
  var state = 0.0
  return (0..<frameCount).map { _ in
    state += coefficient * (generator.next() - state)
    return state
  }
}

private func addTinyRoom(
  to dry: [Double],
  taps: [(milliseconds: Double, gain: Double)]
) -> [Double] {
  var wet = dry
  for tap in taps {
    let delay = Int((tap.milliseconds / 1_000) * Double(sampleRate))
    guard delay > 0, delay < dry.count else { continue }
    for index in delay..<dry.count {
      wet[index] += dry[index - delay] * tap.gain
    }
  }
  return wet
}

private func mastered(
  _ samples: [Double],
  peak: Double,
  room: [(milliseconds: Double, gain: Double)]
) -> [Double] {
  let reflected = addTinyRoom(to: samples, taps: room)
  let limited = reflected.map(softLimit)
  let maximum = limited.lazy.map(abs).max() ?? 0
  guard maximum > 0 else { return limited }

  let gain = peak / maximum
  var output = limited.map { $0 * gain }
  let fadeFrames = max(1, Int(0.006 * Double(sampleRate)))
  for offset in 0..<min(fadeFrames, output.count) {
    let index = output.count - 1 - offset
    output[index] *= smoothStep(Double(offset) / Double(fadeFrames))
  }
  return output
}

private func warmStruckVoice(
  time: Double,
  start: Double,
  frequency: Double,
  strength: Double,
  texture: Double,
  brightness: Double
) -> Double {
  let localTime = time - start
  guard localTime >= 0 else { return 0 }

  let attack = onset(localTime, duration: 0.0026)
  let fundamental =
    sin(2 * Double.pi * frequency * localTime)
    * exp(-localTime * 24)
  let second =
    sin(2 * Double.pi * frequency * 2.01 * localTime + 0.31)
    * exp(-localTime * 48)
  let softInharmonic =
    sin(2 * Double.pi * frequency * 2.67 * localTime + 1.14)
    * exp(-localTime * 71)
  let tactileAttack = texture * exp(-localTime * 145)

  return strength * attack
    * (fundamental
      + (brightness * 0.25 * second)
      + (brightness * 0.09 * softInharmonic)
      + (0.20 * tactileAttack))
}

private let texture = filteredNoise(
  frameCount: frameCount,
  seed: 0x46_55_54_55_52_45_57_4B,
  coefficient: 0.16
)

private let drySamples = (0..<frameCount).map { index in
  let time = Double(index) / Double(sampleRate)
  let first = warmStruckVoice(
    time: time,
    start: 0,
    frequency: 455,
    strength: 0.49,
    texture: texture[index],
    brightness: 0.39
  )
  let second = warmStruckVoice(
    time: time,
    start: 0.036,
    frequency: 607,
    strength: 0.76,
    texture: texture[index],
    brightness: 0.45
  )
  let haloTime = time - 0.039
  let halo =
    haloTime >= 0
    ? (sin(2 * Double.pi * 910 * haloTime + 0.38)
      + (0.14 * sin(2 * Double.pi * 1_824 * haloTime + 1.02))) * onset(haloTime, duration: 0.004)
      * exp(-haloTime * 43) * 0.11
    : 0
  return first + second + halo
}

private let samples = mastered(
  drySamples,
  peak: 0.26,
  room: [(4.8, 0.058), (10.3, 0.028), (16.5, 0.012)]
)

private func appendASCII(_ value: String, to data: inout Data) {
  data.append(contentsOf: value.utf8)
}

private func appendLittleEndian<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
  var littleEndianValue = value.littleEndian
  withUnsafeBytes(of: &littleEndianValue) {
    data.append(contentsOf: $0)
  }
}

private let bytesPerSample = Int(bitsPerSample / 8)
private let dataByteCount = samples.count * Int(channelCount) * bytesPerSample
private let byteRate = UInt32(sampleRate * Int(channelCount) * bytesPerSample)
private let blockAlign = UInt16(Int(channelCount) * bytesPerSample)

private var wave = Data(capacity: 44 + dataByteCount)
appendASCII("RIFF", to: &wave)
appendLittleEndian(UInt32(36 + dataByteCount), to: &wave)
appendASCII("WAVE", to: &wave)
appendASCII("fmt ", to: &wave)
appendLittleEndian(UInt32(16), to: &wave)
appendLittleEndian(UInt16(1), to: &wave)
appendLittleEndian(channelCount, to: &wave)
appendLittleEndian(UInt32(sampleRate), to: &wave)
appendLittleEndian(byteRate, to: &wave)
appendLittleEndian(blockAlign, to: &wave)
appendLittleEndian(bitsPerSample, to: &wave)
appendASCII("data", to: &wave)
appendLittleEndian(UInt32(dataByteCount), to: &wave)

for sample in samples {
  let scaled = min(1, max(-1, sample)) * Double(Int16.max)
  appendLittleEndian(Int16(scaled.rounded()), to: &wave)
}

try wave.write(
  to: URL(fileURLWithPath: CommandLine.arguments[1]),
  options: .atomic
)
