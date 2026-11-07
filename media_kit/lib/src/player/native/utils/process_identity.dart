// Copyright (c) 2026, BiliSail contributors. MIT license.
import 'dart:ffi';
import 'dart:io';
import 'package:media_kit/ffi/src/allocation.dart';
import 'package:media_kit/src/third_party/windows_process.g.dart';

/// Stable across hot restart, distinct when Windows reuses a process ID.
/// A failed identity query must not fall back to a potentially stale pointer.
String nativeReferenceProcessIdentity() {
  if (!Platform.isWindows) return '$pid';
  final api = WindowsProcess(DynamicLibrary.open('kernel32.dll'));
  final times = calloc<FileTime>(4);
  try {
    if (api.GetProcessTimes(
          api.GetCurrentProcess(),
          times,
          times + 1,
          times + 2,
          times + 3,
        ) ==
        0) {
      throw StateError('Unable to identify the current Windows process.');
    }
    final created = (times.ref.dwHighDateTime << 32) | times.ref.dwLowDateTime;
    return '$pid.$created';
  } finally {
    calloc.free(times);
  }
}
