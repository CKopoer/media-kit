import Foundation
import Flutter
import OpenGLES

#if SWIFT_PACKAGE
  import Mpv
#endif

public class TextureHW: NSObject, FlutterTexture, ResizableTextureProtocol {
  public typealias UpdateCallback = () -> Void

  private let handle: OpaquePointer
  private let updateCallback: UpdateCallback
  private let context: EAGLContext
  private let textureCache: CVOpenGLESTextureCache
  private var renderContext: OpaquePointer?
  private let frames = CompletedFrameStore<CVPixelBuffer>()
  private var disposed = false

  init(
    handle: OpaquePointer,
    updateCallback: @escaping UpdateCallback
  ) {
    self.handle = handle
    self.updateCallback = updateCallback
    self.context = OpenGLESHelpers.createContext()
    self.textureCache = OpenGLESHelpers.createTextureCache(context)

    super.init()

    self.initMPV()
  }

  deinit {
    dispose()
    OpenGLESHelpers.deleteContext(context)
  }

  public func dispose() {
    guard !disposed else { return }
    disposed = true
    disposePixelBuffer()
    disposeMPV()
    let previousContext = EAGLContext.current()
    EAGLContext.setCurrent(context)
    OpenGLESHelpers.deleteTextureCache(textureCache)
    EAGLContext.setCurrent(previousContext)
  }

  public func copyPixelBuffer() -> Unmanaged<CVPixelBuffer>? {
    return frames.withCurrent { buffer in
      guard let buffer = buffer else { return nil }
      return Unmanaged.passRetained(buffer)
    }
  }

  private func initMPV() {
    EAGLContext.setCurrent(context)
    defer {
      OpenGLESHelpers.checkError("initMPV")
      EAGLContext.setCurrent(nil)
    }

    var procAddress = mpv_opengl_init_params(
      get_proc_address: {
        (ctx, name) in
        return TextureHW.getProcAddress(ctx, name)
      },
      get_proc_address_ctx: nil
    )

    // All pointers must remain inside their borrowing scopes until C returns.
    MPV_RENDER_API_TYPE_OPENGL.withCString { api in
      withUnsafeMutablePointer(to: &procAddress) { address in
        var params: [mpv_render_param] = [
          mpv_render_param(type: MPV_RENDER_PARAM_API_TYPE,
                           data: UnsafeMutableRawPointer(mutating: api)),
          mpv_render_param(type: MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, data: address),
          mpv_render_param(),
        ]
        MPVHelpers.checkError(
          mpv_render_context_create(&renderContext, handle, &params)
        )
      }
    }

    mpv_render_context_set_update_callback(
      renderContext,
      { (ctx) in
        let that = unsafeBitCast(ctx, to: TextureHW.self)
        that.updateCallback()
      },
      UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
    )
  }

  private func disposeMPV() {
    guard let renderContext = renderContext else { return }
    EAGLContext.setCurrent(context)
    defer {
      OpenGLESHelpers.checkError("disposeMPV")
      EAGLContext.setCurrent(nil)
    }

    mpv_render_context_set_update_callback(renderContext, nil, nil)
    mpv_render_context_free(renderContext)
    self.renderContext = nil
  }

  public func resize(_ size: CGSize) {
    // Keep the previous complete image until render publishes the new size.
  }

  private func disposePixelBuffer() {
    frames.clear()
  }

  public func render(_ size: CGSize) {
    guard !disposed, size.width.isFinite && size.height.isFinite,
      size.width > 0 && size.height > 0,
      size.width <= CGFloat(Int32.max) && size.height <= CGFloat(Int32.max)
    else { return }
    let previousContext = EAGLContext.current()
    guard EAGLContext.setCurrent(context) else { return }
    defer {
      // Run after the autorelease pool releases the frame's GL wrapper, also
      // on allocation/FBO failure. Keep cache operations in the owning context.
      CVOpenGLESTextureCacheFlush(textureCache, 0)
      OpenGLESHelpers.checkError("render")
      EAGLContext.setCurrent(previousContext)
    }
    autoreleasepool {
      // Each published IOSurface is write-once. Three buffers cannot prove that
      // Flutter's Metal queue has finished sampling an older surface.
      guard let textureContext = TextureGLESContext(
        context: context,
        textureCache: textureCache,
        size: size
      ) else { return }

      glBindFramebuffer(GLenum(GL_FRAMEBUFFER), textureContext.frameBuffer)
      defer {
        glBindFramebuffer(GLenum(GL_FRAMEBUFFER), 0)
      }

      var fbo = mpv_opengl_fbo(
        fbo: Int32(textureContext.frameBuffer),
        w: Int32(size.width),
        h: Int32(size.height),
        internal_format: 0
      )
      let status = withUnsafeMutablePointer(to: &fbo) { fboPtr in
        var params: [mpv_render_param] = [
          mpv_render_param(type: MPV_RENDER_PARAM_OPENGL_FBO, data: fboPtr),
          mpv_render_param(type: MPV_RENDER_PARAM_INVALID, data: nil),
        ]
        return mpv_render_context_render(renderContext, &params)
      }
      guard status >= 0 else { return }

      // A different graphics API/queue will consume this IOSurface.
      glFinish()
      frames.publish(textureContext.pixelBuffer)
    }
  }

  static private func getProcAddress(
    _ ctx: UnsafeMutableRawPointer?,
    _ name: UnsafePointer<Int8>?
  ) -> UnsafeMutableRawPointer? {
    let symbol: CFString = CFStringCreateWithCString(
      kCFAllocatorDefault,
      name,
      kCFStringEncodingASCII
    )
    let indentifier = CFBundleGetBundleWithIdentifier(
      "com.apple.opengles" as CFString
    )
    let addr = CFBundleGetFunctionPointerForName(indentifier, symbol)

    if addr == nil {
      NSLog("Cannot get OpenGLES function pointer!")
    }
    return addr
  }
}
