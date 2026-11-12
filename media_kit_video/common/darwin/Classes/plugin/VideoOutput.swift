import CoreGraphics
import Foundation

#if canImport(Flutter)
  import Flutter
#elseif canImport(FlutterMacOS)
  import FlutterMacOS
#endif

// This class creates and manipulates the different types of FlutterTexture,
// handles resizing, rendering calls, and notify Flutter when a new frame is
// available to render.
//
// To improve the user experience, a worker is used to execute heavy tasks on a
// dedicated thread.
public class VideoOutput: NSObject {
  // Will be called on the main thread
  public typealias TextureUpdateCallback = (Int64, CGSize) -> Void

  private static let isSimulator: Bool = {
    let isSim: Bool
    #if targetEnvironment(simulator)
      isSim = true
    #else
      isSim = false
    #endif
    return isSim
  }()

  private let handle: OpaquePointer
  private let enableHardwareAcceleration: Bool
  private let registry: FlutterTextureRegistry
  private let textureUpdateCallback: TextureUpdateCallback
  private let worker: Worker = .init()
  private var width: Int64?
  private var height: Int64?
  private var texture: ResizableTextureProtocol!
  private var textureId: Int64 = -1
  private var currentSize: CGSize = CGSize.zero
  private let stateLock = NSLock()
  private var closing = false
  private var closed = false
  private var closeCallbacks = [() -> Void]()
  private var notificationPending = false
  private var latestSize = CGSize.zero
  // Platform-thread only. All rendering dimensions above remain worker-owned.
  private var platformSize = CGSize.zero

  init(
    handle: Int64,
    configuration: VideoOutputConfiguration,
    registry: FlutterTextureRegistry,
    textureUpdateCallback: @escaping TextureUpdateCallback
  ) {
    let handle = OpaquePointer(bitPattern: Int(handle))
    assert(handle != nil, "handle casting")

    self.handle = handle!
    width = configuration.width
    height = configuration.height
    enableHardwareAcceleration = configuration.enableHardwareAcceleration
    self.registry = registry
    self.textureUpdateCallback = textureUpdateCallback

    super.init()

    worker.enqueue(key: "initialize") { [weak self] in
      self?._init()
    }
  }

  deinit {
    // Fallback for a manager/engine being torn down without an explicit close.
    let texture = self.texture
    worker.finish { texture?.dispose() }
    let registry = self.registry
    let id = textureId
    if id >= 0 { DispatchQueue.main.async { registry.unregisterTexture(id) } }
  }

  public func setSize(width: Int64?, height: Int64?) {
    worker.enqueue(key: "size") { [weak self] in
      self?.width = width
      self?.height = height
    }
  }

  private func _init() {
    guard !isClosing else { return }
    let enableHardwareAcceleration =
      VideoOutput.isSimulator ? false : enableHardwareAcceleration

    NSLog(
      "VideoOutput: enableHardwareAcceleration: \(enableHardwareAcceleration)"
    )

    if VideoOutput.isSimulator {
      NSLog(
        "VideoOutput: warning: hardware rendering is disabled in the iOS simulator, due to an incompatibility with OpenGL ES"
      )
    }

    if enableHardwareAcceleration {
      texture = SafeResizableTexture(
        TextureHW(
          handle: handle,
          // Use `weak self` to prevent memory leaks
          updateCallback: { [weak self]() in
            guard let that = self else {
              return
            }
            that.updateCallback()
          }
        )
      )
    } else {
      texture = SafeResizableTexture(
        TextureSW(
          handle: handle,
          // Use `weak self` to prevent memory leaks
          updateCallback: { [weak self]() in
            guard let that = self else {
              return
            }
            that.updateCallback()
          }
        )
      )
    }

    DispatchQueue.main.async { [weak self]() in
      guard let that = self else {
        return
      }
      that.registerTextureId()
    }
  }

  // Must be run on the main thread
  private func registerTextureId() {
    guard !isClosing else { return }
    // Textures must be registered on the platform thread.
    textureId = registry.register(texture)
    // textureUpdateCallback must run on the main thread
    textureUpdateCallback(textureId, CGSize(width: 0, height: 0))
  }

  public func dispose(completion: @escaping () -> Void) {
    let state = locked { () -> (closed: Bool, start: Bool) in
      if closed { return (true, false) }
      closeCallbacks.append(completion)
      if closing { return (false, false) }
      closing = true
      return (false, true)
    }
    if state.closed {
      DispatchQueue.main.async(execute: completion)
    } else if state.start {
      worker.finish {
        self.texture?.dispose()
        self.texture = nil
        DispatchQueue.main.async {
          if self.textureId >= 0 {
            self.registry.unregisterTexture(self.textureId)
            self.textureId = -1
          }
          let callbacks = self.locked { () -> [() -> Void] in
            self.closed = true
            let callbacks = self.closeCallbacks
            self.closeCallbacks.removeAll()
            return callbacks
          }
          callbacks.forEach { $0() }
        }
      }
    }
  }

  public func updateCallback() {
    guard !isClosing else { return }
    worker.enqueue(key: "render") { [weak self] in
      self?._updateCallback()
    }
  }

  private func _updateCallback() {
    guard !isClosing else { return }
    let size = videoSize

    if size.width == 0 || size.height == 0 {
      return
    }

    if currentSize != size {
      currentSize = size

      texture.resize(size)
    }

    texture.render(size)
    let notify = locked { () -> Bool in
      guard !closing else { return false }
      latestSize = size
      guard !notificationPending else { return false }
      notificationPending = true
      return true
    }
    guard notify else { return }
    DispatchQueue.main.async { [weak self] in
      guard let that = self else { return }
      let size = that.locked { () -> CGSize? in
        that.notificationPending = false
        return that.closing ? nil : that.latestSize
      }
      guard let size = size, that.textureId >= 0 else { return }
      if that.platformSize != size {
        that.platformSize = size
        that.textureUpdateCallback(that.textureId, size)
      }
      that.registry.textureFrameAvailable(that.textureId)
    }
  }

  private var isClosing: Bool { locked { closing } }

  private func locked<T>(_ body: () -> T) -> T {
    stateLock.lock()
    defer { stateLock.unlock() }
    return body()
  }

    private var videoSize: CGSize {
        // fixed size
        if width != nil && height != nil {
            return CGSize(
                width: Double(width!),
                height: Double(height!)
            )
        }
        
        let params = MPVHelpers.getVideoOutParams(handle)
        return CGSize(
            width: Double(width ?? (params.rotate == 0 || params.rotate == 180
                                    ? params.dw
                                    : params.dh)),
            height: Double(height ?? (params.rotate == 0 || params.rotate == 180
                                      ? params.dh
                                      : params.dw))
        )
  }
}
