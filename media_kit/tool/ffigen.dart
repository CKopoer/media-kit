// Copyright (c) 2026, BiliSail contributors. MIT license.
import 'dart:io';

/// Keep generator dependencies in the isolated tool package.
Future<void> main() async {
  final result = await Process.start(
    Platform.resolvedExecutable,
    ['run', 'windows.dart'],
    workingDirectory: Platform.script.resolve('ffigen/').toFilePath(),
    mode: ProcessStartMode.inheritStdio,
  );
  exitCode = await result.exitCode;
}
