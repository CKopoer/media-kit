/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
import 'dart:ffi';

import 'package:media_kit/ffi/ffi.dart';

/// Keeps the flag storage alive until the asynchronous native write completes.
Future<void> withNativeFlag(
  bool value,
  Future<void> Function(Pointer<Void>) write, {
  Allocator allocator = calloc,
}) async {
  // libmpv MPV_FORMAT_FLAG is a C int (0 or 1), not a one-byte C bool.
  // A Bool allocation lets mpv read heap padding and may turn false into true.
  final data = allocator<Int32>()..value = value ? 1 : 0;
  try {
    await write(data.cast());
  } finally {
    allocator.free(data);
  }
}
