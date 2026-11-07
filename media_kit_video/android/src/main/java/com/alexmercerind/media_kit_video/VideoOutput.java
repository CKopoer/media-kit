/**
 * This file is a part of media_kit (https://github.com/media-kit/media-kit).
 * <p>
 * Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
 * All rights reserved.
 * Use of this source code is governed by MIT license that can be found in the LICENSE file.
 */
package com.alexmercerind.media_kit_video;

import android.view.Surface;
import android.os.Handler;
import android.os.Looper;

import java.lang.reflect.Method;
import java.util.Objects;

import io.flutter.view.TextureRegistry;
import io.flutter.plugin.common.MethodChannel;

/**
 * Source-bound Surface lifecycle adapted from the MIT-licensed
 * bggRGjQaUbCoE/media-kit fork, fd8421d21eade4d6d12de137fa7df902fec20292.
 * Flutter retains its own frame listener; no private FlutterJNI reflection is needed.
 */
public final class VideoOutput {
    private static final Method newGlobalObjectRef;
    private static final Method deleteGlobalObjectRef;

    static {
        try {
            Class<?> helper = Class.forName("com.alexmercerind.mediakitandroidhelper.MediaKitAndroidHelper");
            newGlobalObjectRef = helper.getDeclaredMethod("newGlobalObjectRef", Object.class);
            deleteGlobalObjectRef = helper.getDeclaredMethod("deleteGlobalObjectRef", long.class);
            newGlobalObjectRef.setAccessible(true);
            deleteGlobalObjectRef.setAccessible(true);
        } catch (ReflectiveOperationException exception) {
            throw new IllegalStateException("media_kit_libs_android_video is required.", exception);
        }
    }

    private final TextureRegistry.SurfaceTextureEntry texture;
    private Surface surface;
    private long wid;
    private boolean disposed;
    private boolean surfaceSized;
    private boolean videoFrameReady;
    private boolean sourceCreated;
    private MethodChannel.Result frameWaiter;
    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    VideoOutput(TextureRegistry registry) {
        texture = registry.createSurfaceTexture();
        texture.setOnFrameConsumedListener(() -> mainHandler.post(this::notifyVideoFrame));
        // A custom VO may attach before decoded dimensions are available.
        try {
            texture.surfaceTexture().setDefaultBufferSize(1, 1);
        } catch (RuntimeException exception) {
            texture.release();
            throw exception;
        }
    }

    public long id() {
        return texture.id();
    }

    public long createSurface() {
        ensureActive();
        if (sourceCreated) cancelFrameWaiter("source_replaced");
        sourceCreated = true;
        mainHandler.removeCallbacksAndMessages(null);
        videoFrameReady = false;
        // The caller has synchronously set vo=null and wid=0 in the on_load
        // hook, so the old VO no longer owns these resources.
        releaseSurface();
        final Surface next = new Surface(texture.surfaceTexture());
        try {
            final long reference = (long) Objects.requireNonNull(newGlobalObjectRef.invoke(null, next));
            if (reference == 0) throw new IllegalStateException("Could not retain the Android video Surface.");
            surface = next;
            wid = reference;
            return wid;
        } catch (ReflectiveOperationException | RuntimeException exception) {
            next.release();
            throw new IllegalStateException("Could not create the Android video Surface.", exception);
        }
    }

    public void releaseSurface() {
        // Only called after mpv has detached at on_unload (or disposal).
        if (wid != 0) {
            try {
                deleteGlobalObjectRef.invoke(null, wid);
                wid = 0;
            } catch (ReflectiveOperationException exception) {
                throw new IllegalStateException("Could not release the Android Surface reference.", exception);
            }
        }
        if (surface != null) {
            surface.release();
            surface = null;
        }
    }

    public void setSurfaceSize(int width, int height) {
        ensureActive();
        if (width <= 0 || height <= 0) {
            throw new IllegalArgumentException("Video Surface dimensions must be positive.");
        }
        texture.surfaceTexture().setDefaultBufferSize(width, height);
        surfaceSized = width > 1 && height > 1;
    }

    public void waitForVideoFrame(MethodChannel.Result result) {
        if (disposed) {
            result.error("disposed", "Video output was disposed.", null);
        } else if (videoFrameReady) {
            result.success(null);
        } else if (frameWaiter != null) {
            result.error("already_waiting", "A video frame wait already exists.", null);
        } else {
            frameWaiter = result;
        }
    }

    private void notifyVideoFrame() {
        if (disposed || surface == null || !surfaceSized || videoFrameReady) return;
        videoFrameReady = true;
        if (frameWaiter != null) {
            MethodChannel.Result result = frameWaiter;
            frameWaiter = null;
            result.success(null);
        }
    }

    private void cancelFrameWaiter(String code) {
        if (frameWaiter != null) {
            MethodChannel.Result result = frameWaiter;
            frameWaiter = null;
            result.error(code, "The video source is no longer active.", null);
        }
    }

    public void dispose() {
        if (disposed) return;
        releaseSurface();
        disposed = true;
        cancelFrameWaiter("disposed");
        texture.setOnFrameConsumedListener(null);
        mainHandler.removeCallbacksAndMessages(null);
        texture.release();
    }

    private void ensureActive() {
        if (disposed) throw new IllegalStateException("The Android video texture has been disposed.");
    }
}
