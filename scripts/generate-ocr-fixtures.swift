#!/usr/bin/env xcrun swift
import AppKit
import Foundation

enum FixtureGenerationError: Error {
  case bitmapCreationFailed
  case contextCreationFailed
  case imageEncodingFailed
  case viewRenderingFailed
}

let outputDirectory: URL = {
  if CommandLine.arguments.count > 1 {
    return URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
  }

  return URL(fileURLWithPath: "CopyLassoTests/Fixtures", isDirectory: true)
}()

try FileManager.default.createDirectory(
  at: outputDirectory,
  withIntermediateDirectories: true
)

func paragraphStyle(alignment: NSTextAlignment) -> NSParagraphStyle {
  let style = NSMutableParagraphStyle()
  style.alignment = alignment
  style.lineBreakMode = .byClipping
  return style
}

func drawText(
  _ text: String,
  in rect: NSRect,
  font: NSFont,
  color: NSColor,
  alignment: NSTextAlignment = .left
) {
  text.draw(
    in: rect,
    withAttributes: [
      .font: font,
      .foregroundColor: color,
      .paragraphStyle: paragraphStyle(alignment: alignment),
    ]
  )
}

func writeBitmap(
  named name: String,
  width: Int,
  height: Int,
  drawing: (NSRect) -> Void
) throws {
  guard
    let bitmap = NSBitmapImageRep(
      bitmapDataPlanes: nil,
      pixelsWide: width,
      pixelsHigh: height,
      bitsPerSample: 8,
      samplesPerPixel: 4,
      hasAlpha: true,
      isPlanar: false,
      colorSpaceName: .deviceRGB,
      bytesPerRow: width * 4,
      bitsPerPixel: 32
    )
  else {
    throw FixtureGenerationError.bitmapCreationFailed
  }

  guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
    throw FixtureGenerationError.contextCreationFailed
  }

  NSGraphicsContext.saveGraphicsState()
  NSGraphicsContext.current = context
  drawing(NSRect(x: 0, y: 0, width: width, height: height))
  context.flushGraphics()
  NSGraphicsContext.restoreGraphicsState()

  guard let data = bitmap.representation(using: .png, properties: [:]) else {
    throw FixtureGenerationError.imageEncodingFailed
  }

  try data.write(to: outputDirectory.appendingPathComponent(name), options: .atomic)
}

try writeBitmap(named: "clean-multiline.png", width: 1_200, height: 500) { bounds in
  NSColor(calibratedWhite: 0.98, alpha: 1).setFill()
  bounds.fill()

  let lines = [
    "Read every visible line",
    "Keep the original order",
    "Process all text offline",
  ]
  let font = NSFont.systemFont(ofSize: 48, weight: .regular)

  for (index, line) in lines.enumerated() {
    drawText(
      line,
      in: NSRect(x: 90, y: 340 - (index * 120), width: 1_020, height: 70),
      font: font,
      color: NSColor(calibratedWhite: 0.08, alpha: 1)
    )
  }
}

try writeBitmap(named: "small-text.png", width: 1_200, height: 320) { bounds in
  NSColor.white.setFill()
  bounds.fill()
  drawText(
    "Small screen text should remain readable",
    in: NSRect(x: 80, y: 145, width: 1_040, height: 35),
    font: NSFont.systemFont(ofSize: 18, weight: .regular),
    color: NSColor(calibratedWhite: 0.1, alpha: 1),
    alignment: .center
  )
}

try writeBitmap(named: "light-on-dark.png", width: 1_200, height: 360) { bounds in
  NSColor(calibratedRed: 0.08, green: 0.09, blue: 0.11, alpha: 1).setFill()
  bounds.fill()
  drawText(
    "LIGHT TEXT ON DARK BACKGROUND",
    in: NSRect(x: 70, y: 145, width: 1_060, height: 70),
    font: NSFont.systemFont(ofSize: 44, weight: .semibold),
    color: NSColor(calibratedWhite: 0.96, alpha: 1),
    alignment: .center
  )
}

try writeBitmap(named: "moderate-low-contrast.png", width: 1_200, height: 360) { bounds in
  NSColor(calibratedWhite: 0.72, alpha: 1).setFill()
  bounds.fill()
  drawText(
    "Moderate contrast should preserve these words",
    in: NSRect(x: 70, y: 145, width: 1_060, height: 70),
    font: NSFont.systemFont(ofSize: 40, weight: .medium),
    color: NSColor(calibratedWhite: 0.45, alpha: 1),
    alignment: .center
  )
}

func writeApplicationFixture() throws {
  let view = NSView(frame: NSRect(x: 0, y: 0, width: 1_200, height: 600))
  view.appearance = NSAppearance(named: .aqua)
  view.wantsLayer = true
  view.layer?.backgroundColor = NSColor(calibratedWhite: 0.94, alpha: 1).cgColor

  let title = NSTextField(labelWithString: "CopyLasso Settings")
  title.font = NSFont.systemFont(ofSize: 34, weight: .bold)
  title.textColor = NSColor(calibratedWhite: 0.08, alpha: 1)
  title.frame = NSRect(x: 70, y: 475, width: 1_060, height: 50)
  view.addSubview(title)

  let primaryLabel = NSTextField(labelWithString: "Capture text from any screen")
  primaryLabel.font = NSFont.systemFont(ofSize: 25, weight: .medium)
  primaryLabel.textColor = NSColor(calibratedWhite: 0.08, alpha: 1)
  primaryLabel.frame = NSRect(x: 70, y: 355, width: 1_060, height: 40)
  view.addSubview(primaryLabel)

  let secondaryLabel = NSTextField(labelWithString: "Recognition stays on this Mac")
  secondaryLabel.font = NSFont.systemFont(ofSize: 21, weight: .regular)
  secondaryLabel.textColor = NSColor(calibratedWhite: 0.3, alpha: 1)
  secondaryLabel.frame = NSRect(x: 70, y: 295, width: 1_060, height: 35)
  view.addSubview(secondaryLabel)

  let button = NSButton(title: "Save Changes", target: nil, action: nil)
  button.bezelStyle = .rounded
  button.font = NSFont.systemFont(ofSize: 21, weight: .regular)
  button.contentTintColor = NSColor(calibratedWhite: 0.08, alpha: 1)
  button.frame = NSRect(x: 70, y: 135, width: 210, height: 54)
  view.addSubview(button)

  view.layoutSubtreeIfNeeded()
  guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else {
    throw FixtureGenerationError.viewRenderingFailed
  }
  view.cacheDisplay(in: view.bounds, to: bitmap)

  guard let data = bitmap.representation(using: .png, properties: [:]) else {
    throw FixtureGenerationError.imageEncodingFailed
  }
  try data.write(
    to: outputDirectory.appendingPathComponent("rasterized-application-text.png"),
    options: .atomic
  )
}

try writeApplicationFixture()
