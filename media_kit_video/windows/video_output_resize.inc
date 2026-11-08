// BiliSail stable texture registration for PiliPlus media_kit_video fd8421d (MIT).
void VideoOutput::Resize(int64_t required_width, int64_t required_height) {
  std::lock_guard<std::mutex> lock(textures_mutex_);
  if (surface_manager_ != nullptr) {
    surface_manager_->SetSize(static_cast<int32_t>(required_width),
                              static_cast<int32_t>(required_height));
    // Complete the paused/current frame's redraw before a consumer can acquire
    // the new allocation. Later GPU work remains on the same ordered context.
    if (render_context_ != nullptr) {
      surface_manager_->Draw([&] {
        mpv_opengl_fbo fbo{0, static_cast<int>(required_width),
                          static_cast<int>(required_height), 0};
        mpv_render_param params[]{
            {MPV_RENDER_PARAM_OPENGL_FBO, &fbo},
            {MPV_RENDER_PARAM_INVALID, nullptr},
        };
        mpv_render_context_render(render_context_, params);
      });
    }
    if (texture_id_ == 0) {
      auto descriptor = std::make_unique<FlutterDesktopGpuSurfaceDescriptor>();
      auto variant =
          std::make_unique<flutter::TextureVariant>(flutter::GpuSurfaceTexture(
              kFlutterDesktopGpuSurfaceTypeDxgiSharedHandle,
              [this](auto, auto) -> const FlutterDesktopGpuSurfaceDescriptor* {
                std::lock_guard<std::mutex> frame_lock(textures_mutex_);
                if (destroyed_) return nullptr;
                if (surface_manager_->HasFrame()) {
                  const auto handle = surface_manager_->Read();
                  if (handle != nullptr) {
                    last_video_handle_ = handle;
                    last_video_texture_ = surface_manager_->TextureForHandle(handle);
                  }
                  if (surface_manager_->HasPendingFrame()) {
                    registrar_->texture_registrar()->MarkTextureFrameAvailable(texture_id_);
                  }
                }
                if (!last_video_texture_) return nullptr;
                using TextureReference =
                    Microsoft::WRL::ComPtr<ID3D11Texture2D>;
                auto reference =
                    std::make_unique<TextureReference>(last_video_texture_);
                D3D11_TEXTURE2D_DESC dimensions{};
                reference->Get()->GetDesc(&dimensions);
                auto& descriptor = *textures_.at(texture_id_);
                descriptor.struct_size = sizeof(descriptor);
                descriptor.handle = last_video_handle_;
                descriptor.width = descriptor.visible_width = dimensions.Width;
                descriptor.height = descriptor.visible_height =
                    dimensions.Height;
                descriptor.format = kFlutterDesktopPixelFormatBGRA8888;
                descriptor.release_context = reference.release();
                descriptor.release_callback = [](void* context) {
                  delete static_cast<TextureReference*>(context);
                };
                // Flutter 3.47 reads visible dimensions AFTER release_callback.
                // Only the COM lease is released there; the descriptor remains
                // alive until this texture is unregistered.
                return &descriptor;
              }));
      texture_id_ =
          registrar_->texture_registrar()->RegisterTexture(variant.get());
      textures_.emplace(texture_id_, std::move(descriptor));
      texture_variants_.emplace(texture_id_, std::move(variant));
    }
  } else if (pixel_buffer_ != nullptr) {
    auto descriptor = std::make_unique<FlutterDesktopPixelBuffer>();
    descriptor->buffer = pixel_buffer_.get();
    descriptor->width = required_width;
    descriptor->height = required_height;
    descriptor->release_context = nullptr;
    descriptor->release_callback = [](void*) {};
    if (texture_id_ == 0) {
      auto variant = std::make_unique<flutter::TextureVariant>(
          flutter::PixelBufferTexture([this](auto, auto) {
            std::lock_guard<std::mutex> frame_lock(textures_mutex_);
            if (destroyed_)
              return static_cast<FlutterDesktopPixelBuffer*>(nullptr);
            // Keep callback metadata alive across a concurrent producer resize.
            last_pixel_buffer_ = *pixel_buffer_textures_.at(texture_id_);
            // The producer lock ends before Flutter uploads the returned bytes.
            // Lease a private copy so the next software render cannot tear them.
            const auto size = last_pixel_buffer_.width * last_pixel_buffer_.height * 4;
            auto pixels = std::make_unique<uint8_t[]>(size);
            std::copy_n(pixel_buffer_.get(), size, pixels.get());
            last_pixel_buffer_.buffer = pixels.get();
            last_pixel_buffer_.release_context = pixels.release();
            last_pixel_buffer_.release_callback = [](void* context) {
              delete[] static_cast<uint8_t*>(context);
            };
            return &last_pixel_buffer_;
          }));
      texture_id_ =
          registrar_->texture_registrar()->RegisterTexture(variant.get());
      texture_variants_.emplace(texture_id_, std::move(variant));
    }
    pixel_buffer_textures_[texture_id_] = std::move(descriptor);
  }
  // Layout changes update dimensions, never unregister the live texture.
  texture_update_callback_(texture_id_, required_width, required_height);
}
