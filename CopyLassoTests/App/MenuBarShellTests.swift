import AppKit
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

  func testAboutMetadataProvidesFinalBrandAndLegalDetails() {
    let metadata = AboutMetadata(
      infoDictionary: [
        "CFBundleShortVersionString": "0.1.0",
        "CFBundleVersion": "1",
      ]
    )

    XCTAssertEqual(metadata.applicationName, "CopyLasso")
    XCTAssertEqual(metadata.copyright, "Copyright © 2026 Bennett Hilberg")
    XCTAssertEqual(metadata.licenseName, "MIT License")
    XCTAssertEqual(
      metadata.summary,
      "Free and open source. Private, offline, and local."
    )
    XCTAssertEqual(
      metadata.repositoryURL.absoluteString,
      "https://github.com/bennetthilberg/copylasso"
    )
    XCTAssertEqual(
      metadata.privacyURL.absoluteString,
      "https://github.com/bennetthilberg/copylasso/blob/main/PRIVACY.md"
    )
    XCTAssertEqual(
      metadata.licenseURL.absoluteString,
      "https://github.com/bennetthilberg/copylasso/blob/main/LICENSE"
    )
    XCTAssertEqual(metadata.acknowledgement.title, "KeyboardShortcuts 3.0.1")
    XCTAssertEqual(metadata.acknowledgement.author, "Sindre Sorhus")
    XCTAssertEqual(metadata.acknowledgement.license, "MIT")
    XCTAssertTrue(metadata.acknowledgement.notice.contains("Permission is hereby granted"))
  }

  func testAboutMetadataUsesSafeFallbacksForMissingValues() {
    let metadata = AboutMetadata(infoDictionary: [:])

    XCTAssertEqual(metadata.version, "Unknown")
    XCTAssertEqual(metadata.build, "Unknown")
    XCTAssertEqual(metadata.versionDescription, "Version Unknown (Unknown)")
    XCTAssertEqual(metadata.applicationName, "CopyLasso")
    XCTAssertEqual(metadata.repositoryURL.host(), "github.com")
  }

  func testAboutViewDefersAndInjectsApplicationIconLoading() {
    let expectedIcon = NSImage(size: NSSize(width: 80, height: 80))
    var loadCount = 0
    let iconSource = ApplicationIconSource {
      loadCount += 1
      return expectedIcon
    }

    _ = AboutView(
      metadata: AboutMetadata(infoDictionary: [:]),
      applicationIconSource: iconSource
    )

    XCTAssertEqual(loadCount, 0)
    XCTAssertTrue(iconSource.load() === expectedIcon)
    XCTAssertEqual(loadCount, 1)
  }
}

@MainActor
private final class SpyApplicationTerminator: ApplicationTerminating {
  private(set) var terminationCallCount = 0

  func terminate() {
    terminationCallCount += 1
  }
}
