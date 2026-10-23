/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
@TestOn('vm')
library;

import 'dart:async';
import 'dart:ffi';

import 'package:media_kit/ffi/ffi.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit/generated/libmpv/bindings.dart' as mpv;
import 'package:media_kit/src/player/native/utils/native_flag.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(() {
    MediaKit.ensureInitialized();
    NativePlayer.test = true;
  });

  test('mpv receives false and true even when adjacent heap bytes are nonzero',
      () async {
    final player = Player();
    addTearDown(player.dispose);
    final native = player.platform as NativePlayer;
    await player.handle;
    final name = 'pause'.toNativeUtf8();
    addTearDown(() => calloc.free(name));
    for (final value in [false, true, false, true]) {
      final allocator = _DirtyTailAllocator();
      await withNativeFlag(value, (data) async {
        expect(
          native.mpv.mpv_set_property(
              native.ctx, name.cast(), mpv.mpv_format.MPV_FORMAT_FLAG, data),
          0,
        );
        expect(await native.getProperty('pause'), value ? 'yes' : 'no');
      }, allocator: allocator);
      expect(allocator.requestedBytes, sizeOf<Int32>());
      expect(allocator.freed, true);
    }
  });

  test('native flag remains allocated until the reply and frees on failure',
      () async {
    final allocator = _DirtyTailAllocator();
    final reply = Completer<void>();
    final operation =
        withNativeFlag(false, (data) => reply.future, allocator: allocator);
    final expectation = expectLater(operation, throwsStateError);
    expect(allocator.freed, false);
    reply.completeError(StateError('native write failed'));
    await expectation;
    expect(allocator.freed, true);
  });

  test('public play and pause agree with the native pause property', () async {
    final player = Player();
    addTearDown(player.dispose);
    final native = player.platform as NativePlayer;
    for (var i = 0; i < 25; i++) {
      await player.pause();
      expect(await native.getProperty('pause'), 'yes');
      await player.play();
      expect(await native.getProperty('pause'), 'no');
    }
  });
}

/// Emulates nonzero allocator padding without reading outside allocated memory.
class _DirtyTailAllocator implements Allocator {
  int requestedBytes = 0;
  bool freed = false;

  @override
  Pointer<T> allocate<T extends NativeType>(int byteCount, {int? alignment}) {
    requestedBytes = byteCount;
    final data = calloc<Uint8>(byteCount < 4 ? 4 : byteCount);
    for (var i = byteCount; i < 4; i++) {
      data[i] = 0x01;
    }
    return data.cast<T>();
  }

  @override
  void free(Pointer pointer) {
    freed = true;
    calloc.free(pointer);
  }
}
