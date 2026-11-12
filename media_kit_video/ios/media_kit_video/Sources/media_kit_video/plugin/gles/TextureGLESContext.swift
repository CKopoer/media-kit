import OpenGLES
import UIKit

public class TextureGLESContext {
  private let context: EAGLContext
  public let frameBuffer: GLuint
  public let texture: CVOpenGLESTexture
  public let pixelBuffer: CVPixelBuffer

  init?(
    context: EAGLContext,
    textureCache: CVOpenGLESTextureCache,
    size: CGSize
  ) {
    self.context = context

    // Allocation/import failures are recoverable during playback. Do not retry
    // allocations in a tight loop or terminate the host application.
    guard let pixelBuffer = OpenGLESHelpers.createPixelBuffer(size),
      let texture = OpenGLESHelpers.createTexture(
        textureCache,
        pixelBuffer,
        size
      ),
      let frameBuffer = try? OpenGLESHelpers.createFrameBuffer(
        context: context,
        texture: texture,
        size: size
      ) else { return nil }
    self.pixelBuffer = pixelBuffer
    self.texture = texture
    self.frameBuffer = frameBuffer
  }

  deinit {
    // CoreVideo owns the GL texture name. ARC releases its wrapper and the
    // render-scoped cache flush evicts unused entries; never delete it by name.
    OpenGLESHelpers.deleteFrameBuffer(context, frameBuffer)
  }
}
