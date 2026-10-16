/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
import 'package:media_kit/media_kit.dart';
import 'package:test/test.dart';

void main() {
  test('native options are isolated from extras and same-URI media', () {
    final options = {'cache': 'no'};
    final media = Media(
      'https://example.com/video.mp4',
      extras: {'application-data': 42},
      httpHeaders: {'User-Agent': 'media-kit-test'},
      nativeOptions: options,
    );
    options['cache'] = 'yes';
    expect(media.nativeOptions, {'cache': 'no'});
    expect(media.extras, {'application-data': 42});
    expect(media.httpHeaders, {'User-Agent': 'media-kit-test'});
    expect(Media(media.uri).nativeOptions, isNull);
    expect(media.copyWith().nativeOptions, {'cache': 'no'});
    expect(() => media.nativeOptions!['cache'] = 'yes', throwsUnsupportedError);
  });
}
