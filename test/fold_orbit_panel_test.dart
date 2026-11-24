import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/services/fold_posture.dart';
import 'package:glowpath/ui/fold_layout.dart';
import 'package:glowpath/ui/orbit_sheet.dart';
import 'package:material_ui/material_ui.dart';

const _cases = [
  _FoldCase('Android clamshell', Size(393, 852), horizontal: true),
  _FoldCase('Android book', Size(951, 669), horizontal: false),
  _FoldCase(
    'iOS measured tabletop',
    Size(669, 951),
    horizontal: true,
    ios: true,
  ),
];

void main() {
  test(
    'inactive anchors are optional and stale native frames are rejected',
    () {
      const size = Size(669, 951);
      const media = MediaQueryData(size: size);
      const geometry = FoldGeometry(
        viewport: size,
        status: HingePosture.fullyOpen,
        layoutDivisions: [Rect.fromLTWH(0, 475.5, 669, 0)],
      );
      expect(FoldPaneLayout.resolve(media, geometry), isNull);
      final expanded = FoldPaneLayout.resolve(
        media,
        geometry,
        includeInactive: true,
      )!;
      expect(expanded.expanded, isTrue);
      expect(expanded.gap.height, 56);
      expect(
        FoldPaneLayout.resolve(
          const MediaQueryData(size: Size(951, 669)),
          geometry,
          includeInactive: true,
        ),
        isNull,
      );
      final flatAndroid = media.copyWith(
        displayFeatures: const [
          DisplayFeature(
            bounds: Rect.fromLTWH(0, 475.5, 669, 0),
            type: DisplayFeatureType.fold,
            state: DisplayFeatureState.postureFlat,
          ),
        ],
      );
      expect(FoldPaneLayout.resolve(flatAndroid, const FoldGeometry()), isNull);
      expect(
        FoldPaneLayout.resolve(
          flatAndroid,
          const FoldGeometry(),
          includeInactive: true,
        ),
        isNotNull,
      );
    },
  );

  test(
    'physical Android hinge and cutouts reserve the largest usable panes',
    () {
      const cutout = Rect.fromLTWH(827, 585, 124, 84);
      const media = MediaQueryData(
        size: Size(951, 669),
        padding: EdgeInsets.only(top: 24, bottom: 24),
        displayFeatures: [
          DisplayFeature(
            bounds: Rect.fromLTWH(461, 0, 29, 669),
            type: DisplayFeatureType.hinge,
            state: DisplayFeatureState.unknown,
          ),
          DisplayFeature(
            bounds: cutout,
            type: DisplayFeatureType.cutout,
            state: DisplayFeatureState.unknown,
          ),
        ],
      );
      final panes = FoldPaneLayout.resolve(media, const FoldGeometry())!;
      expect(panes.horizontal, isFalse);
      expect(panes.missionRect, const Rect.fromLTRB(0, 24, 447.5, 645));
      expect(panes.actionRect, const Rect.fromLTRB(503.5, 24, 951, 577));
      expect(panes.actionRect.overlaps(cutout.inflate(8)), isFalse);
      final local = FoldPaneLayout.paneMediaQuery(media, panes.actionRect);
      expect(local.size, panes.actionRect.size);
      expect(local.padding, EdgeInsets.zero);
      expect(local.displayFeatures, isEmpty);
    },
  );

  for (final scenario in _cases) {
    for (final initiallyFolded in [false, true]) {
      testWidgets(
        '${scenario.name}: panel ${initiallyFolded ? 'opens folded' : 'opens flat then folds'} without resetting content',
        (tester) async {
          tester.view.physicalSize = scenario.size;
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final geometry = ValueNotifier(scenario.geometry(initiallyFolded));
          final media = ValueNotifier(scenario.media(initiallyFolded));
          addTearDown(geometry.dispose);
          addTearDown(media.dispose);
          await tester.pumpWidget(
            MaterialApp(
              builder: (context, child) =>
                  ValueListenableBuilder<MediaQueryData>(
                    valueListenable: media,
                    builder: (context, data, _) =>
                        MediaQuery(data: data, child: child!),
                  ),
              home: _PanelLauncher(geometry: geometry),
            ),
          );
          await tester.tap(find.byKey(const ValueKey('open-test-panel')));
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(const ValueKey('increment-panel')));
          await tester.pump();
          expect(find.text('Count 1'), findsOneWidget);
          if (!initiallyFolded) {
            expect(
              find.byKey(const ValueKey('fold-panel-action')),
              findsNothing,
            );
            if (scenario.size.shortestSide < 600) {
              expect(find.byType(BottomSheet), findsOneWidget);
            }
          }

          for (final folded in [true, false, true]) {
            geometry.value = scenario.geometry(folded);
            media.value = scenario.media(folded);
            await tester.pump();
            // The old centered panel must disappear immediately. During the
            // entrance the close control stays on the action side of the gap.
            if (folded) {
              await tester.pump(const Duration(milliseconds: 60));
              final panes = FoldPaneLayout.resolve(
                media.value,
                geometry.value,
              )!;
              final close = tester.getRect(
                find.byKey(const ValueKey('close-sheet')),
              );
              expect(close.overlaps(panes.gap), isFalse);
            }
            await tester.pumpAndSettle();
            expect(find.text('Count 1'), findsOneWidget);
            expect(find.byType(OrbitSheet), findsOneWidget);
            if (folded) {
              final panes = FoldPaneLayout.resolve(
                media.value,
                geometry.value,
              )!;
              expect(
                tester.getRect(find.byKey(const ValueKey('fold-panel-action'))),
                panes.actionRect,
              );
              expect(
                tester.getRect(
                  find.byKey(const ValueKey('fold-panel-companion')),
                ),
                panes.missionRect,
              );
              _contained(
                panes.actionRect,
                tester.getRect(find.byType(OrbitSheet)),
              );
              _contained(
                panes.actionRect,
                tester.getRect(find.byKey(const ValueKey('increment-panel'))),
              );
              expect(
                MediaQuery.sizeOf(tester.element(find.byType(_PanelContent))),
                panes.actionRect.size,
              );
              expect(find.byType(FittedBox), findsNothing);
            } else {
              expect(
                find.byKey(const ValueKey('fold-panel-companion')),
                findsNothing,
              );
            }
            expect(tester.takeException(), isNull);
          }
          await tester.tap(find.byKey(const ValueKey('close-sheet')));
          await tester.pumpAndSettle();
          expect(find.byType(OrbitSheet), findsNothing);
          await tester.pumpWidget(const SizedBox());
        },
      );
    }
  }

  testWidgets('reduced motion places a folded panel immediately', (
    tester,
  ) async {
    const scenario = _FoldCase('compact', Size(393, 852), horizontal: true);
    tester.view.physicalSize = scenario.size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final media = scenario.media(true).copyWith(disableAnimations: true);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: media,
          child: OrbitPanelFrame(
            title: 'CONTROL',
            onClose: () {},
            fit: true,
            child: const _PanelContent(),
          ),
        ),
      ),
    );
    await tester.pump();
    final panes = FoldPaneLayout.resolve(media, const FoldGeometry())!;
    _contained(panes.actionRect, tester.getRect(find.byType(OrbitSheet)));
    final opacity = tester.widget<Opacity>(
      find
          .descendant(
            of: find.byKey(const ValueKey('fold-panel-action')),
            matching: find.byType(Opacity),
          )
          .first,
    );
    expect(opacity.opacity, 1);
    expect(tester.takeException(), isNull);
  });
}

