/**
 * This file is a part of media_kit (https://github.com/media-kit/media-kit).
 * <p>
 * Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
 * All rights reserved.
 * Use of this source code is governed by MIT license that can be found in the LICENSE file.
 */
package com.alexmercerind.media_kit_video;

import androidx.annotation.NonNull;

import java.util.Collections;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.MethodChannel.MethodCallHandler;
import io.flutter.plugin.common.MethodChannel.Result;

public class MediaKitVideoPlugin implements FlutterPlugin, MethodCallHandler {
    private MethodChannel channel;
    private VideoOutputManager videoOutputManager;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        channel = new MethodChannel(binding.getBinaryMessenger(), "com.alexmercerind/media_kit_video");
        channel.setMethodCallHandler(this);
        videoOutputManager = new VideoOutputManager(binding.getTextureRegistry());
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull Result result) {
        try {
            if ("Utils.IsEmulator".equals(call.method)) {
                result.success(Utils.isEmulator());
                return;
            }
            switch (call.method) {
                case "VideoOutputManager.Create": {
                    final long handle = Long.parseLong(call.argument("handle"));
                    result.success(Collections.singletonMap("id", videoOutputManager.create(handle).id()));
                    break;
                }
                case "VideoOutputManager.CreateSurface": {
                    final long handle = Long.parseLong(call.argument("handle"));
                    result.success(Collections.singletonMap("wid", videoOutputManager.get(handle).createSurface()));
                    break;
                }
                case "VideoOutputManager.ReleaseSurface": {
                    final long handle = Long.parseLong(call.argument("handle"));
                    videoOutputManager.releaseSurface(handle);
                    result.success(null);
                    break;
                }
                case "VideoOutputManager.SetSurfaceSize": {
                    final long handle = Long.parseLong(call.argument("handle"));
                    final int width = Integer.parseInt(call.argument("width"));
                    final int height = Integer.parseInt(call.argument("height"));
                    videoOutputManager.get(handle).setSurfaceSize(width, height);
                    result.success(null);
                    break;
                }
                case "VideoOutputManager.Dispose": {
                    final long handle = Long.parseLong(call.argument("handle"));
                    videoOutputManager.dispose(handle);
                    result.success(null);
                    break;
                }
                default:
                    result.notImplemented();
            }
        } catch (RuntimeException exception) {
            result.error("video_output", exception.getMessage(), null);
        }
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        // A texture's Java Surface can only be released after the Dart mpv
        // unload/disposal barrier. Engine detachment alone does not prove that
        // its native video output has stopped using the JNI reference.
    }
}
