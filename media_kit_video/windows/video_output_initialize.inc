// Copyright (c) 2026 BiliSail contributors. MIT license; see LICENSE.
// Select one renderer before registering a Flutter texture. A failed OpenGL
// attempt must never leave a GPU texture attached to the software renderer.
void VideoOutput::Initialize() {
  using RenderContext =
      std::unique_ptr<mpv_render_context, decltype(&mpv_render_context_free)>;
  RenderContext context(nullptr, mpv_render_context_free);
  try {
    mpv_set_option_string(handle_, "video-sync", "audio");
    mpv_set_option_string(handle_, "video-timing-offset", "0");
    if (configuration_.enable_hardware_acceleration) {
      try {
        surface_manager_ = std::make_unique<ANGLESurfaceManager>(
            static_cast<int32_t>(width_.value_or(1)),
            static_cast<int32_t>(height_.value_or(1)));
        surface_manager_->MakeCurrent(true);
        mpv_opengl_init_params gl_init_params{
            [](auto, auto name) {
              return reinterpret_cast<void*>(eglGetProcAddress(name));
            },
            nullptr,
        };
        mpv_render_param params[] = {
            {MPV_RENDER_PARAM_API_TYPE, MPV_RENDER_API_TYPE_OPENGL},
            {MPV_RENDER_PARAM_OPENGL_INIT_PARAMS, &gl_init_params},
            {MPV_RENDER_PARAM_INVALID, nullptr},
        };
        mpv_render_context* created = nullptr;
        if (mpv_render_context_create(&created, handle_, params) == 0) {
          context.reset(created);
        }
      } catch (const std::exception&) {
        // ANGLE can reject the device or shared texture. Discard the entire
        // attempt below and use libmpv's independent software render API.
      }
    }
    if (!context) {
      if (surface_manager_)
        surface_manager_->MakeCurrent(false);
      surface_manager_.reset();
      mpv_render_param params[] = {
          {MPV_RENDER_PARAM_API_TYPE, MPV_RENDER_API_TYPE_SW},
          {MPV_RENDER_PARAM_INVALID, nullptr},
      };
      mpv_render_context* created = nullptr;
      if (mpv_render_context_create(&created, handle_, params) != 0) {
        throw std::runtime_error("Unable to initialize a video renderer.");
      }
      context.reset(created);
      pixel_buffer_ =
          std::make_unique<uint8_t[]>(SW_RENDERING_PIXEL_BUFFER_SIZE);
    }
    Resize(width_.value_or(1), height_.value_or(1));
    render_context_ = context.get();
    mpv_render_context_set_update_callback(
        render_context_,
        [](void* output) { static_cast<VideoOutput*>(output)->NotifyRender(); },
        this);
    context.release();
  } catch (...) {
    render_context_ = nullptr;
    // Free on the rendering thread, while a hardware context is still current.
    context.reset();
    if (surface_manager_)
      surface_manager_->MakeCurrent(false);
    surface_manager_.reset();
    pixel_buffer_.reset();
    throw;
  }
}
