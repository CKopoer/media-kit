/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit_video/src/video_controller/android_video_controller/surface_lifecycle.dart';

void main() {
  test('GPU attaches only after its Surface has valid dimensions', () async {
    final fixture = _Fixture();
    await fixture.lifecycle.onLoad();
    expect(fixture.events, ['vo=null', 'wid=0', 'create:1']);

    await fixture.lifecycle.onVideoParameters(1920, 1080);
    expect(fixture.events.skip(3), [
      'resize:1920x1080',
      'android-surface-size=1920x1080',
      'wid=1',
      'vo=gpu',
      'size:1920x1080',
    ]);
  });

  test(
    'early GPU attachment is resized without detaching or seeking',
    () async {
      final fixture = _Fixture(attachAfterVideoParameters: false);
      await fixture.lifecycle.onLoad();
      expect(fixture.events, [
        'vo=null',
        'wid=0',
        'create:1',
        'wid=1',
        'vo=gpu',
      ]);
      fixture.events.clear();
      await fixture.lifecycle.onVideoParameters(1280, 720);
      expect(fixture.events, [
        'resize:1280x720',
        'android-surface-size=1280x720',
        'wid=1',
        'vo=gpu',
        'size:1280x720',
      ]);
    },
  );

  test('same dimensions on the next source attach a fresh Surface', () async {
    final fixture = _Fixture();
    await fixture.lifecycle.onLoad();
    await fixture.lifecycle.onVideoParameters(1280, 720);
    fixture.events.clear();
    await fixture.lifecycle.onUnload();
    await fixture.lifecycle.onLoad();
    await fixture.lifecycle.onVideoParameters(1280, 720);
    expect(fixture.events, [
      'vo=null',
      'wid=0',
      'release',
      'vo=null',
      'wid=0',
      'create:2',
      'resize:1280x720',
      'android-surface-size=1280x720',
      'wid=2',
      'vo=gpu',
      'size:1280x720',
    ]);
  });

  test(
    'unload invalidates a resize before its platform call returns',
    () async {
      final fixture = _Fixture();
      await fixture.lifecycle.onLoad();
      final resizeStarted = Completer<void>();
      final resizeComplete = Completer<void>();
      fixture.resize = () {
        resizeStarted.complete();
        return resizeComplete.future;
      };
      fixture.events.clear();
      final parameters = fixture.lifecycle.onVideoParameters(1920, 1080);
      await resizeStarted.future;
      final unload = fixture.lifecycle.onUnload();
      resizeComplete.complete();
      await Future.wait([parameters, unload]);
      expect(fixture.events, [
        'resize:1920x1080',
        'vo=null',
        'wid=0',
        'release',
      ]);

      fixture.resize = null;
      fixture.events.clear();
      await fixture.lifecycle.onLoad();
      await fixture.lifecycle.onVideoParameters(1920, 1080);
      expect(fixture.events, contains('wid=2'));
      expect(fixture.events.last, 'size:1920x1080');
    },
  );

  test('unload during creation never attaches the obsolete Surface', () async {
    final fixture = _Fixture(attachAfterVideoParameters: false);
    final creationStarted = Completer<void>();
    final creationComplete = Completer<void>();
    fixture.create = () {
      creationStarted.complete();
      return creationComplete.future;
    };
    final load = fixture.lifecycle.onLoad();
    await creationStarted.future;
    final unload = fixture.lifecycle.onUnload();
    creationComplete.complete();
    await Future.wait([load, unload]);
    expect(fixture.events, [
      'vo=null',
      'wid=0',
      'create:1',
      'vo=null',
      'wid=0',
      'release',
    ]);
  });

  test('queued video parameters cannot resize the next source', () async {
    final fixture = _Fixture();
    await fixture.lifecycle.onLoad();
    final resizeStarted = Completer<void>();
    final resizeComplete = Completer<void>();
    fixture.resize = () {
      resizeStarted.complete();
      return resizeComplete.future;
    };
    final first = fixture.lifecycle.onVideoParameters(640, 360);
    await resizeStarted.future;
    final queued = fixture.lifecycle.onVideoParameters(1920, 1080);
    final unload = fixture.lifecycle.onUnload();
    final load = fixture.lifecycle.onLoad();
    resizeComplete.complete();
    await Future.wait([first, queued, unload, load]);
    expect(fixture.events, isNot(contains('resize:1920x1080')));
    expect(fixture.events.where((e) => e.startsWith('size:')), isEmpty);
  });

  test('video parameters arriving during Surface creation are ignored',
      () async {
    final fixture = _Fixture();
    final creationStarted = Completer<void>();
    final creationComplete = Completer<void>();
    fixture.create = () {
      creationStarted.complete();
      return creationComplete.future;
    };
    final load = fixture.lifecycle.onLoad();
    await creationStarted.future;
    await fixture.lifecycle.onVideoParameters(640, 360);
    creationComplete.complete();
    await load;
    expect(fixture.events, ['vo=null', 'wid=0', 'create:1']);
    await fixture.lifecycle.onVideoParameters(1920, 1080);
    expect(fixture.events.last, 'size:1920x1080');
  });

  test(
    'invalid and repeated dimensions do not reset the video output',
    () async {
      final fixture = _Fixture();
      await fixture.lifecycle.onVideoParameters(640, 360);
      expect(fixture.events, isEmpty);
      await fixture.lifecycle.onLoad();
      await fixture.lifecycle.onVideoParameters(640, 360);
      fixture.events.clear();
      await fixture.lifecycle.onVideoParameters(0, 0);
      await fixture.lifecycle.onVideoParameters(-1, 360);
      await fixture.lifecycle.onVideoParameters(640, 360);
      expect(fixture.events, isEmpty);
    },
  );

  test('dispose detaches before releasing and rejects later events', () async {
    final fixture = _Fixture(attachAfterVideoParameters: false);
    await fixture.lifecycle.onLoad();
    fixture.events.clear();
    await fixture.lifecycle.dispose();
    await fixture.lifecycle.dispose();
    await fixture.lifecycle.onLoad();
    await fixture.lifecycle.onVideoParameters(640, 360);
    expect(fixture.events, ['vo=null', 'wid=0', 'release']);
  });

  test(
    'custom MediaCodec VO preserves video-track activation ordering',
    () async {
      final fixture = _Fixture(
        vo: 'mediacodec_embed',
        attachAfterVideoParameters: false,
      );
      await fixture.lifecycle.onLoad();
      await fixture.lifecycle.onUnload();
      expect(fixture.events, [
        'vo=null',
        'vid=no',
        'wid=0',
        'create:1',
        'wid=1',
        'vo=mediacodec_embed',
        'vid=auto',
        'vo=null',
        'vid=no',
        'wid=0',
        'release',
      ]);
    },
  );

  test('creation failure also fails output readiness without an early waiter',
      () async {
    final fixture = _Fixture();
    final failure = StateError('Surface creation failed');
    fixture.create = () async => throw failure;
    await expectLater(fixture.lifecycle.onLoad(), throwsA(same(failure)));
    // No caller was awaiting readiness when the hook failed. This must not
    // become an unhandled asynchronous exception.
    await Future<void>.delayed(Duration.zero);
    await expectLater(fixture.lifecycle.ready, throwsA(same(failure)));
  });

  test('zero JNI reference fails output readiness', () async {
    final fixture = _Fixture()..returnedWid = 0;
    await expectLater(fixture.lifecycle.onLoad(), throwsStateError);
    await expectLater(fixture.lifecycle.ready, throwsStateError);
    expect(fixture.events, isNot(contains('vo=gpu')));
  });

  test('resize failure fails this source output readiness', () async {
    final fixture = _Fixture();
    final failure = StateError('Surface resizing failed');
    await fixture.lifecycle.onLoad();
    fixture.resize = () async => throw failure;
    await expectLater(
      fixture.lifecycle.onVideoParameters(1280, 720),
      throwsA(same(failure)),
    );
    await expectLater(fixture.lifecycle.ready, throwsA(same(failure)));
  });

  test('VO property failure fails this source output readiness', () async {
    final fixture = _Fixture(attachAfterVideoParameters: false);
    final failure = StateError('VO attachment failed');
    fixture.property = (name, value) {
      if (name == 'vo' && value == 'gpu') throw failure;
    };
    await expectLater(fixture.lifecycle.onLoad(), throwsA(same(failure)));
    await expectLater(fixture.lifecycle.ready, throwsA(same(failure)));
  });

  test('readiness is renewed after a successful previous source', () async {
    final fixture = _Fixture();
    final first = fixture.lifecycle.ready;
    await fixture.lifecycle.onLoad();
    expect(fixture.lifecycle.ready, same(first));
    await fixture.lifecycle.onVideoParameters(1280, 720);
    await first;
    await fixture.lifecycle.onUnload();
    await fixture.lifecycle.onLoad();
    final next = fixture.lifecycle.ready;
    expect(next, isNot(same(first)));
    final failure = StateError('Second source output failed');
    fixture.resize = () async => throw failure;
    await expectLater(
      fixture.lifecycle.onVideoParameters(1280, 720),
      throwsA(same(failure)),
    );
    await expectLater(next, throwsA(same(failure)));
  });

  test(
      'failed Surface release removes Dart ownership without unsafe native disposal',
      () async {
    final fixture = _Fixture();
    await fixture.lifecycle.onLoad();
    final owner = Object();
    final cache = <int, Object>{1: owner};
    final failure = StateError('Surface release failed');
    fixture.release = () async => throw failure;
    var dartDisposed = false;
    var nativeDisposed = false;
    await expectLater(
      disposeAndroidVideoOutput(
        detach: fixture.lifecycle.dispose,
        disposeNative: () async => nativeDisposed = true,
        disposeDart: () {
          if (identical(cache[1], owner)) cache.remove(1);
          dartDisposed = true;
        },
      ),
      throwsA(same(failure)),
    );
    expect(cache, isEmpty);
    expect(dartDisposed, isTrue);
    expect(nativeDisposed, isFalse);
  });

  test('native disposal failure still finalizes Dart ownership', () async {
    final events = <String>[];
    final failure = StateError('Native texture disposal failed');
    await expectLater(
      disposeAndroidVideoOutput(
        detach: () async => events.add('detached'),
        disposeNative: () async => throw failure,
        disposeDart: () => events.add('dart-disposed'),
      ),
      throwsA(same(failure)),
    );
    expect(events, ['detached', 'dart-disposed']);
  });
}

class _Fixture {
  _Fixture({String vo = 'gpu', bool attachAfterVideoParameters = true}) {
    lifecycle = AndroidSurfaceLifecycle(
      vo: vo,
      attachAfterVideoParameters: attachAfterVideoParameters,
      createSurface: () async {
        final wid = ++_wid;
        events.add('create:$wid');
        await create?.call();
        return returnedWid ?? wid;
      },
      releaseSurface: () async {
        events.add('release');
        await release?.call();
      },
      resizeSurface: (width, height) async {
        events.add('resize:${width}x$height');
        await resize?.call();
      },
      setProperty: (name, value) {
        events.add('$name=$value');
        property?.call(name, value);
      },
      onSize: (width, height) => events.add('size:${width}x$height'),
    );
  }

  final events = <String>[];
  int _wid = 0;
  Future<void> Function()? create;
  Future<void> Function()? resize;
  Future<void> Function()? release;
  void Function(String name, String value)? property;
  int? returnedWid;
  late final AndroidSurfaceLifecycle lifecycle;
}
