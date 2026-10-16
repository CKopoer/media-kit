/**
 * This file is a part of media_kit (https://github.com/media-kit/media-kit).
 * <p>
 * Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
 * All rights reserved.
 * Use of this source code is governed by MIT license that can be found in the LICENSE file.
 */
package com.alexmercerind.media_kit_video;

import java.util.HashMap;

import io.flutter.view.TextureRegistry;

public final class VideoOutputManager {
    private final HashMap<Long, VideoOutput> videoOutputs = new HashMap<>();
    private final TextureRegistry registry;

    VideoOutputManager(TextureRegistry registry) {
        this.registry = registry;
    }

    public VideoOutput create(long handle) {
        VideoOutput output = videoOutputs.get(handle);
        if (output == null) {
            output = new VideoOutput(registry);
            videoOutputs.put(handle, output);
        }
        return output;
    }

    public VideoOutput get(long handle) {
        final VideoOutput output = videoOutputs.get(handle);
        if (output == null) throw new IllegalStateException("The Android video texture does not exist.");
        return output;
    }

    public void dispose(long handle) {
        final VideoOutput output = videoOutputs.get(handle);
        if (output != null) {
            output.dispose();
            videoOutputs.remove(handle);
        }
    }

    public void releaseSurface(long handle) {
        final VideoOutput output = videoOutputs.get(handle);
        if (output != null) output.releaseSurface();
    }

}