void _contained(Rect outer, Rect inner) {
  expect(inner.left, greaterThanOrEqualTo(outer.left - .01));
  expect(inner.top, greaterThanOrEqualTo(outer.top - .01));
  expect(inner.right, lessThanOrEqualTo(outer.right + .01));
  expect(inner.bottom, lessThanOrEqualTo(outer.bottom + .01));
}

class _FoldCase {
  const _FoldCase(
    this.name,
    this.size, {
    required this.horizontal,
    this.ios = false,
  });
  final String name;
  final Size size;
  final bool horizontal;
  final bool ios;

  Rect get anchor => horizontal
      ? Rect.fromLTWH(0, size.height / 2, size.width, 0)
      : Rect.fromLTWH(size.width / 2, 0, 0, size.height);
  Rect get active => horizontal
      ? Rect.fromLTWH(0, size.height / 2 - 14, size.width, 28)
      : Rect.fromLTWH(size.width / 2 - 14, 0, 28, size.height);

  FoldGeometry geometry(bool folded) => ios
      ? FoldGeometry(
          viewport: size,
          supported: true,
          status: folded ? HingePosture.partiallyOpen : HingePosture.fullyOpen,
          divisions: folded ? [active] : const [],
          layoutDivisions: [anchor],
          occlusions: const [Rect.fromLTWH(525, 0, 144, 82)],
        )
      : const FoldGeometry();

  MediaQueryData media(bool folded) => MediaQueryData(
    size: size,
    padding: ios
        ? const EdgeInsets.only(top: 82, bottom: 34)
        : const EdgeInsets.only(top: 24, bottom: 24),
    displayFeatures: ios
        ? const []
        : [
            DisplayFeature(
              bounds: anchor,
              type: DisplayFeatureType.fold,
              state: folded
                  ? DisplayFeatureState.postureHalfOpened
                  : DisplayFeatureState.postureFlat,
            ),
          ],
  );
}

class _PanelLauncher extends StatefulWidget {
  const _PanelLauncher({required this.geometry});
  final ValueListenable<FoldGeometry> geometry;
  @override
  State<_PanelLauncher> createState() => _PanelLauncherState();
}

class _PanelLauncherState extends State<_PanelLauncher>
    with SingleTickerProviderStateMixin {
  late final _motion = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 200),
  );

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: Center(
      child: TextButton(
        key: const ValueKey('open-test-panel'),
        onPressed: () => showOrbitPanel(
          context: context,
          title: 'CONTROL',
          motion: _motion,
          fit: true,
          foldGeometry: widget.geometry,
          foldCompanionBuilder: (_) => const Center(child: Text('Mission map')),
          builder: (_) => const _PanelContent(),
        ),
        child: const Text('Open'),
      ),
    ),
  );
}

class _PanelContent extends StatefulWidget {
  const _PanelContent();
  @override
  State<_PanelContent> createState() => _PanelContentState();
}

class _PanelContentState extends State<_PanelContent> {
  var count = 0;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Expanded(child: Center(child: Text('Count $count'))),
      SizedBox(
        height: 48,
        child: TextButton(
          key: const ValueKey('increment-panel'),
          onPressed: () => setState(() => count++),
          child: const Text('Adjust control'),
        ),
      ),
    ],
  );
}
