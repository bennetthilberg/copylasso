import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest

@testable import CopyLasso

@MainActor
final class SystemInteractiveCaptureServiceTests: XCTestCase {
  func testProductionConfigurationUsesOnlyTheFixedSystemSelectorContract() {
    let configuration = SystemInteractiveCaptureConfiguration.copyLasso

    XCTAssertEqual(
      configuration.executableURL,
      URL(fileURLWithPath: "/usr/sbin/screencapture")
    )
    XCTAssertEqual(
      configuration.arguments,
      ["-i", "-s", "-x", "-t", "png", "/dev/stdout"]
    )
    XCTAssertEqual(configuration.maximumOutputBytes, 128 * 1_024 * 1_024)
    XCTAssertEqual(configuration.maximumPixelCount, 100_000_000)
  }

  func testPrepareStartsTheSystemSelectorSynchronouslyAndCaptureUsesThatSession() async throws {
    let image = try makeImage(width: 8, height: 6)
    let session = StubSystemInteractiveCaptureProcessSession(
      result: .success(
        SystemInteractiveCaptureProcessResult(
          terminationStatus: 0,
          terminationReason: .exit,
          output: Data([0x89, 0x50, 0x4E, 0x47])
        )
      )
    )
    let launcher = RecordingSystemInteractiveCaptureProcessLauncher(sessions: [session])
    let decoder = StubSystemInteractiveCaptureImageDecoder(result: .success(image))
    let service = SystemInteractiveCaptureService(
      launcher: launcher,
      decoder: decoder
    )

    service.prepareForCaptureTransition()

    XCTAssertEqual(launcher.configurations, [.copyLasso])
    let outcome = try await service.capture()

    guard case .captured(let capturedImage) = outcome else {
      return XCTFail("Expected captured image")
    }
    XCTAssertEqual(capturedImage.width, 8)
    XCTAssertEqual(capturedImage.height, 6)
    XCTAssertEqual(launcher.configurations, [.copyLasso])
    XCTAssertEqual(decoder.maximumPixelCounts, [100_000_000])
  }

  func testRepeatedPreparationDoesNotStartOverlappingSelectors() {
    let session = StubSystemInteractiveCaptureProcessSession(
      result: .success(.cancelledFixture)
    )
    let launcher = RecordingSystemInteractiveCaptureProcessLauncher(sessions: [session])
    let service = SystemInteractiveCaptureService(
      launcher: launcher,
      decoder: StubSystemInteractiveCaptureImageDecoder(result: .failure(.injected))
    )

    service.prepareForCaptureTransition()
    service.prepareForCaptureTransition()

    XCTAssertEqual(launcher.configurations, [.copyLasso])
  }

  func testCaptureStartsSelectorWhenMenuInvocationDidNotPreflight() async throws {
    let session = StubSystemInteractiveCaptureProcessSession(
      result: .success(.cancelledFixture)
    )
    let launcher = RecordingSystemInteractiveCaptureProcessLauncher(sessions: [session])
    let service = SystemInteractiveCaptureService(
      launcher: launcher,
      decoder: StubSystemInteractiveCaptureImageDecoder(result: .failure(.injected))
    )

    let outcome = try await service.capture()

    XCTAssertEqual(launcher.configurations, [.copyLasso])
    guard case .cancelled(.escape) = outcome else {
      return XCTFail("Expected an inert cancellation for empty interactive output")
    }
  }

  func testNonzeroProcessFailureWithOutputIsNotMisreportedAsCancellation() async {
    let result = SystemInteractiveCaptureProcessResult(
      terminationStatus: 2,
      terminationReason: .exit,
      output: Data([0x89, 0x50, 0x4E, 0x47])
    )
    let service = makeService(result: result)

    await assertThrowsErrorAsync(try await service.capture()) { error in
      XCTAssertEqual(error as? InteractiveCaptureError, .processFailed(status: 2))
    }
  }

  func testInvalidPNGIsRejectedWithoutReturningPixels() async {
    let result = SystemInteractiveCaptureProcessResult(
      terminationStatus: 0,
      terminationReason: .exit,
      output: Data([0x89, 0x50, 0x4E, 0x47])
    )
    let service = SystemInteractiveCaptureService(
      launcher: RecordingSystemInteractiveCaptureProcessLauncher(
        sessions: [StubSystemInteractiveCaptureProcessSession(result: .success(result))]
      ),
      decoder: StubSystemInteractiveCaptureImageDecoder(result: .failure(.injected))
    )

    await assertThrowsErrorAsync(try await service.capture()) { error in
      XCTAssertEqual(error as? InteractiveCaptureError, .invalidImage)
    }
  }

