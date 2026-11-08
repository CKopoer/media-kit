// BiliSail GPU delivery for PiliPlus media_kit_video fd8421d. See LICENSE and README.md.
// Draw and copy share ANGLE's D3D11 immediate context whenever available.
namespace {
ID3D11Device *BiliSailAngleDevice(EGLDisplay display) {
  static const auto query_display =
      reinterpret_cast<PFNEGLQUERYDISPLAYATTRIBEXTPROC>(
          eglGetProcAddress("eglQueryDisplayAttribEXT"));
  static const auto query_device =
      reinterpret_cast<PFNEGLQUERYDEVICEATTRIBEXTPROC>(
          eglGetProcAddress("eglQueryDeviceAttribEXT"));
  EGLAttrib device = 0;
  EGLAttrib d3d_device = 0;
  if (display == EGL_NO_DISPLAY || query_display == nullptr ||
      query_device == nullptr ||
      query_display(display, EGL_DEVICE_EXT, &device) != EGL_TRUE ||
      query_device(reinterpret_cast<EGLDeviceEXT>(device),
                   EGL_D3D11_DEVICE_ANGLE, &d3d_device) != EGL_TRUE) {
    return nullptr;
  }
  return reinterpret_cast<ID3D11Device *>(d3d_device);
}

class BiliSailMutexLock {
public:
  explicit BiliSailMutexLock(HANDLE mutex) : mutex_(mutex) {
    const auto result = WaitForSingleObject(mutex_, INFINITE);
    if (result != WAIT_OBJECT_0 && result != WAIT_ABANDONED) {
      throw std::runtime_error("Unable to lock video GPU commands.");
    }
  }
  ~BiliSailMutexLock() { ReleaseMutex(mutex_); }
  BiliSailMutexLock(const BiliSailMutexLock &) = delete;
  BiliSailMutexLock &operator=(const BiliSailMutexLock &) = delete;

private:
  HANDLE mutex_;
};

class BiliSailCurrentGlScope {
public:
  explicit BiliSailCurrentGlScope(ANGLESurfaceManager &surface)
      : surface_(surface) {
    surface_.MakeCurrent(true);
  }
  ~BiliSailCurrentGlScope() { surface_.MakeCurrent(false); }
  BiliSailCurrentGlScope(const BiliSailCurrentGlScope &) = delete;
  BiliSailCurrentGlScope &operator=(const BiliSailCurrentGlScope &) = delete;

private:
  ANGLESurfaceManager &surface_;
};
} // namespace

bool ANGLESurfaceManager::UseAngleDevice() {
  auto *device = BiliSailAngleDevice(display_);
  if (device == nullptr)
    return false;
  Microsoft::WRL::ComPtr<ID3D10Multithread> multithread;
  if (FAILED(device->QueryInterface(IID_PPV_ARGS(&multithread))))
    return false;
  multithread->SetMultithreadProtected(TRUE);
  device->AddRef();
  d3d_11_device_ = device;
  device->GetImmediateContext(&d3d_11_device_context_);
  uses_angle_device_ = true;
  return true;
}

void ANGLESurfaceManager::Draw(std::function<void()> callback) {
  const BiliSailMutexLock lock(mutex_);
  const BiliSailCurrentGlScope current(*this);
  callback();
  SwapBuffers();
  ++draw_revision_;
  has_frame_ = true;
}

HANDLE ANGLESurfaceManager::Read() {
  const BiliSailMutexLock lock(mutex_);
  const auto frame = snapshot_.Capture(internal_d3d_11_texture_2D_.Get(),
                                       draw_revision_);
  return frame ? frame->handle : nullptr;
}

void ANGLESurfaceManager::SwapBuffers() {
  if (uses_angle_device_) {
    // Submit rendering on the same queue used by the snapshot copy. Read()
    // verifies GPU completion before publishing the immutable allocation.
    glFlush();
  } else {
    // A legacy producer on another device still needs the original barrier.
    glFinish();
  }
}
