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
    disposePixelBuffer()
    disposeMPV()
    OpenGLESHelpers.deleteTextureCache(textureCache)

    // Deleting the context may cause potential RAM or VRAM memory leaks, as it
    // is used in the `deinit` method of the `TextureGLESContext`.
    // Potential fix: use a counter, and delete it only when the counter reaches
    // zero
    OpenGLESHelpers.deleteContext(context)
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

    let api = UnsafeMutableRawPointer(
      mutating: (MPV_RENDER_API_TYPE_OPENGL as NSString).utf8String
    )
    var procAddress = mpv_opengl_init_params(
      get_proc_address: {
        (ctx, name) in
        return TextureHW.getProcAddress(ctx, name)
      },
      get_proc_address_ctx: nil
    )

    var params: [mpv_render_param] = withUnsafeMutableBytes(of: &procAddress) {
      procAddress in
      return [
        mpv_render_param(type: MPV_RENDER_PARAM_API_TYPE, data: api),
        mpv_render_param(
          type: MPV_RENDER_PARAM_OPENGL_INIT_PARAMS,
          data: procAddress.baseAddress.map {
            UnsafeMutableRawPointer($0)
          }
        ),
        mpv_render_param(),
      ]
    }

    MPVHelpers.checkError(
      mpv_render_context_create(&renderContext, handle, &params)
    )

    mpv_render_context_set_update_callback(
      renderContext,
      { (ctx) in
        let that = unsafeBitCast(ctx, to: TextureHW.self)
        DispatchQueue.main.async {
          that.updateCallback()
        }
      },
      UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
    )
  }

  private func disposeMPV() {
    EAGLContext.setCurrent(context)
    defer {
      OpenGLESHelpers.checkError("disposeMPV")
      EAGLContext.setCurrent(nil)
    }

    mpv_render_context_set_update_callback(renderContext, nil, nil)
    mpv_render_context_free(renderContext)
  }

  public func resize(_ size: CGSize) {
    // Keep the previous complete image until render publishes the new size.
  }

  private func disposePixelBuffer() {
    frames.clear()
  }

  public func render(_ size: CGSize) {
    guard size.width > 0 && size.height > 0 else { return }
    autoreleasepool {
      // Each published IOSurface is write-once. Three buffers cannot prove that
      // Flutter's Metal queue has finished sampling an older surface.
      let textureContext = TextureGLESContext(
        context: context,
        textureCache: textureCache,
        size: size
      )

      EAGLContext.setCurrent(context)
      defer {
        OpenGLESHelpers.checkError("render")
        EAGLContext.setCurrent(nil)
      }

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
      let fboPtr = withUnsafeMutablePointer(to: &fbo) { $0 }

      var params: [mpv_render_param] = [
        mpv_render_param(type: MPV_RENDER_PARAM_OPENGL_FBO, data: fboPtr),
        mpv_render_param(type: MPV_RENDER_PARAM_INVALID, data: nil),
      ]

      mpv_render_context_render(renderContext, &params)

      // A different graphics API/queue will consume this IOSurface.
      glFinish()
      frames.publish(textureContext.pixelBuffer)
    }
    // The frame's GL wrappers are gone; do not accumulate CoreVideo cache entries.
    EAGLContext.setCurrent(context)
    CVOpenGLESTextureCacheFlush(textureCache, 0)
    EAGLContext.setCurrent(nil)
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
