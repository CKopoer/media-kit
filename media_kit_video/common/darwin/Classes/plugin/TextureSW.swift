import CoreGraphics
import CoreVideo
import Foundation

#if SWIFT_PACKAGE
  import Mpv
#endif

#if canImport(Flutter)
  import Flutter
#elseif canImport(FlutterMacOS)
  import FlutterMacOS
#endif

public class TextureSW: NSObject, FlutterTexture, ResizableTextureProtocol {
  public typealias UpdateCallback = () -> Void

  private let handle: OpaquePointer
  private let updateCallback: UpdateCallback
  private var renderContext: OpaquePointer?
  private let frames = CompletedFrameStore<CVPixelBuffer>()
  private var disposed = false

  init(
    handle: OpaquePointer,
    updateCallback: @escaping UpdateCallback
  ) {
    self.handle = handle
    self.updateCallback = updateCallback

    super.init()

    self.initMPV()
  }

  deinit {
    dispose()
  }

  public func dispose() {
    guard !disposed else { return }
    disposed = true
    disposePixelBuffer()
    disposeMPV()
  }

  public func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    return frames.withCurrent { buffer in
      guard let buffer = buffer else { return nil }
      return Unmanaged.passRetained(buffer)
    }
  }

  private func initMPV() {
    MPV_RENDER_API_TYPE_SW.withCString { api in
      var params: [mpv_render_param] = [
        mpv_render_param(type: MPV_RENDER_PARAM_API_TYPE,
                         data: UnsafeMutableRawPointer(mutating: api)),
        mpv_render_param(type: MPV_RENDER_PARAM_INVALID, data: nil),
      ]
      MPVHelpers.checkError(
        mpv_render_context_create(&renderContext, handle, &params)
      )
    }

    mpv_render_context_set_update_callback(
      renderContext,
      { (ctx) in
        let that = unsafeBitCast(ctx, to: TextureSW.self)
        that.updateCallback()
      },
      UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
    )
  }

  private func disposeMPV() {
    guard let renderContext = renderContext else { return }
    mpv_render_context_set_update_callback(renderContext, nil, nil)
    mpv_render_context_free(renderContext)
    self.renderContext = nil
  }

  public func resize(_ size: CGSize) {
    // Keep the previous complete image until the new size has been rendered.
  }

  private func disposePixelBuffer() {
    frames.clear()
  }

  public func render(_ size: CGSize) {
    guard !disposed, size.width.isFinite && size.height.isFinite,
      size.width > 0 && size.height > 0,
      size.width <= CGFloat(Int32.max) && size.height <= CGFloat(Int32.max),
      let textureContext = TextureSWContext(size: size)
    else { return }
    guard CVPixelBufferLockBaseAddress(
      textureContext.pixelBuffer,
      CVPixelBufferLockFlags(rawValue: 0)
    ) == kCVReturnSuccess else { return }

    var ssize: [Int32] = [Int32(size.width), Int32(size.height)]
    let format: String = "bgr0"
    var pitch: Int = CVPixelBufferGetBytesPerRow(textureContext.pixelBuffer)
    guard let buffer = CVPixelBufferGetBaseAddress(textureContext.pixelBuffer) else {
      CVPixelBufferUnlockBaseAddress(textureContext.pixelBuffer, CVPixelBufferLockFlags(rawValue: 0))
      return
    }
    let status = ssize.withUnsafeMutableBytes { dimensions in
      format.withCString { format in
        withUnsafeMutablePointer(to: &pitch) { pitch in
          var params: [mpv_render_param] = [
            mpv_render_param(type: MPV_RENDER_PARAM_SW_SIZE, data: dimensions.baseAddress),
            mpv_render_param(type: MPV_RENDER_PARAM_SW_FORMAT,
                             data: UnsafeMutableRawPointer(mutating: format)),
            mpv_render_param(type: MPV_RENDER_PARAM_SW_STRIDE, data: pitch),
            mpv_render_param(type: MPV_RENDER_PARAM_SW_POINTER, data: buffer),
            mpv_render_param(type: MPV_RENDER_PARAM_INVALID, data: nil),
          ]
          return mpv_render_context_render(renderContext, &params)
        }
      }
    }

    CVPixelBufferUnlockBaseAddress(
      textureContext.pixelBuffer,
      CVPixelBufferLockFlags(rawValue: 0)
    )
    if status >= 0 { frames.publish(textureContext.pixelBuffer) }
  }
}
