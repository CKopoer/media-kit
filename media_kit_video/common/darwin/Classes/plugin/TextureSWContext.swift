import CoreGraphics
import CoreVideo
import Foundation

public class TextureSWContext {
  public let pixelBuffer: CVPixelBuffer

  init?(size: CGSize) {
    guard let buffer = TextureSWContext.createPixelBuffer(size) else { return nil }
    self.pixelBuffer = buffer
  }

  deinit {
    TextureSWContext.disposePixelBuffer(pixelBuffer)
  }

  private static func createPixelBuffer(_ size: CGSize) -> CVPixelBuffer? {
    let attrs =
      [
        kCVPixelBufferMetalCompatibilityKey: true,
        kCVPixelBufferIOSurfacePropertiesKey: [:],
      ] as CFDictionary

    var pixelBuffer: CVPixelBuffer?
    let cvret = CVPixelBufferCreate(
      kCFAllocatorDefault,
      Int(size.width),
      Int(size.height),
      kCVPixelFormatType_32BGRA,
      attrs,
      &pixelBuffer
    )
    guard cvret == kCVReturnSuccess else { return nil }
    return pixelBuffer
  }

  private static func disposePixelBuffer(_ pixelBuffer: CVPixelBuffer) {
    // 'CVPixelBufferRelease' is unavailable: Core Foundation objects are
    // automatically memory managed
  }
}
