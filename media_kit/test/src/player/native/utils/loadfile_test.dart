/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
import 'package:media_kit/src/player/native/utils/loadfile.dart';
import 'package:test/test.dart';

void main() {
  test('loadfile preserves legacy no-options commands', () {
    expect(loadfileCommand('fd://3', apiVersion: 0x20003),
        ['loadfile', 'fd://3', 'append']);
  });

  test('loadfile options support both client API layouts', () {
    final options = {'cache': 'no'};
    expect(loadfileCommand('video.mp4', apiVersion: 0x20002, options: options),
        ['loadfile', 'video.mp4', 'append', 'cache=%2%no']);
    expect(loadfileCommand('video.mp4', apiVersion: 0x20003, options: options),
        ['loadfile', 'video.mp4', 'append', '-1', 'cache=%2%no']);
  });

  test('loadfile quotes delimiter and Unicode option values in UTF-8 bytes',
      () {
    expect(
      loadfileCommand('video.mp4', apiVersion: 0x20003, options: {
        'force-media-title': '中,a="b"',
        'cache': 'yes',
      }).last,
      'force-media-title=%9%中,a="b",cache=%3%yes',
    );
  });

  test('loadfile rejects option injection and embedded NUL', () {
    for (final options in [
      {'cache,vo': 'no'},
      {'cache=no': 'no'},
      {'': 'no'},
      {'cache': 'no\u0000yes'},
    ]) {
      expect(
        () =>
            loadfileCommand('video.mp4', apiVersion: 0x20003, options: options),
        throwsArgumentError,
      );
    }
  });
}
