/**
 * This file is a part of media_kit (https://github.com/media-kit/media-kit).
 * <p>
 * Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
 * All rights reserved.
 * Use of this source code is governed by MIT license that can be found in the LICENSE file.
 */
package com.alexmercerind.media_kit_video;

import android.view.Surface;

import java.lang.reflect.Method;
import java.util.Objects;

import io.flutter.view.TextureRegistry;

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

    VideoOutput(TextureRegistry registry) {
        texture = registry.createSurfaceTexture();
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
    }

    public void dispose() {
        if (disposed) return;
        releaseSurface();
        texture.release();
        disposed = true;
    }

    private void ensureActive() {
        if (disposed) throw new IllegalStateException("The Android video texture has been disposed.");
    }
}
