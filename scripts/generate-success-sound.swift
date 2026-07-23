import Foundation

private let sampleRate: UInt32 = 44_100
private let channelCount: UInt16 = 1
private let bitsPerSample: UInt16 = 16
private let frameCount = 7_938

guard CommandLine.arguments.count == 2 else {
  FileHandle.standardError.write(
    Data("Usage: xcrun swift scripts/generate-success-sound.swift OUTPUT.wav\n".utf8)
  )
  exit(64)
}

private func triangleSample(phase: UInt32) -> Int64 {
  let position = Int64(phase >> 16)
  if position < 32_768 {
    return (position * 2) - 32_767
  }
  return 98_303 - (position * 2)
}

private func appendASCII(_ value: String, to data: inout Data) {
  data.append(contentsOf: value.utf8)
}

private func appendLittleEndian<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
  var littleEndian = value.littleEndian
  withUnsafeBytes(of: &littleEndian) {
    data.append(contentsOf: $0)
  }
}

private var samples = Data(capacity: frameCount * 2)
private var primaryPhase: UInt32 = 0
private var overtonePhase: UInt32 = 0
private let primaryIncrement = UInt32((UInt64(980) << 32) / UInt64(sampleRate))
private let overtoneIncrement = UInt32((UInt64(1_470) << 32) / UInt64(sampleRate))
private var noiseState: UInt32 = 0xC0_9A_55_01

for frame in 0..<frameCount {
  primaryPhase &+= primaryIncrement
  overtonePhase &+= overtoneIncrement

  let attack = min(frame, 132)
  let attackEnvelope = Int64(attack * 32_767 / 132)
  let remaining = frameCount - frame
  let decayEnvelope = Int64(remaining * remaining * 32_767 / (frameCount * frameCount))
  let envelope = min(attackEnvelope, decayEnvelope)

  let primary = triangleSample(phase: primaryPhase)
  let overtone = triangleSample(phase: overtonePhase)
  var mixed = ((primary * 3) + (overtone * 2)) / 5
  mixed = mixed * envelope / 32_767

  if frame < 220 {
    noiseState = (1_664_525 &* noiseState) &+ 1_013_904_223
    let noise = Int64(Int32(bitPattern: noiseState) >> 16)
    let transientEnvelope = Int64((220 - frame) * 32_767 / 220)
    mixed += noise * transientEnvelope / (32_767 * 8)
  }

  let scaled = max(-32_767, min(32_767, mixed * 9 / 32))
  appendLittleEndian(Int16(scaled), to: &samples)
}

private let bytesPerSample = UInt32(bitsPerSample / 8)
private let byteRate = sampleRate * UInt32(channelCount) * bytesPerSample
private let blockAlign = channelCount * UInt16(bytesPerSample)
private let dataSize = UInt32(samples.count)

private var wave = Data(capacity: 44 + samples.count)
appendASCII("RIFF", to: &wave)
appendLittleEndian(UInt32(36) + dataSize, to: &wave)
appendASCII("WAVE", to: &wave)
appendASCII("fmt ", to: &wave)
appendLittleEndian(UInt32(16), to: &wave)
appendLittleEndian(UInt16(1), to: &wave)
appendLittleEndian(channelCount, to: &wave)
appendLittleEndian(sampleRate, to: &wave)
appendLittleEndian(byteRate, to: &wave)
appendLittleEndian(blockAlign, to: &wave)
appendLittleEndian(bitsPerSample, to: &wave)
appendASCII("data", to: &wave)
appendLittleEndian(dataSize, to: &wave)
wave.append(samples)

try wave.write(to: URL(fileURLWithPath: CommandLine.arguments[1]), options: .atomic)
