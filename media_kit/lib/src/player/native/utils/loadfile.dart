/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
import 'dart:convert';

/// Builds separate arguments for mpv's `loadfile` command.
///
/// mpv 0.38 (client API 2.3) inserted an index before per-file options. Values
/// use mpv's UTF-8 byte-length quoting so commas, quotes and non-ASCII paths
/// cannot be interpreted as another option.
List<String> loadfileCommand(
  String uri, {
  required int apiVersion,
  Map<String, String>? options,
}) {
  final command = ['loadfile', uri, 'append'];
  if (options == null || options.isEmpty) return command;
  final values = <String>[];
  for (final entry in options.entries) {
    if (entry.key.isEmpty ||
        entry.key.contains(RegExp('[,=\u0000]')) ||
        entry.value.contains('\u0000')) {
      throw ArgumentError(
          'Native media options contain an invalid key or NUL.');
    }
    values
        .add('${entry.key}=%${utf8.encode(entry.value).length}%${entry.value}');
  }
  if (apiVersion >= 0x20003) command.add('-1');
  command.add(values.join(','));
  return command;
}
