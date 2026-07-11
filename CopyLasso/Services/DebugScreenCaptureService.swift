#if DEBUG
  import CoreGraphics

  actor DebugScreenCaptureService: ScreenCaptureService {
    func capture(_ selection: SelectionResult) async throws -> CGImage {
      let width = Int(selection.backingPixelRect.width)
      let height = Int(selection.backingPixelRect.height)
      guard width > 0, height > 0,
        let context = CGContext(
          data: nil,
          width: width,
          height: height,
          bitsPerComponent: 8,
          bytesPerRow: 0,
          space: CGColorSpaceCreateDeviceRGB(),
          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ),
        let image = context.makeImage()
      else {
        throw ScreenCaptureError.emptyOutput
      }
      return image
    }
  }
#endif
