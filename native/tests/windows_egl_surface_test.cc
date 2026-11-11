// Copyright (c) 2026 BiliSail contributors. MIT license; see LICENSE.
// Fake EGL follows eglBindTexImage's write prohibition. Compile the actual
// production methods, including the first decoded-size resize after mpv init.
#include <cstdint>
#include <iostream>
#include <stdexcept>
#include <unordered_map>

namespace {
void Require(bool condition, const char* message) {
  if (!condition) throw std::runtime_error(message);
}
using EGLint = int;
using EGLDisplay = int;
using EGLSurface = int;
using EGLContext = int;
using EGLConfig = int;
using GLuint = unsigned;
constexpr int EGL_NO_DISPLAY = 0, EGL_NO_SURFACE = 0, EGL_NO_CONTEXT = 0;
constexpr int EGL_FALSE = 0, EGL_TRUE = 1, EGL_NONE = 2;
constexpr int EGL_WIDTH = 3, EGL_HEIGHT = 4, EGL_TEXTURE_TARGET = 5;
constexpr int EGL_TEXTURE_2D = 6, EGL_TEXTURE_FORMAT = 7, EGL_TEXTURE_RGBA = 8;
constexpr int EGL_D3D_TEXTURE_2D_SHARE_HANDLE_ANGLE = 9;
// Retain the old sampling API for compiling pre-fix production methods too.
[[maybe_unused]] constexpr int EGL_BACK_BUFFER = 10;
[[maybe_unused]] constexpr int GL_TEXTURE_2D = 11, GL_TEXTURE_MIN_FILTER = 12;
[[maybe_unused]] constexpr int GL_TEXTURE_MAG_FILTER = 13, GL_NEAREST = 14;

struct Image {
  bool sampled = false;
  int width = 0, height = 0;
};
struct State {
  std::unordered_map<int, Image> surfaces;
  int next_surface = 1, current_context = 0, current_surface = 0;
  int contexts = 0, gl_calls = 0, invalid_calls = 0, surfaceless_calls = 0;
} state;

int eglMakeCurrent(EGLDisplay display, EGLSurface draw, EGLSurface read,
                   EGLContext context) {
  if (!display || (context && !draw)) {
    if (!display) ++state.invalid_calls;
    if (context && !draw) ++state.surfaceless_calls;
  }
  Require(draw == read, "different read/draw surfaces");
  state.current_context = context;
  state.current_surface = draw;
  return EGL_TRUE;
}
int eglChooseConfig(EGLDisplay, const EGLint*, EGLConfig* config, int, int* count) {
  *config = 1;
  *count = 1;
  return EGL_TRUE;
}
int eglCreateContext(EGLDisplay, EGLConfig, EGLContext, const EGLint*) {
  return ++state.contexts;
}
int eglCreatePbufferFromClientBuffer(EGLDisplay, int, void*, EGLConfig,
                                     const EGLint* attributes) {
  Image image;
  for (auto* item = attributes; *item != EGL_NONE; item += 2) {
    if (item[0] == EGL_WIDTH) image.width = item[1];
    if (item[0] == EGL_HEIGHT) image.height = item[1];
  }
  const auto id = state.next_surface++;
  state.surfaces.emplace(id, image);
  return id;
}
void glGenTextures(int, GLuint* texture) {
  ++state.gl_calls;
  *texture = 1;
}
void glBindTexture(int, GLuint) { ++state.gl_calls; }
void glTexParameteri(int, int, int) { ++state.gl_calls; }
int eglBindTexImage(EGLDisplay, EGLSurface surface, int) {
  // EGL ignores this operation without a current context. The old resize
  // path makes the context current, so it silently binds the new draw target.
  if (state.current_context) state.surfaces.at(surface).sampled = true;
  return EGL_TRUE;
}
int eglReleaseTexImage(EGLDisplay, EGLSurface surface, int) {
  state.surfaces.at(surface).sampled = false;
  return EGL_TRUE;
}
int eglDestroySurface(EGLDisplay, EGLSurface surface) {
  Require(state.current_surface != surface, "destroyed a current draw surface");
  state.surfaces.erase(surface);
  return EGL_TRUE;
}
int eglDestroyContext(EGLDisplay, EGLContext context) {
  Require(state.current_context != context, "destroyed a current context");
  --state.contexts;
  return EGL_TRUE;
}
struct Device {
  void Release() {}
};
struct Texture {
  void Release() {}
};

class ANGLESurfaceManager {
 public:
  void MakeCurrent(bool value);
  void CleanUp(bool release_context);
  bool CreateAndBindEGLSurface();
  void CheckDraw() {
    MakeCurrent(true);
    const auto& image = state.surfaces.at(state.current_surface);
    Require(!image.sampled, "draw surface is bound for sampling: video writes are undefined");
    Require(image.width == width_ && image.height == height_, "wrong draw dimensions");
  }
  int32_t width_ = 1, height_ = 1;
  EGLDisplay display_ = 1;
  EGLSurface surface_ = EGL_NO_SURFACE;
  EGLContext context_ = EGL_NO_CONTEXT;
  EGLConfig config_ = 0;
  void* internal_handle_ = nullptr;
  Device *d3d_11_device_context_ = nullptr, *d3d_11_device_ = nullptr;
  Texture* internal_d3d_11_texture_2D_ = nullptr;
  static constexpr int kEGLConfigurationAttributes[] = {EGL_NONE};
  static constexpr int kEGLContextAttributes[] = {EGL_NONE};
};
#define FAIL(message) return false
#include "egl_surface_methods.inc"

void ResizeWithCurrentContext() {
  state = {};
  ANGLESurfaceManager surface;
  Require(surface.CreateAndBindEGLSurface(), "initial surface creation failed");
  // VideoOutput::Initialize leaves this context current after mpv setup.
  surface.CheckDraw();
  for (const auto width : {640, 1280, 320, 1920}) {
    surface.CleanUp(false);
    surface.width_ = width;
    surface.height_ = width * 9 / 16;
    Require(surface.CreateAndBindEGLSurface(), "resize failed");
    surface.CheckDraw();
    Require(state.contexts == 1, "resize replaced the mpv GL context");
    Require(state.surfaces.size() == 1, "resize leaked a surface");
  }
  surface.CleanUp(true);
  Require(state.contexts == 0 && state.surfaces.empty(), "cleanup leaked EGL resources");
  Require(state.gl_calls == 0, "producer creation modified GL texture state");
  Require(state.surfaceless_calls == 0, "resize requires a surfaceless context");
}

void CreateWhileAnotherContextIsCurrent() {
  state = {};
  state.current_context = 99;
  ANGLESurfaceManager surface;
  Require(surface.CreateAndBindEGLSurface(), "surface creation failed");
  Require(state.gl_calls == 0, "surface creation changed another player's texture state");
  surface.CheckDraw();
  surface.CleanUp(true);
}

void EmptyCleanup() {
  state = {};
  ANGLESurfaceManager surface;
  surface.display_ = EGL_NO_DISPLAY;
  surface.CleanUp(false);
  surface.CleanUp(true);
  Require(state.invalid_calls == 0, "cleanup called EGL with no display");
}
}  // namespace

int main() {
  try {
    ResizeWithCurrentContext();
    CreateWhileAnotherContextIsCurrent();
    EmptyCleanup();
    std::cout << "PASS: writable producer surface, repeated resize, context isolation, cleanup\n";
    return 0;
  } catch (const std::exception& error) {
    std::cerr << error.what() << '\n';
    return 1;
  }
}
