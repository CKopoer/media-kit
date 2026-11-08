// Copyright (c) 2026 BiliSail contributors. MIT license; see LICENSE.
#ifndef MEDIA_KIT_D3D11_TEXTURE_SNAPSHOT_H_
#define MEDIA_KIT_D3D11_TEXTURE_SNAPSHOT_H_

#include <d3d11.h>
#include <dxgi.h>
#include <wrl/client.h>

#include <chrono>
#include <cstdint>
#include <memory>
#include <thread>

namespace media_kit {

// A published allocation is never written again. Flutter's descriptor release
// callback only releases the import lease, BEFORE Flutter samples the image.
struct D3D11TextureFrame {
  Microsoft::WRL::ComPtr<ID3D11Texture2D> texture;
  HANDLE handle = nullptr;
  uint64_t revision = 0;
};

// Call under the producer's render lock, on its immediate-context command queue.
// At most one copy can be pending. Slow GPUs retain the last complete frame;
// callers request another Flutter frame while pending() is true.
class D3D11TextureSnapshot {
 public:
  using Frame = std::shared_ptr<const D3D11TextureFrame>;

  Frame Capture(ID3D11Texture2D* source, uint64_t revision) {
    const auto deadline = std::chrono::steady_clock::now() +
                          std::chrono::milliseconds(2);
    if (pending_) {
      Complete(deadline);
      if (pending_) return current_;
      // A newer render/resize may have arrived while the old copy was pending.
      // Queue it now, even when playback has paused and no new render will wake
      // Flutter. Both completion polls share the same raster-thread wait budget.
    }
    if (current_ && current_->revision == revision) return current_;

    Microsoft::WRL::ComPtr<ID3D11Device> device;
    source->GetDevice(&device);
    D3D11_TEXTURE2D_DESC desc{};
    source->GetDesc(&desc);
    desc.MiscFlags = D3D11_RESOURCE_MISC_SHARED;
    auto frame = std::make_shared<D3D11TextureFrame>();
    if (FAILED(device->CreateTexture2D(&desc, nullptr, &frame->texture)))
      return current_;
    Microsoft::WRL::ComPtr<IDXGIResource> resource;
    if (FAILED(frame->texture.As(&resource)) ||
        FAILED(resource->GetSharedHandle(&frame->handle))) return current_;
    D3D11_QUERY_DESC query_desc{D3D11_QUERY_EVENT, 0};
    if (FAILED(device->CreateQuery(&query_desc, &query_))) return current_;

    device->GetImmediateContext(&context_);
    frame->revision = revision;
    pending_ = std::move(frame);
    source_ = source;
    context_->CopyResource(pending_->texture.Get(), source);
    context_->End(query_.Get());
    context_->Flush();
    Complete(deadline);
    return current_;
  }

  bool pending() const { return pending_ != nullptr; }
  Frame current() const { return current_; }

 private:
  void Complete(std::chrono::steady_clock::time_point deadline) {
    // Flush submits work; an EVENT query proves the copy actually completed.
    // Bound raster-thread waiting and keep one pending allocation for retries.
    HRESULT result;
    do {
      result = context_->GetData(query_.Get(), nullptr, 0,
                                D3D11_ASYNC_GETDATA_DONOTFLUSH);
      if (result != S_FALSE) break;
      std::this_thread::yield();
    } while (std::chrono::steady_clock::now() < deadline);
    if (result == S_FALSE) return;
    if (result == S_OK) current_ = std::move(pending_);
    pending_.reset();
    source_.Reset();
    query_.Reset();
    context_.Reset();
  }

  Frame current_;
  std::shared_ptr<D3D11TextureFrame> pending_;
  Microsoft::WRL::ComPtr<ID3D11Texture2D> source_;
  Microsoft::WRL::ComPtr<ID3D11Query> query_;
  Microsoft::WRL::ComPtr<ID3D11DeviceContext> context_;
};

}  // namespace media_kit
#endif  // MEDIA_KIT_D3D11_TEXTURE_SNAPSHOT_H_
