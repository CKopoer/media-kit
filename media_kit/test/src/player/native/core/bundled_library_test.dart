import 'dart:io';

import 'package:media_kit/src/player/native/core/native_library.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  test('packaged Linux library is selected beside an executable with spaces',
      () async {
    final directory = await Directory.systemTemp.createTemp('mpv bundle ');
    addTearDown(() => directory.delete(recursive: true));
    final library = File(p.join(directory.path, 'lib', 'libmpv.so.2'));
    await library.parent.create();
    await library.writeAsBytes([0]);
    final executable = p.join(directory.path, 'bilisail');
    expect(
      NativeLibrary.bundledLibraryPath(executable,
          platform: 'linux', exists: (path) => File(path).existsSync()),
      library.path,
    );
    await library.delete();
    expect(
      NativeLibrary.bundledLibraryPath(executable,
          platform: 'linux', exists: (path) => File(path).existsSync()),
      isNull,
    );
  });

  test('other platforms retain their existing library discovery', () {
    for (final platform in ['windows', 'android', 'macos', 'ios']) {
      expect(
        NativeLibrary.bundledLibraryPath('application',
            platform: platform,
            exists: (_) => throw StateError('Must not probe Linux paths')),
        isNull,
      );
    }
  });
}
