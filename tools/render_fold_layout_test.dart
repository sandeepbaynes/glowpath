// Run with: flutter test tools/render_fold_layout_test.dart --reporter expanded
// Captures the real app, using the measured geometry in the fold layout tests.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/game_controller.dart';
import 'package:glowpath/main.dart';
import 'package:glowpath/services/fold_posture.dart';
import 'package:glowpath/ui/launch_countdown.dart';
import 'package:glowpath/ui/space_scenery.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _output = 'build/review/fold-layout';
const _boundaryKey = ValueKey('fold-layout-render');
const _camera = Rect.fromLTWH(399.6666667, 29.3333333, 37, 37);
const _status = Rect.fromLTWH(382, 0, 84, 174);
const _cases = [
  _FoldCapture(
    'ios-closed-466x678',
    Size(466, 678),
    platform: TargetPlatform.iOS,
    insets: EdgeInsets.only(right: 84, bottom: 34),
    occlusions: [_camera, _status],
  ),
  _FoldCapture(
    'ios-tabletop-669x951',
    Size(669, 951),
    platform: TargetPlatform.iOS,
    crease: Rect.fromLTWH(0, 475.5, 669, 0),
    insets: EdgeInsets.only(top: 82, bottom: 34),
    occlusions: [Rect.fromLTWH(525, 0, 144, 82)],
  ),
  _FoldCapture(
    'ios-book-951x669',
    Size(951, 669),
    platform: TargetPlatform.iOS,
    crease: Rect.fromLTWH(475.5, 0, 0, 669),
    insets: EdgeInsets.only(right: 84, bottom: 34),
    occlusions: [Rect.fromLTWH(827, 585, 124, 84)],
  ),
  _FoldCapture(
    'android-clamshell-393x852',
    Size(393, 852),
    platform: TargetPlatform.android,
    crease: Rect.fromLTWH(0, 426, 393, 0),
    insets: EdgeInsets.only(top: 24, bottom: 24),
  ),
  _FoldCapture(
    'android-clamshell-412x915',
    Size(412, 915),
    platform: TargetPlatform.android,
    crease: Rect.fromLTWH(0, 457.5, 412, 0),
    insets: EdgeInsets.only(top: 24, bottom: 24),
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final font in {
      'Manrope': 'assets/fonts/Manrope-VariableFont_wght.ttf',
      'Atkinson': 'assets/fonts/AtkinsonHyperlegibleNext-VariableFont_wght.ttf',
      'Lora': 'assets/fonts/Lora-VariableFont_wght.ttf',
      'MaterialIcons': 'fonts/MaterialIcons-Regular.otf',
    }.entries) {
      await (FontLoader(font.key)..addFont(rootBundle.load(font.value))).load();
    }
    await Directory(_output).create(recursive: true);
  });

  for (final scenario in _cases) {
    for (final halfOpen in scenario.crease == null ? [false] : [true, false]) {
      final name = scenario.crease == null
          ? scenario.name
          : '${scenario.name}-${halfOpen ? 'half' : 'flat'}';
      testWidgets('render $name with 17 seconds remaining', (tester) async {
        _configure(tester, scenario);
        final geometry = ValueNotifier(scenario.geometry(halfOpen));
        addTearDown(geometry.dispose);
        if (scenario.platform == TargetPlatform.android) {
          tester.view.displayFeatures = [
            ui.DisplayFeature(
              bounds: scenario.crease!,
              type: ui.DisplayFeatureType.fold,
              state: halfOpen
                  ? ui.DisplayFeatureState.postureHalfOpened
                  : ui.DisplayFeatureState.postureFlat,
            ),
          ];
        }
        // This is a capture harness outside test/, using the same mocked store
        // as the behavioral fold tests. No real player's progress is changed.
        // ignore: invalid_use_of_visible_for_testing_member
        SharedPreferences.setMockInitialValues({'journeyLevel': 92});
        final game = GameController(
          preferences: await SharedPreferences.getInstance(),
          now: () => DateTime.utc(2026, 11, 24, 12),
          snapshotWriter: (_) => SynchronousFuture(true),
        );
        await game.load();
        await game.flush();
        addTearDown(game.dispose);
        var clock = Duration.zero;
        await tester.pumpWidget(
          RepaintBoundary(
            key: _boundaryKey,
            child: GlowpathApp(
              controller: game,
              showBriefings: false,
              ambientMotion: false,
              clockNow: () => clock,
              foldGeometry: geometry,
            ),
          ),
        );
        await tester.pumpAndSettle();
        final countdown = tester.widget<LaunchCountdown>(
          find.byType(LaunchCountdown),
        );
        clock = countdown.total - const Duration(seconds: 17);
        await tester.pump(const Duration(milliseconds: 250));
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<LaunchCountdown>(find.byType(LaunchCountdown))
              .remaining,
          const Duration(seconds: 17),
        );
        expect(tester.takeException(), isNull);
        final metrics = <String, Object?>{
          'name': name,
          'size': [scenario.size.width, scenario.size.height],
          'remainingSeconds': 17,
          'puzzleSize': game.puzzle.size,
          'inlineMapVisible': find.byType(VoyageExplorer).evaluate().isNotEmpty,
        };
        for (final key in [
          'puzzle-board',
          'shared-navigation',
          'hint',
          'undo',
          'mode-journey',
          'mode-daily',
          'mode-weekly',
          'open-help',
          'open-settings',
          if (scenario.crease == null) 'open-atlas',
        ]) {
          final finder = find.byKey(ValueKey(key));
          expect(finder, findsOneWidget);
          final rect = tester.getRect(finder);
          expect(
            (Offset.zero & scenario.size).inflate(.01).contains(rect.topLeft),
            isTrue,
            reason: '$key top left outside viewport',
          );
          expect(
            (Offset.zero & scenario.size)
                .inflate(.01)
                .contains(rect.bottomRight),
            isTrue,
            reason: '$key bottom right outside viewport',
          );
          if (key != 'shared-navigation') {
            expect(finder.hitTestable(), findsOneWidget, reason: key);
          }
          metrics[key] = [rect.left, rect.top, rect.width, rect.height];
        }
        for (final element in find.byType(Scrollable).evaluate()) {
          final state = (element as StatefulElement).state as ScrollableState;
          expect(state.position.maxScrollExtent, lessThanOrEqualTo(.01));
        }
        if (scenario.crease != null) {
          expect(find.byType(VoyageExplorer), findsOneWidget);
        }
        final boundary = tester.renderObject<RenderRepaintBoundary>(
          find.byKey(_boundaryKey),
        );
        await tester.runAsync(() async {
          final image = await boundary.toImage(pixelRatio: 1.5);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('$_output/$name.png').writeAsBytes(
            bytes!.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          );
          image.dispose();
          await File(
            '$_output/$name.json',
          ).writeAsString(const JsonEncoder.withIndent('  ').convert(metrics));
        });
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}

class _FoldCapture {
  const _FoldCapture(
    this.name,
    this.size, {
    required this.platform,
    required this.insets,
    this.crease,
    this.occlusions = const [],
  });

  final String name;
  final Size size;
  final TargetPlatform platform;
  final EdgeInsets insets;
  final Rect? crease;
  final List<Rect> occlusions;

  FoldGeometry geometry(bool halfOpen) {
    if (platform == TargetPlatform.android) return const FoldGeometry();
    final split = crease;
    final gutter = split == null
        ? null
        : split.width > split.height
        ? Rect.fromLTWH(0, split.center.dy - 20, size.width, 40)
        : Rect.fromLTWH(split.center.dx - 20, 0, 40, size.height);
    return FoldGeometry(
      viewport: size,
      supported: true,
      divisions: halfOpen && gutter != null ? [gutter] : const [],
      layoutDivisions: split == null ? const [] : [halfOpen ? gutter! : split],
      occlusions: occlusions,
      status: split == null
          ? HingePosture.closed
          : halfOpen
          ? HingePosture.partiallyOpen
          : HingePosture.fullyOpen,
    );
  }
}

void _configure(WidgetTester tester, _FoldCapture scenario) {
  debugDefaultTargetPlatformOverride = scenario.platform;
  tester.view.devicePixelRatio = 3;
  tester.view.physicalSize = scenario.size * 3;
  tester.view.padding = FakeViewPadding(
    top: scenario.insets.top * 3,
    bottom: scenario.insets.bottom * 3,
    left: scenario.insets.left * 3,
    right: scenario.insets.right * 3,
  );
  tester.view.viewPadding = tester.view.padding;
  tester.platformDispatcher.textScaleFactorTestValue = 1;
  addTearDown(() => debugDefaultTargetPlatformOverride = null);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetPadding);
  addTearDown(tester.view.resetViewPadding);
  addTearDown(tester.view.resetDisplayFeatures);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}
