import 'dart:io';
import 'package:media_kit/src/player/native/utils/process_identity.dart';
import 'package:test/test.dart';

void main() {
  test('process identity survives repeated reads and separates processes',
      () async {
    final identity = nativeReferenceProcessIdentity();
    expect(nativeReferenceProcessIdentity(), identity);
    expect(identity, startsWith('$pid.'));
    final root = Directory.current;
    final result = await Process.run(Platform.resolvedExecutable, [
      '--packages=${root.parent.path}/.dart_tool/package_config.json',
      '${root.path}/test/fixtures/process_identity_probe.dart',
    ]);
    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect((result.stdout as String).trim(), isNot(identity));
    // Same PID with a different creation time cannot locate the same buffer.
    expect(identity.split('.').length, 2);
  }, skip: !Platform.isWindows);
}
