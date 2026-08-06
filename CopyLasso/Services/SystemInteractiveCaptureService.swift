import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

struct SystemInteractiveCaptureConfiguration: Equatable, Sendable {
  let executableURL: URL
  let arguments: [String]
  let maximumOutputBytes: Int
  let maximumPixelCount: Int

  static let copyLasso = SystemInteractiveCaptureConfiguration(
    executableURL: URL(fileURLWithPath: "/usr/sbin/screencapture"),
    arguments: ["-i", "-s", "-x", "-t", "png", "/dev/stdout"],
    maximumOutputBytes: 128 * 1_024 * 1_024,
    maximumPixelCount: 100_000_000
  )
}

enum SystemInteractiveCaptureProcessTerminationReason: Equatable, Sendable {
  case exit
  case uncaughtSignal
}

struct SystemInteractiveCaptureProcessResult: Equatable, Sendable {
  let terminationStatus: Int32
  let terminationReason: SystemInteractiveCaptureProcessTerminationReason
  let output: Data
}

enum SystemInteractiveCaptureProcessError: Error, Equatable, Sendable {
  case outputTooLarge
  case launchFailed
  case readFailed
}

protocol SystemInteractiveCaptureProcessSession: AnyObject, Sendable {
  func result() async throws -> SystemInteractiveCaptureProcessResult
  func cancel()
}

@MainActor
protocol SystemInteractiveCaptureProcessLaunching: AnyObject {
  func start(
    _ configuration: SystemInteractiveCaptureConfiguration
  ) throws -> any SystemInteractiveCaptureProcessSession
}

@MainActor
final class SystemInteractiveCaptureProcessLauncher: SystemInteractiveCaptureProcessLaunching {
  func start(
    _ configuration: SystemInteractiveCaptureConfiguration
  ) throws -> any SystemInteractiveCaptureProcessSession {
    guard configuration.maximumOutputBytes > 0 else {
      throw SystemInteractiveCaptureProcessError.launchFailed
    }

    let process = Process()
    let outputPipe = Pipe()
    process.executableURL = configuration.executableURL
    process.arguments = configuration.arguments
    process.standardInput = FileHandle.nullDevice
    process.standardOutput = outputPipe
    process.standardError = FileHandle.nullDevice

    do {
      try process.run()
    } catch {
      try? outputPipe.fileHandleForReading.close()
      try? outputPipe.fileHandleForWriting.close()
      throw SystemInteractiveCaptureProcessError.launchFailed
    }

    try? outputPipe.fileHandleForWriting.close()
    return LiveSystemInteractiveCaptureProcessSession(
      process: process,
      outputHandle: outputPipe.fileHandleForReading,
      maximumOutputBytes: configuration.maximumOutputBytes
    )
  }
}

private final class LiveSystemInteractiveCaptureProcessSession:
  SystemInteractiveCaptureProcessSession,
  @unchecked Sendable
{
  private let resources: ProcessResources
  private let resultTask: Task<SystemInteractiveCaptureProcessResult, Error>

  init(process: Process, outputHandle: FileHandle, maximumOutputBytes: Int) {
    let resources = ProcessResources(
      process: process,
      outputHandle: outputHandle,
      maximumOutputBytes: maximumOutputBytes
    )
    self.resources = resources
    resultTask = Task.detached(priority: .userInitiated) {
      try resources.collectResult()
    }
  }

  func result() async throws -> SystemInteractiveCaptureProcessResult {
    try await withTaskCancellationHandler {
      let result = try await resultTask.value
      try Task.checkCancellation()
      return result
    } onCancel: { [resources] in
      resources.cancel()
    }
  }

  func cancel() {
    resources.cancel()
  }
}

private final class ProcessResources: @unchecked Sendable {
  private let process: Process
  private let outputHandle: FileHandle
  private let maximumOutputBytes: Int
  private let lock = NSLock()
  private var wasCancelled = false

  init(process: Process, outputHandle: FileHandle, maximumOutputBytes: Int) {
    self.process = process
    self.outputHandle = outputHandle
    self.maximumOutputBytes = maximumOutputBytes
  }

  func collectResult() throws -> SystemInteractiveCaptureProcessResult {
    var output = Data()
    defer {
      try? outputHandle.close()
    }
    do {
      while let chunk = try outputHandle.read(upToCount: 64 * 1_024), !chunk.isEmpty {
        guard chunk.count <= maximumOutputBytes - output.count else {
          throw SystemInteractiveCaptureProcessError.outputTooLarge
        }
        output.append(chunk)
      }
    } catch let error as SystemInteractiveCaptureProcessError {
      cancelAndWaitForExit()
      throw error
    } catch {
      cancelAndWaitForExit()
      throw SystemInteractiveCaptureProcessError.readFailed
    }

    process.waitUntilExit()
    let reason: SystemInteractiveCaptureProcessTerminationReason =
      process.terminationReason == .exit ? .exit : .uncaughtSignal
    return SystemInteractiveCaptureProcessResult(
      terminationStatus: process.terminationStatus,
      terminationReason: reason,
      output: output
    )
  }

