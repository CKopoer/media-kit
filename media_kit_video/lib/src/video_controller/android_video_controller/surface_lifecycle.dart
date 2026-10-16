/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
import 'dart:async';

import 'package:synchronized/synchronized.dart';

/// Coordinates the Android Surface with mpv's load/unload barriers.
///
/// The Surface must outlive its video output. Resizing a Flutter texture must
/// never seek or reattach a previous source after an asynchronous platform call.
class AndroidSurfaceLifecycle {
  AndroidSurfaceLifecycle({
    required this.vo,
    required this.attachAfterVideoParameters,
    required this.createSurface,
    required this.releaseSurface,
    required this.resizeSurface,
    required this.setProperty,
    required this.onSize,
  });

  final String vo;
  final bool attachAfterVideoParameters;
  final Future<int> Function() createSurface;
  final Future<void> Function() releaseSurface;
  final Future<void> Function(int width, int height) resizeSurface;

  /// Synchronous mpv calls are required inside hooks. Awaiting an asynchronous
  /// property reply there would wait on the event loop running that hook.
  final void Function(String name, String value) setProperty;
  final void Function(int width, int height) onSize;

  final _lock = Lock();
  int _generation = 0;
  int? _wid;
  int? _width;
  int? _height;
  bool _loaded = false;
  bool _disposed = false;
  Future<void>? _disposeFuture;
  bool _hasLoaded = false;
  Completer<void> _ready = _newReadiness();

  /// Completes after this source's Surface has accepted decoded dimensions.
  ///
  /// A new source gets a new future, including after an earlier successful
  /// source. Every future has an error listener even if the application does
  /// not await readiness; applications that await it still receive the error.
  Future<void> get ready => _ready.future;

  Future<void> onLoad() {
    if (_disposed) return Future<void>.value();
    final generation = ++_generation;
    _loaded = false;
    if (_hasLoaded) {
      _failReadiness(StateError('The Android video source was replaced.'));
      _ready = _newReadiness();
    }
    _hasLoaded = true;
    return _run(generation, () async {
      if (_disposed || generation != _generation) return;
      _detach();
      // A new Surface is needed even for the same URL: MediaCodec cannot
      // reconnect to a Surface that was used by its previous codec.
      final wid = await createSurface();
      _wid = wid;
      _width = null;
      _height = null;
      if (_disposed || generation != _generation) return;
      if (wid == 0) {
        throw StateError('The Android video Surface has no JNI reference.');
      }
      _loaded = true;
      if (!attachAfterVideoParameters) _attach();
    });
  }

  Future<void> onUnload() {
    final generation = ++_generation;
    _loaded = false;
    _failReadiness(StateError('The Android video source was unloaded.'));
    return _run(generation, () async {
      _detach();
      await releaseSurface();
      _wid = null;
      _width = null;
      _height = null;
    });
  }

  Future<void> onVideoParameters(int width, int height) {
    // mpv cannot decode the new source before its on_load hook completes.
    // Parameters delivered while its Surface is being created belong to an
    // earlier/idle output; do not queue them behind creation and attach later.
    if (_disposed || !_loaded) return Future<void>.value();
    final generation = _generation;
    return _run(generation, () async {
      if (_disposed ||
          !_loaded ||
          generation != _generation ||
          width <= 0 ||
          height <= 0 ||
          (width == _width && height == _height)) {
        return;
      }
      await resizeSurface(width, height);
      if (_disposed || !_loaded || generation != _generation) return;
      setProperty('android-surface-size', '${width}x$height');
      if (attachAfterVideoParameters || vo == 'gpu') _attach();
      _width = width;
      _height = height;
      onSize(width, height);
      if (!_ready.isCompleted) _ready.complete();
    });
  }

  Future<void> dispose() {
    final pending = _disposeFuture;
    if (pending != null) return pending;
    _disposed = true;
    return _disposeFuture = onUnload();
  }

  void _attach() {
    setProperty('wid', _wid.toString());
    setProperty('vo', vo);
    if (vo == 'mediacodec_embed') setProperty('vid', 'auto');
  }

  void _detach() {
    // Stop the VO before dropping its Java/JNI reference.
    setProperty('vo', 'null');
    if (vo == 'mediacodec_embed') setProperty('vid', 'no');
    setProperty('wid', '0');
  }

  Future<void> _run(int generation, Future<void> Function() operation) {
    return _lock.synchronized(() async {
      try {
        await operation();
      } catch (error, stackTrace) {
        if (generation == _generation) _failReadiness(error, stackTrace);
        rethrow;
      }
    });
  }

  void _failReadiness(Object error, [StackTrace? stackTrace]) {
    if (!_ready.isCompleted) _ready.completeError(error, stackTrace);
  }

  static Completer<void> _newReadiness() {
    final completer = Completer<void>();
    completer.future.ignore();
    return completer;
  }
}

/// Removes Dart ownership even when native teardown fails. Native resources
/// must only be freed after mpv has successfully detached from the Surface.
Future<void> disposeAndroidVideoOutput({
  required Future<void> Function() detach,
  required Future<void> Function() disposeNative,
  required void Function() disposeDart,
}) async {
  try {
    await detach();
    await disposeNative();
  } finally {
    disposeDart();
  }
}