  func testCancelTerminatesPreparedSessionAndAllowsFreshPreparation() {
    let first = StubSystemInteractiveCaptureProcessSession(result: .success(.cancelledFixture))
    let second = StubSystemInteractiveCaptureProcessSession(result: .success(.cancelledFixture))
    let launcher = RecordingSystemInteractiveCaptureProcessLauncher(sessions: [first, second])
    let service = SystemInteractiveCaptureService(
      launcher: launcher,
      decoder: StubSystemInteractiveCaptureImageDecoder(result: .failure(.injected))
    )

    service.prepareForCaptureTransition()
    service.cancelCapture()
    service.prepareForCaptureTransition()

    XCTAssertEqual(first.cancelCallCount, 1)
    XCTAssertEqual(second.cancelCallCount, 0)
    XCTAssertEqual(launcher.configurations, [.copyLasso, .copyLasso])
  }

  func testCancelledStaleCompletionCannotConsumeAReplacementSession() async throws {
    let first = HoldingSystemInteractiveCaptureProcessSession()
    let second = StubSystemInteractiveCaptureProcessSession(result: .success(.cancelledFixture))
    let launcher = RecordingSystemInteractiveCaptureProcessLauncher(sessions: [first, second])
    let service = SystemInteractiveCaptureService(
      launcher: launcher,
      decoder: StubSystemInteractiveCaptureImageDecoder(result: .failure(.injected))
    )

    service.prepareForCaptureTransition()
    let staleCapture = Task { @MainActor in
      try await service.capture()
    }
    await first.waitUntilResultRequested()
    service.cancelCapture()
    service.prepareForCaptureTransition()
    first.resume(returning: .cancelledFixture)

    guard case .cancelled(.systemInterrupted) = try await staleCapture.value else {
      return XCTFail("Expected the cancelled generation to stay stale")
    }
    guard case .cancelled(.escape) = try await service.capture() else {
      return XCTFail("Expected the replacement session to remain available")
    }
    XCTAssertEqual(launcher.configurations, [.copyLasso, .copyLasso])
  }

  func testLiveProcessSessionCapturesStandardOutputWithoutAFile() async throws {
    let configuration = SystemInteractiveCaptureConfiguration(
      executableURL: URL(fileURLWithPath: "/usr/bin/printf"),
      arguments: ["system-selector"],
      maximumOutputBytes: 64,
      maximumPixelCount: 100
    )
    let session = try SystemInteractiveCaptureProcessLauncher().start(configuration)

    let result = try await session.result()

    XCTAssertEqual(result.terminationStatus, 0)
    XCTAssertEqual(result.terminationReason, .exit)
    XCTAssertEqual(result.output, Data("system-selector".utf8))
  }

  func testLiveProcessSessionRejectsOutputBeyondTheConfiguredBound() async throws {
    let configuration = SystemInteractiveCaptureConfiguration(
      executableURL: URL(fileURLWithPath: "/usr/bin/printf"),
      arguments: ["oversized"],
      maximumOutputBytes: 4,
      maximumPixelCount: 100
    )
    let session = try SystemInteractiveCaptureProcessLauncher().start(configuration)

    await assertThrowsErrorAsync(try await session.result()) { error in
      XCTAssertEqual(error as? SystemInteractiveCaptureProcessError, .outputTooLarge)
    }
  }

  func testImageDecoderAcceptsPNGAndEnforcesThePixelBound() async throws {
    let data = try makePNG(width: 8, height: 6)
    let decoder = SystemInteractiveCaptureImageDecoder()

    let image = try await decoder.decode(data, maximumPixelCount: 48)

    XCTAssertEqual(image.width, 8)
    XCTAssertEqual(image.height, 6)
    await assertThrowsErrorAsync(
      try await decoder.decode(data, maximumPixelCount: 47)
    ) { error in
      XCTAssertEqual(error as? InteractiveCaptureError, .invalidImage)
    }
  }

  func testImageDecoderRejectsNonPNGData() async {
    let decoder = SystemInteractiveCaptureImageDecoder()

    await assertThrowsErrorAsync(
      try await decoder.decode(Data("not private pixels".utf8), maximumPixelCount: 100)
    ) { error in
      XCTAssertEqual(error as? InteractiveCaptureError, .invalidImage)
    }
  }

  private func makeService(
    result: SystemInteractiveCaptureProcessResult
  ) -> SystemInteractiveCaptureService {
    SystemInteractiveCaptureService(
      launcher: RecordingSystemInteractiveCaptureProcessLauncher(
        sessions: [StubSystemInteractiveCaptureProcessSession(result: .success(result))]
      ),
      decoder: StubSystemInteractiveCaptureImageDecoder(result: .failure(.injected))
    )
  }

