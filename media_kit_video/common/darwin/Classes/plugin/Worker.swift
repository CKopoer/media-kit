import Foundation

// One thread owns the renderer. Repeated render/resize notifications replace
// pending work; shutdown rejects new work and runs cleanup after the active job.
class Worker {
  public typealias Job = () -> Void

  private let semaphore = DispatchSemaphore(value: 0)
  private let lock = NSRecursiveLock()
  private var thread: Thread!
  private var queue = [(key: String?, job: Job)]()
  private var stopping = false

  init() {
    thread = Thread { [weak self] in self?.loop() }
    thread.start()
  }

  public func cancel() {
    finish {}
  }

  public func enqueue(key: String? = nil, _ job: @escaping Job) {
    let added = locked { () -> Bool in
      guard !stopping else { return false }
      if let key = key, let index = queue.firstIndex(where: { $0.key == key }) {
        queue[index].job = job
        return false
      }
      queue.append((key, job))
      return true
    }
    if added { semaphore.signal() }
  }

  public func finish(_ cleanup: @escaping Job) {
    let added = locked { () -> Bool in
      guard !stopping else { return false }
      stopping = true
      queue.removeAll()
      queue.append((nil, cleanup))
      return true
    }
    if added { semaphore.signal() }
  }

  private func loop() {
    while true {
      semaphore.wait()
      // Release the job and its captures before waiting again. Long-lived
      // threads also need to drain bridged Cocoa temporaries for every job.
      autoreleasepool {
        let job = locked { queue.isEmpty ? nil : queue.removeFirst().job }
        job?()
      }
      if locked(do: { stopping && queue.isEmpty }) { return }
    }
  }

  private func locked<T>(do block: () -> T) -> T {
    lock.lock()
    defer {
      lock.unlock()
    }

    return block()
  }
}
