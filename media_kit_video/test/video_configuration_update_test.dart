/// This file is a part of media_kit (https://github.com/media-kit/media-kit).
///
/// Copyright © 2021 & onwards, Hitesh Kumar Saini <saini123hitesh@gmail.com>.
/// All rights reserved.
/// Use of this source code is governed by MIT license that can be found in the LICENSE file.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

void main() {
  testWidgets('updated Video properties can clear previous nullable values',
      (tester) async {
    final fixture = _Fixture();
    _disposeAfterTest(tester, fixture);
    final videoKey = GlobalKey<VideoState>();
    const controlsKey = Key('custom-controls');
    Widget controls(VideoState state) => const SizedBox(key: controlsKey);

    await tester.pumpWidget(_host(Video(
      key: videoKey,
      controller: fixture.controller,
      width: 320,
      height: 180,
      aspectRatio: 16 / 9,
      controls: controls,
      wakelock: false,
      subtitleViewConfiguration:
          const SubtitleViewConfiguration(visible: false),
    )));
    expect(find.byKey(controlsKey), findsOneWidget);
    expect(videoKey.currentState?.videoViewParametersNotifier.value.width, 320);

    await tester.pumpWidget(_host(Video(
      key: videoKey,
      controller: fixture.controller,
      width: null,
      height: null,
      aspectRatio: null,
      controls: null,
      wakelock: false,
      subtitleViewConfiguration:
          const SubtitleViewConfiguration(visible: false),
    )));
    await tester.pump();
    final parameters = videoKey.currentState!.videoViewParametersNotifier.value;
    expect(parameters.width, isNull);
    expect(parameters.height, isNull);
    expect(parameters.aspectRatio, isNull);
    expect(parameters.controls, isNull);
    expect(find.byKey(controlsKey), findsNothing);
  });

  testWidgets('unchanged widget properties preserve imperative Video updates',
      (tester) async {
    final fixture = _Fixture();
    _disposeAfterTest(tester, fixture);
    final videoKey = GlobalKey<VideoState>();
    Widget video(Color fill) => _host(Video(
          key: videoKey,
          controller: fixture.controller,
          width: 320,
          height: 180,
          controls: null,
          wakelock: false,
          fill: fill,
          subtitleViewConfiguration:
              const SubtitleViewConfiguration(visible: false),
        ));
    await tester.pumpWidget(video(const Color(0xFF000000)));
    videoKey.currentState!.update(width: 640, height: 480, aspectRatio: 4 / 3);
    await tester.pump();

    await tester.pumpWidget(video(const Color(0xFF112233)));
    await tester.pump();
    final parameters = videoKey.currentState!.videoViewParametersNotifier.value;
    expect(parameters.width, 640);
    expect(parameters.height, 480);
    expect(parameters.aspectRatio, 4 / 3);
    expect(parameters.fill, const Color(0xFF112233));
  });

  testWidgets('SubtitleView applies changed configuration padding',
      (tester) async {
    final fixture = _Fixture();
    _disposeAfterTest(tester, fixture);
    final subtitleKey = GlobalKey<SubtitleViewState>();
    Widget subtitles(EdgeInsets padding) => _host(SubtitleView(
          key: subtitleKey,
          controller: fixture.controller,
          configuration: SubtitleViewConfiguration(padding: padding),
        ));
    await tester.pumpWidget(subtitles(const EdgeInsets.only(bottom: 72)));
    expect(
        subtitleKey.currentState?.padding, const EdgeInsets.only(bottom: 72));

    await tester.pumpWidget(subtitles(EdgeInsets.zero));
    expect(subtitleKey.currentState?.padding, EdgeInsets.zero);
    final container = tester.widget<AnimatedContainer>(
      find.descendant(
          of: find.byKey(subtitleKey),
          matching: find.byType(AnimatedContainer)),
    );
    expect(container.padding, EdgeInsets.zero);
  });

  testWidgets('unrelated subtitle configuration preserves control padding',
      (tester) async {
    final fixture = _Fixture();
    _disposeAfterTest(tester, fixture);
    final subtitleKey = GlobalKey<SubtitleViewState>();
    Widget subtitles(TextStyle style) => _host(SubtitleView(
          key: subtitleKey,
          controller: fixture.controller,
          configuration: SubtitleViewConfiguration(
            padding: const EdgeInsets.only(bottom: 24),
            style: style,
          ),
        ));
    await tester.pumpWidget(subtitles(const TextStyle(fontSize: 18)));
    subtitleKey.currentState!.setPadding(const EdgeInsets.only(bottom: 96));
    await tester.pump();

    await tester.pumpWidget(subtitles(const TextStyle(fontSize: 20)));
    expect(
        subtitleKey.currentState?.padding, const EdgeInsets.only(bottom: 96));
  });
}

Widget _host(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: child,
    );

void _disposeAfterTest(WidgetTester tester, _Fixture fixture) {
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    fixture.controller.notifier.dispose();
    await fixture.player.dispose();
  });
}

class _Fixture {
  final player = Player(platformPlayer: _FakePlatformPlayer());
  late final controller = _FakeVideoController(player);
}

class _FakePlatformPlayer extends PlatformPlayer {
  _FakePlatformPlayer() : super(configuration: const PlayerConfiguration());
}

class _FakeVideoController implements VideoController {
  _FakeVideoController(this.player);

  @override
  final Player player;

  @override
  final notifier = ValueNotifier<PlatformVideoController?>(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
