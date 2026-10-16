/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
@TestOn('vm')
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:media_kit/media_kit.dart';
import 'package:test/test.dart';

void main() {
  setUpAll(() {
    MediaKit.ensureInitialized();
    NativePlayer.test = true;
  });

  test('native initialization options override matching defaults', () async {
    final player = Player(
        configuration: const PlayerConfiguration(options: {
      'cache-on-disk': 'no',
      'demuxer-max-bytes': '67108864',
      'prefetch-playlist': 'yes',
    }));
    addTearDown(player.dispose);
    final native = player.platform as NativePlayer;
    expect(await native.getProperty('cache-on-disk'), 'no');
    expect(await native.getProperty('demuxer-max-bytes'), '67108864');
    expect(await native.getProperty('prefetch-playlist'), 'yes');
  });

  test('independent players do not share operation locks', () async {
    final a = Player();
    final b = Player();
    addTearDown(a.dispose);
    addTearDown(b.dispose);
    await Future.wait([a.handle, b.handle]);
    final entered = Completer<void>();
    final release = Completer<void>();
    final held = (a.platform as NativePlayer).lock.synchronized(() async {
      entered.complete();
      await release.future;
    });
    await entered.future;
    try {
      await b.setVolume(25).timeout(const Duration(seconds: 3));
      expect(
          double.parse(
              await (b.platform as NativePlayer).getProperty('volume')),
          25);
    } finally {
      release.complete();
      await held;
    }
  });

  test('per-file options and mixed synchronous hooks survive unload', () async {
    final directory =
        await Directory.systemTemp.createTemp('media-kit-options');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/silence.wav');
    await file.writeAsBytes(_silenceWav());
    final player = Player();
    addTearDown(player.dispose);
    final native = player.platform as NativePlayer;
    final hooks = <String>[];
    final loaded = Completer<void>();
    native.onLoadHooks.add(() => hooks.add('sync-load'));
    native.onLoadHooks.add(() async {
      await Future<void>.delayed(Duration.zero);
      hooks.add('async-load');
    });
    native.onUnloadHooks.add(() => hooks.add('sync-unload'));
    final subscription = player.stream.duration.listen((duration) {
      if (duration > Duration.zero && !loaded.isCompleted) loaded.complete();
    });
    addTearDown(subscription.cancel);
    const title = '中,a="b"';
    await player.open(
        Media(file.path, nativeOptions: {
          'force-media-title': title,
        }),
        play: false);
    await loaded.future.timeout(const Duration(seconds: 5));
    expect(await native.getProperty('media-title'), title);
    await player.stop();
    expect(hooks, ['sync-load', 'async-load', 'sync-unload']);
  });

  test('native screenshot retains encoded and raw-byte APIs', () async {
    final directory = await Directory.systemTemp.createTemp('media-kit-shot');
    addTearDown(() => directory.delete(recursive: true));
    final file = File('${directory.path}/frame.ppm');
    await file.writeAsBytes([
      ...'P6\n2 2\n255\n'.codeUnits,
      255,
      0,
      0,
      0,
      255,
      0,
      0,
      0,
      255,
      255,
      255,
      255,
    ]);
    final player = Player();
    addTearDown(player.dispose);
    final decoded = player.stream.videoParams
        .firstWhere((params) => params.w == 2 && params.h == 2);
    await player.open(Media(file.path), play: false);
    await decoded.timeout(const Duration(seconds: 5));
    final png = await player.screenshot(format: 'image/png');
    expect(png?.take(8), [137, 80, 78, 71, 13, 10, 26, 10]);
    final raw = await player.screenshot(format: null);
    expect(raw, isNotNull);
    expect(raw!.length, greaterThanOrEqualTo(16));
  });
}

Uint8List _silenceWav() {
  const samples = 8000;
  final bytes = Uint8List(44 + samples * 2);
  final data = ByteData.sublistView(bytes);
  bytes.setRange(0, 4, 'RIFF'.codeUnits);
  data.setUint32(4, bytes.length - 8, Endian.little);
  bytes.setRange(8, 16, 'WAVEfmt '.codeUnits);
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 8000, Endian.little);
  data.setUint32(28, 16000, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  bytes.setRange(36, 40, 'data'.codeUnits);
  data.setUint32(40, samples * 2, Endian.little);
  return bytes;
}
