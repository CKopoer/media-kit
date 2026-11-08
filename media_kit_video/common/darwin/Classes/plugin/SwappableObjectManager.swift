import Foundation

// Only completed, write-once frames enter this store. Retain under the lock so
// resize/disposal cannot release a frame while the raster thread acquires it.
// No old frame is returned to a producer-owned reuse pool.
public final class CompletedFrameStore<T> {
  private let lock = NSLock()
  private var current: T?

  public func publish(_ frame: T) {
    lock.lock()
    defer { lock.unlock() }
    current = frame
  }

  public func withCurrent<R>(_ read: (T?) -> R) -> R {
    lock.lock()
    defer { lock.unlock() }
    return read(current)
  }

  public func clear() {
    lock.lock()
    defer { lock.unlock() }
    current = nil
  }
}
