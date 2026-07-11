import XCTest

@testable import CopyLasso

@MainActor
final class MenuBarShellTests: XCTestCase {
  func testQuitRoutesToTheInjectedApplicationTerminatorExactlyOnce() {
    let terminator = SpyApplicationTerminator()
    let coordinator = CaptureCoordinator()
    let handler = MenuBarCommandHandler(
      captureCommand: makeTestCaptureCommand(
        coordinator: coordinator,
        scheduleWork: { _ in }
      ),
      applicationTerminator: terminator
    )

    handler.quit()

    XCTAssertEqual(terminator.terminationCallCount, 1)
  }

  func testAboutMetadataUsesBundleVersionAndBuildValues() {
    let metadata = AboutMetadata(
      infoDictionary: [
        "CFBundleShortVersionString": "1.2.3",
        "CFBundleVersion": "45",
      ]
    )

    XCTAssertEqual(metadata.version, "1.2.3")
    XCTAssertEqual(metadata.build, "45")
    XCTAssertEqual(metadata.versionDescription, "Version 1.2.3 (45)")
  }

  func testAboutMetadataUsesSafeFallbacksForMissingValues() {
    let metadata = AboutMetadata(infoDictionary: [:])

    XCTAssertEqual(metadata.version, "Unknown")
    XCTAssertEqual(metadata.build, "Unknown")
    XCTAssertEqual(metadata.versionDescription, "Version Unknown (Unknown)")
  }
}

@MainActor
private final class SpyApplicationTerminator: ApplicationTerminating {
  private(set) var terminationCallCount = 0

  func terminate() {
    terminationCallCount += 1
  }
}
