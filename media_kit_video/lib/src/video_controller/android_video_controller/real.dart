/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
import 'dart:io';
import 'dart:async';
import 'dart:collection';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

import 'package:media_kit/media_kit.dart';
// ignore: implementation_imports
import 'package:media_kit/ffi/ffi.dart';

import 'package:media_kit_video/src/utils/query_decoders.dart';
import 'package:media_kit_video/src/video_controller/platform_video_controller.dart';
import 'package:media_kit_video/src/video_controller/android_video_controller/surface_lifecycle.dart';

/// Android video output, coordinated with mpv's source lifecycle.
///
/// The load/unload Surface design is adapted from the MIT-licensed
/// bggRGjQaUbCoE/media-kit fork, fd8421d21eade4d6d12de137fa7df902fec20292.
class AndroidVideoController extends PlatformVideoController {
  static bool get supported => Platform.isAndroid;

  NativePlayer get platform => player.platform as NativePlayer;

  late final AndroidSurfaceLifecycle _surface;
  StreamSubscription<VideoParams>? _videoParamsSubscription;
  Future<void>? _disposeFuture;

  /// Decoded dimensions are the readiness fallback while Flutter retains its
  /// own frame listener. The future is renewed for each source and propagates
  /// Surface/VO failures; it does not claim a displayed frame was measured.
  @override
  Future<void> get waitUntilFirstFrameRendered => _surface.ready;

  AndroidVideoController._(super.player, super.configuration, int handle) {
    _surface = AndroidSurfaceLifecycle(
      vo: configuration.vo!,
      attachAfterVideoParameters:
          configuration.androidAttachSurfaceAfterVideoParameters ??
              configuration.vo == 'gpu',
      createSurface: () async {
        final data = await _channel.invokeMapMethod<String, Object?>(
          'VideoOutputManager.CreateSurface',
          {'handle': handle.toString()},
        ).timeout(_platformCallTimeout);
        final wid = data?['wid'];
        if (wid is! int || wid == 0) {
          throw StateError('Failed to create the Android video Surface.');
        }
        return wid;
      },
      releaseSurface: () => _channel.invokeMethod<void>(
        'VideoOutputManager.ReleaseSurface',
        {'handle': handle.toString()},
      ).timeout(_platformCallTimeout),
      resizeSurface: (width, height) =>
          _channel.invokeMethod<void>('VideoOutputManager.SetSurfaceSize', {
        'handle': handle.toString(),
        'width': width.toString(),
        'height': height.toString(),
      }).timeout(_platformCallTimeout),
      setProperty: _setProperty,
      onSize: (width, height) {
        rect.value = Rect.fromLTWH(
          0.0,
          0.0,
          width.toDouble(),
          height.toDouble(),
        );
      },
    );
    platform.onLoadHooks.add(_surface.onLoad);
    platform.onUnloadHooks.add(_surface.onUnload);
    _videoParamsSubscription = player.stream.videoParams.listen((event) {
      final rotated = event.rotate == 90 || event.rotate == 270;
      final width = (rotated ? event.dh : event.dw) ?? 0;
      final height = (rotated ? event.dw : event.dh) ?? 0;
      unawaited(
        _surface.onVideoParameters(width, height).catchError((
          Object error,
          StackTrace stackTrace,
        ) {
          debugPrint(error.toString());
          debugPrint(stackTrace.toString());
        }),
      );
    });
  }

  /// A hook must return before mpv's event loop can consume an async reply.
  void _setProperty(String key, String value) {
    final name = key.toNativeUtf8();
    final data = value.toNativeUtf8();
    try {
      final result = platform.mpv.mpv_set_property_string(
        platform.ctx,
        name.cast(),
        data.cast(),
      );
      if (result < 0) {
        throw StateError(
          'Failed to set the Android video property $key ($result).',
        );
      }
    } finally {
      calloc.free(name);
      calloc.free(data);
    }
  }

  static Future<PlatformVideoController> create(
    Player player,
    VideoControllerConfiguration configuration,
  ) async {
    Future<String> getDefaultHwdec() async {
      bool hardware = configuration.enableHardwareAcceleration;
      final isEmulator = await _channel
          .invokeMethod<bool>('Utils.IsEmulator')
          .timeout(_platformCallTimeout);
      if (isEmulator ?? false) hardware = false;
      return hardware ? 'auto-safe' : 'no';
    }

    configuration = configuration.copyWith(
      vo: configuration.vo ?? 'gpu',
      hwdec: configuration.hwdec ?? await getDefaultHwdec(),
    );
    final handle = await player.handle;
    if (_controllers.containsKey(handle)) return _controllers[handle]!;
    final decoders = await queryDecoders(handle);
    if (!decoders.contains('h264')) {
      throw UnsupportedError(
        '[VideoController] requires media_kit_libs_***_video.',
      );
    }

    final controller = AndroidVideoController._(player, configuration, handle);
    try {
      final data = await _channel.invokeMapMethod<String, Object?>(
        'VideoOutputManager.Create',
        {'handle': handle.toString()},
      ).timeout(_platformCallTimeout);
      final id = data?['id'];
      if (id is! int) {
        throw StateError('Failed to create the Android video texture.');
      }
      for (final entry in {
        'vo': 'null',
        'hwdec': configuration.hwdec!,
        'vid': 'auto',
        'opengl-es': 'yes',
        // The load hook may attach before video parameters are known. An idle
        // window must not emit synthetic 1x1 video dimensions in that interval.
        'force-window': 'no',
        'gpu-context': 'android',
        'sub-use-margins': 'no',
        'sub-font-provider': 'none',
        'sub-scale-with-window': 'yes',
        'hwdec-codecs': 'h264,hevc,mpeg4,mpeg2video,vp8,vp9,av1',
      }.entries) {
        controller._setProperty(entry.key, entry.value);
      }
      controller.id.value = id;
      _controllers[handle] = controller;
      player.platform?.release.add(controller._dispose);
      return controller;
    } catch (_) {
      try {
        await controller._dispose();
      } catch (error, stackTrace) {
        debugPrint('Failed to clean up the Android video output: $error');
        debugPrint(stackTrace.toString());
      }
      rethrow;
    }
  }

  @override
  Future<void> setSize({int? width, int? height}) {
    throw UnsupportedError(
      '[AndroidVideoController.setSize] is not available on Android',
    );
  }

  Future<void> _dispose() => _disposeFuture ??= _disposeResources();

  Future<void> _disposeResources() async {
    final handle = platform.ctx.address;
    await disposeAndroidVideoOutput(
      detach: () async {
        platform.onLoadHooks.remove(_surface.onLoad);
        platform.onUnloadHooks.remove(_surface.onUnload);
        await _videoParamsSubscription?.cancel();
        await _surface.dispose();
      },
      disposeNative: () => _channel.invokeMethod<void>(
        'VideoOutputManager.Dispose',
        {'handle': handle.toString()},
      ).timeout(_platformCallTimeout),
      disposeDart: () {
        if (identical(_controllers[handle], this)) _controllers.remove(handle);
        super.dispose();
      },
    );
  }

  static final _controllers = HashMap<int, AndroidVideoController>();
  static const _channel = MethodChannel('com.alexmercerind/media_kit_video');
  static const _platformCallTimeout = Duration(seconds: 5);
}