  private func makePNG(width: Int, height: Int) throws -> Data {
    let image = try makeImage(width: width, height: height)
    let data = NSMutableData()
    let destination = try XCTUnwrap(
      CGImageDestinationCreateWithData(
        data,
        UTType.png.identifier as CFString,
        1,
        nil
      )
    )
    CGImageDestinationAddImage(destination, image, nil)
    XCTAssertTrue(CGImageDestinationFinalize(destination))
    return data as Data
  }

  private func makeImage(width: Int, height: Int) throws -> CGImage {
    let context = try XCTUnwrap(
      CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
      )
    )
    context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    return try XCTUnwrap(context.makeImage())
  }
}

@MainActor
private final class RecordingSystemInteractiveCaptureProcessLauncher:
  SystemInteractiveCaptureProcessLaunching
{
  private var sessions: [any SystemInteractiveCaptureProcessSession]
  private(set) var configurations: [SystemInteractiveCaptureConfiguration] = []

  init(sessions: [any SystemInteractiveCaptureProcessSession]) {
    self.sessions = sessions
  }

  func start(
    _ configuration: SystemInteractiveCaptureConfiguration
  ) throws -> any SystemInteractiveCaptureProcessSession {
    configurations.append(configuration)
    guard !sessions.isEmpty else { throw TestServiceError.injected }
    return sessions.removeFirst()
  }
}

private final class StubSystemInteractiveCaptureProcessSession:
  SystemInteractiveCaptureProcessSession,
  @unchecked Sendable
{
  private let storedResult: Result<SystemInteractiveCaptureProcessResult, TestServiceError>
  private let lock = NSLock()
  private var storedCancelCallCount = 0

  init(result: Result<SystemInteractiveCaptureProcessResult, TestServiceError>) {
    storedResult = result
  }

  var cancelCallCount: Int {
    lock.withLock { storedCancelCallCount }
  }

  func result() async throws -> SystemInteractiveCaptureProcessResult {
    try storedResult.get()
  }

  func cancel() {
    lock.withLock { storedCancelCallCount += 1 }
  }
}

private final class HoldingSystemInteractiveCaptureProcessSession:
  SystemInteractiveCaptureProcessSession,
  @unchecked Sendable
{
  private let lock = NSLock()
  private var resultContinuation: CheckedContinuation<SystemInteractiveCaptureProcessResult, Error>?
  private var requestWaiters: [CheckedContinuation<Void, Never>] = []

  func result() async throws -> SystemInteractiveCaptureProcessResult {
    try await withCheckedThrowingContinuation { continuation in
      lock.withLock {
        resultContinuation = continuation
        let waiters = requestWaiters
        requestWaiters.removeAll()
        for waiter in waiters {
          waiter.resume()
        }
      }
    }
  }

  func cancel() {}

  func waitUntilResultRequested() async {
    await withCheckedContinuation { continuation in
      lock.withLock {
        if resultContinuation != nil {
          continuation.resume()
        } else {
          requestWaiters.append(continuation)
        }
      }
    }
  }

  func resume(returning result: SystemInteractiveCaptureProcessResult) {
    let continuation = lock.withLock {
      let continuation = resultContinuation
      resultContinuation = nil
      return continuation
    }
    continuation?.resume(returning: result)
  }
}

private final class StubSystemInteractiveCaptureImageDecoder:
  SystemInteractiveCaptureImageDecoding,
  @unchecked Sendable
{
  private let storedResult: Result<CGImage, TestServiceError>
  private let lock = NSLock()
  private var storedMaximumPixelCounts: [Int] = []

  init(result: Result<CGImage, TestServiceError>) {
    storedResult = result
  }

  var maximumPixelCounts: [Int] {
    lock.withLock { storedMaximumPixelCounts }
  }

  func decode(_ data: Data, maximumPixelCount: Int) async throws -> CGImage {
    lock.withLock { storedMaximumPixelCounts.append(maximumPixelCount) }
    return try storedResult.get()
  }
}

extension SystemInteractiveCaptureProcessResult {
  fileprivate static let cancelledFixture = SystemInteractiveCaptureProcessResult(
    terminationStatus: 1,
    terminationReason: .exit,
    output: Data()
  )
}

@MainActor
private func assertThrowsErrorAsync<T>(
  _ expression: @autoclosure () async throws -> T,
  _ errorHandler: (any Error) -> Void,
  file: StaticString = #filePath,
  line: UInt = #line
) async {
  do {
    _ = try await expression()
    XCTFail("Expected error", file: file, line: line)
  } catch {
    errorHandler(error)
  }
}