  func cancel() {
    lock.withLock {
      guard !wasCancelled else { return }
      wasCancelled = true
      if process.isRunning {
        process.terminate()
      }
    }
  }

  private func cancelAndWaitForExit() {
    cancel()
    process.waitUntilExit()
  }
}

protocol SystemInteractiveCaptureImageDecoding: Sendable {
  func decode(_ data: Data, maximumPixelCount: Int) async throws -> CGImage
}

actor SystemInteractiveCaptureImageDecoder: SystemInteractiveCaptureImageDecoding {
  func decode(_ data: Data, maximumPixelCount: Int) throws -> CGImage {
    let pngSignature = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
    guard maximumPixelCount > 0, data.starts(with: pngSignature) else {
      throw InteractiveCaptureError.invalidImage
    }
    guard
      let source = CGImageSourceCreateWithData(data as CFData, nil),
      CGImageSourceGetCount(source) == 1,
      CGImageSourceGetType(source) as String? == UTType.png.identifier,
      let properties = CGImageSourceCopyPropertiesAtIndex(
        source,
        0,
        [kCGImageSourceShouldCache: false] as CFDictionary
      ) as? [CFString: Any],
      let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue,
      let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue,
      width > 0,
      height > 0,
      width <= maximumPixelCount / height,
      let image = CGImageSourceCreateImageAtIndex(
        source,
        0,
        [
          kCGImageSourceShouldCache: true,
          kCGImageSourceShouldCacheImmediately: true,
        ] as CFDictionary
      ),
      image.width == width,
      image.height == height
    else {
      throw InteractiveCaptureError.invalidImage
    }
    return image
  }
}

@MainActor
final class SystemInteractiveCaptureService: InteractiveCaptureService {
  private struct PreparedCapture {
    let id: UUID
    let session: any SystemInteractiveCaptureProcessSession
  }

  private enum Preparation {
    case capture(PreparedCapture)
    case failure(InteractiveCaptureError)
  }

  private let launcher: any SystemInteractiveCaptureProcessLaunching
  private let decoder: any SystemInteractiveCaptureImageDecoding
  private var preparation: Preparation?

  init(
    launcher: any SystemInteractiveCaptureProcessLaunching =
      SystemInteractiveCaptureProcessLauncher(),
    decoder: any SystemInteractiveCaptureImageDecoding =
      SystemInteractiveCaptureImageDecoder()
  ) {
    self.launcher = launcher
    self.decoder = decoder
  }

  func prepareForCaptureTransition() {
    guard preparation == nil else { return }
    do {
      preparation = .capture(
        PreparedCapture(
          id: UUID(),
          session: try launcher.start(.copyLasso)
        )
      )
    } catch {
      preparation = .failure(.captureFailed)
    }
  }

  func capture() async throws -> InteractiveCaptureOutcome {
    if preparation == nil {
      prepareForCaptureTransition()
    }
    guard let preparation else {
      throw InteractiveCaptureError.captureFailed
    }

    switch preparation {
    case .failure(let error):
      self.preparation = nil
      throw error
    case .capture(let prepared):
      let result: SystemInteractiveCaptureProcessResult
      do {
        result = try await prepared.session.result()
      } catch is CancellationError {
        clearPreparation(matching: prepared.id)
        return .cancelled(.systemInterrupted)
      } catch {
        clearPreparation(matching: prepared.id)
        throw InteractiveCaptureError.captureFailed
      }

      guard matchesCurrentPreparation(prepared.id) else {
        return .cancelled(.systemInterrupted)
      }
      self.preparation = nil

      if result.output.isEmpty,
        result.terminationReason == .exit,
        result.terminationStatus == 0 || result.terminationStatus == 1
      {
        return .cancelled(.escape)
      }
      guard result.terminationReason == .exit, result.terminationStatus == 0 else {
        throw InteractiveCaptureError.processFailed(status: result.terminationStatus)
      }

      do {
        return .captured(
          try await decoder.decode(
            result.output,
            maximumPixelCount: SystemInteractiveCaptureConfiguration.copyLasso.maximumPixelCount
          )
        )
      } catch {
        throw InteractiveCaptureError.invalidImage
      }
    }
  }

  func cancelCapture() {
    if case .capture(let prepared) = preparation {
      prepared.session.cancel()
    }
    preparation = nil
  }

  private func matchesCurrentPreparation(_ id: UUID) -> Bool {
    guard case .capture(let current) = preparation else { return false }
    return current.id == id
  }

  private func clearPreparation(matching id: UUID) {
    if matchesCurrentPreparation(id) {
      preparation = nil
    }
  }
}
