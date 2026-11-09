// Copyright (c) 2026 BiliSail contributors. MIT license; see LICENSE.
// Execute the production initializer with fake mpv/ANGLE ports. No Flutter
// engine, graphics driver, native SDK or application build is needed.
#include <cassert>
#include <cstdint>
#include <memory>
#include <optional>
#include <stdexcept>
#include <string>

namespace {
struct Scenario {
  bool angle_fails = false;
  bool gl_fails = false;
  bool sw_fails = false;
  bool resize_fails = false;
  int surfaces = 0;
  int contexts = 0;
  int gl_attempts = 0;
  int sw_attempts = 0;
  int registrations = 0;
  int callbacks = 0;
} scenario;

struct mpv_handle {};
struct mpv_render_context {};
struct mpv_render_param {
  int type;
  const void* data;
};
struct mpv_opengl_init_params {
  void* (*get_proc_address)(void*, const char*);
  void* context;
};
constexpr int MPV_RENDER_PARAM_API_TYPE = 1;
constexpr int MPV_RENDER_PARAM_OPENGL_INIT_PARAMS = 2;
constexpr int MPV_RENDER_PARAM_INVALID = 0;
constexpr const char* MPV_RENDER_API_TYPE_OPENGL = "opengl";
constexpr const char* MPV_RENDER_API_TYPE_SW = "sw";
constexpr int SW_RENDERING_PIXEL_BUFFER_SIZE = 4;

void* eglGetProcAddress(const char*) {
  return nullptr;
}
int mpv_set_option_string(mpv_handle*, const char*, const char*) {
  return 0;
}
int mpv_render_context_create(mpv_render_context** context,
                              mpv_handle*,
                              mpv_render_param* params) {
  const bool gl =
      std::string(static_cast<const char*>(params[0].data)) == "opengl";
  if (gl) {
    ++scenario.gl_attempts;
    if (scenario.gl_fails)
      return -19;
  } else {
    ++scenario.sw_attempts;
    // Software initialization must see neither a GPU surface nor a texture.
    assert(scenario.surfaces == 0);
    assert(scenario.registrations == 0);
    if (scenario.sw_fails)
      return -19;
  }
  *context = new mpv_render_context;
  ++scenario.contexts;
  return 0;
}
void mpv_render_context_free(mpv_render_context* context) {
  delete context;
  --scenario.contexts;
}
void mpv_render_context_set_update_callback(mpv_render_context* context,
                                            void (*)(void*),
                                            void*) {
  assert(context != nullptr);
  assert(scenario.registrations == 1);
  ++scenario.callbacks;
}
class ANGLESurfaceManager {
 public:
  ANGLESurfaceManager(int32_t, int32_t) {
    if (scenario.angle_fails)
      throw std::runtime_error("fake ANGLE failure");
    ++scenario.surfaces;
  }
  ~ANGLESurfaceManager() { --scenario.surfaces; }
  void MakeCurrent(bool) {}
};

class VideoOutput {
 public:
  struct Configuration {
    bool enable_hardware_acceleration = true;
  } configuration_;
  mpv_handle* handle_ = nullptr;
  std::optional<int64_t> width_;
  std::optional<int64_t> height_;
  mpv_render_context* render_context_ = nullptr;
  std::unique_ptr<ANGLESurfaceManager> surface_manager_;
  std::unique_ptr<uint8_t[]> pixel_buffer_;
  void Initialize();
  void NotifyRender() {}
  void Resize(int64_t, int64_t) {
    assert(bool(surface_manager_) != bool(pixel_buffer_));
    if (scenario.resize_fails)
      throw std::runtime_error("fake resize failure");
    ++scenario.registrations;
  }
  ~VideoOutput() {
    if (render_context_)
      mpv_render_context_free(render_context_);
  }
};

#include "video_output_initialize.inc"

void Check(bool angle_fails, bool gl_fails, bool enabled) {
  scenario = {};
  scenario.angle_fails = angle_fails;
  scenario.gl_fails = gl_fails;
  {
    VideoOutput output;
    output.configuration_.enable_hardware_acceleration = enabled;
    output.Initialize();
    const bool hardware = enabled && !angle_fails && !gl_fails;
    assert(bool(output.surface_manager_) == hardware);
    assert(bool(output.pixel_buffer_) == !hardware);
    assert(scenario.sw_attempts == (hardware ? 0 : 1));
    assert(scenario.gl_attempts == (enabled && !angle_fails ? 1 : 0));
    assert(scenario.registrations == 1);
    assert(scenario.callbacks == 1);
  }
  assert(scenario.contexts == 0);
  assert(scenario.surfaces == 0);
}
}  // namespace

int main() {
  Check(false, false, true);
  Check(true, false, true);
  Check(false, true, true);
  Check(false, false, false);
  for (const bool resize_fails : {false, true}) {
    scenario = {};
    scenario.gl_fails = true;
    scenario.sw_fails = !resize_fails;
    scenario.resize_fails = resize_fails;
    VideoOutput output;
    bool failed = false;
    try {
      output.Initialize();
    } catch (const std::runtime_error&) {
      failed = true;
    }
    assert(failed);
    assert(output.render_context_ == nullptr);
    assert(!output.surface_manager_ && !output.pixel_buffer_);
    assert(scenario.contexts == 0 && scenario.surfaces == 0);
    assert(scenario.registrations == 0 && scenario.callbacks == 0);
  }
}
