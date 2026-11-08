// This file is a part of media_kit
// (https://github.com/media-kit/media-kit).
//
// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
// All rights reserved.
// Use of this source code is governed by MIT license that can be found in the
// LICENSE file.

#include "include/media_kit_video/texture_sw.h"

struct _TextureSW {
  FlPixelBufferTexture parent_instance;
  guint32 current_width;
  guint32 current_height;
  VideoOutput* video_output;
  guint8* snapshot;
};

G_DEFINE_TYPE(TextureSW, texture_sw, fl_pixel_buffer_texture_get_type())

static void texture_sw_init(TextureSW* self) {
  self->current_width = 1;
  self->current_height = 1;
  self->video_output = NULL;
  self->snapshot = NULL;
}

static void texture_sw_dispose(GObject* object) {
  auto* self = TEXTURE_SW(object);
  g_clear_pointer(&self->snapshot, g_free);
  G_OBJECT_CLASS(texture_sw_parent_class)->dispose(object);
}

static void texture_sw_class_init(TextureSWClass* klass) {
  FL_PIXEL_BUFFER_TEXTURE_CLASS(klass)->copy_pixels = texture_sw_copy_pixels;
  G_OBJECT_CLASS(klass)->dispose = texture_sw_dispose;
}

TextureSW* texture_sw_new(VideoOutput* video_output) {
  TextureSW* self = TEXTURE_SW(g_object_new(texture_sw_get_type(), NULL));
  self->video_output = video_output;
  return self;
}

gboolean texture_sw_copy_pixels(FlPixelBufferTexture* texture,
                                const guint8** buffer,
                                guint32* width,
                                guint32* height,
                                GError** error) {
  TextureSW* self = TEXTURE_SW(texture);
  VideoOutput* video_output = self->video_output;
  guint8* copy = NULL;
  guint32 frame_width = 0, frame_height = 0;
  if (video_output_copy_pixel_buffer(video_output, &copy, &frame_width, &frame_height)) {
    g_free(self->snapshot);
    self->snapshot = copy;
    if (self->current_width != frame_width || self->current_height != frame_height) {
      self->current_width = frame_width;
      self->current_height = frame_height;
      video_output_notify_texture_update(video_output);
    }
  }
  // Flutter uploads after this callback unlocks the producer. Only the raster
  // callback owns this snapshot; the native renderer never writes these bytes.
  if (self->snapshot == NULL) return FALSE;
  *buffer = self->snapshot;
  *width = self->current_width;
  *height = self->current_height;
  return TRUE;
}
