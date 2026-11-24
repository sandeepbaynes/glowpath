import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/services/fold_posture.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('native points and system margins pass through without scaling', () {
    final geometry = FoldGeometry.fromEvent(_event());
    expect(geometry.viewport, const Size(669, 951));
    expect(geometry.status, HingePosture.partiallyOpen);
    expect(geometry.supported, isTrue);
    expect(
      geometry.horizontalDivision(const Size(669, 951)),
      const Rect.fromLTWH(0, 461, 669, 28),
    );
    expect(geometry.occlusions, [const Rect.fromLTWH(641, -5, 33, 24)]);
    expect(geometry.verticalDivision(const Size(669, 951)), isNull);
  });

  test('inactive native creases retain zero-thickness layout anchors', () {
    for (final horizontal in [true, false]) {
      final size = horizontal ? const Size(669, 951) : const Size(951, 669);
      final anchor = horizontal
          ? const Rect.fromLTWH(0, 475.5, 669, 0)
          : const Rect.fromLTWH(475.5, 0, 0, 669);
      final geometry = FoldGeometry.fromEvent({
        ..._event(),
        'width': size.width,
        'height': size.height,
        'status': 'fullyOpen',
        'divisions': <Object>[],
        'layoutDivisions': [_region(anchor)],
      });
      expect(geometry.divisions, isEmpty);
      expect(geometry.layoutDivisions, [anchor]);
      expect(geometry.horizontalDivision(size), isNull);
      expect(geometry.verticalDivision(size), isNull);
      expect(
        horizontal
            ? geometry.horizontalLayoutDivision(size)
            : geometry.verticalLayoutDivision(size),
        anchor,
      );
      expect(
        horizontal
            ? geometry.verticalLayoutDivision(size)
            : geometry.horizontalLayoutDivision(size),
        isNull,
      );
    }
  });

  test('layout anchors take precedence over active division margins', () {
    final geometry = FoldGeometry.fromEvent({
      ..._event(),
      'layoutDivisions': [_region(const Rect.fromLTWH(0, 475.5, 669, 0))],
    });
    expect(
      geometry.horizontalDivision(const Size(669, 951)),
      const Rect.fromLTWH(0, 461, 669, 28),
    );
    expect(
      geometry.horizontalLayoutDivision(const Size(669, 951)),
      const Rect.fromLTWH(0, 475.5, 669, 0),
    );
  });

  test('legacy messages fall back to active division geometry', () {
    for (final horizontal in [true, false]) {
      final size = horizontal ? const Size(669, 951) : const Size(951, 669);
      final active = horizontal
          ? const Rect.fromLTWH(0, 461, 669, 28)
          : const Rect.fromLTWH(461, 0, 28, 669);
      for (final includeEmpty in [false, true]) {
        final geometry = FoldGeometry.fromEvent({
          ..._event(),
          'width': size.width,
          'height': size.height,
          'divisions': [_region(active)],
          if (includeEmpty) 'layoutDivisions': <Object>[],
        });
        expect(geometry.layoutDivisions, isEmpty);
        expect(
          horizontal
              ? geometry.horizontalLayoutDivision(size)
              : geometry.verticalLayoutDivision(size),
          active,
        );
      }
    }
  });

  test(
    'invalid layout payloads are filtered and stale anchors are rejected',
    () {
      final geometry = FoldGeometry.fromEvent({
        ..._event(),
        'divisions': <Object>[],
        'layoutDivisions': [
          null,
          'invalid',
          {'x': 0, 'y': 100, 'width': double.infinity, 'height': 0},
          {'x': double.nan, 'y': 100, 'width': 669, 'height': 0},
          {'x': 0, 'y': 100, 'width': -669, 'height': 0},
          {'x': 0, 'y': 100, 'width': 0, 'height': 0},
          {'x': 0, 'y': 100, 'width': 669},
          _region(const Rect.fromLTWH(0, 475.5, 669, 0)),
        ],
      });
      expect(geometry.layoutDivisions, [const Rect.fromLTWH(0, 475.5, 669, 0)]);
      expect(geometry.horizontalLayoutDivision(const Size(951, 669)), isNull);
      expect(geometry.verticalLayoutDivision(const Size(951, 669)), isNull);

      final unusableAnchors = FoldGeometry.fromEvent({
        ..._event(),
        'divisions': <Object>[],
        'layoutDivisions': [
          _region(const Rect.fromLTWH(0, 475, 200, 0)),
          _region(const Rect.fromLTWH(0, 0, 669, 0)),
          _region(const Rect.fromLTWH(0, 951, 669, 0)),
          _region(const Rect.fromLTWH(0, 0, 0, 951)),
          _region(const Rect.fromLTWH(669, 0, 0, 951)),
          _region(const Rect.fromLTWH(334, 0, 0, 200)),
        ],
      });
      expect(
        unusableAnchors.horizontalLayoutDivision(const Size(669, 951)),
        isNull,
      );
      expect(
        unusableAnchors.verticalLayoutDivision(const Size(669, 951)),
        isNull,
      );
    },
  );

  test('rotation cannot use stale geometry or infer posture from aspect', () {
    final geometry = FoldGeometry.fromEvent(_event());
    expect(geometry.horizontalDivision(const Size(951, 669)), isNull);
    const flat = FoldGeometry(
      viewport: Size(669, 951),
      supported: true,
      status: HingePosture.fullyOpen,
    );
    expect(flat.horizontalDivision(const Size(669, 951)), isNull);
  });

  test('vertical division uses its real bounds and clips outside the view', () {
    const geometry = FoldGeometry(
      viewport: Size(951, 669),
      divisions: [Rect.fromLTWH(461, -12, 29, 700)],
    );
    expect(
      geometry.verticalDivision(const Size(951, 669)),
      const Rect.fromLTWH(461, 0, 29, 669),
    );
    expect(geometry.horizontalDivision(const Size(951, 669)), isNull);
  });

  test(
    'partial and edge regions do not create an unusable two-panel layout',
    () {
      const geometry = FoldGeometry(
        viewport: Size(669, 951),
        divisions: [
          Rect.fromLTWH(0, 461, 200, 28),
          Rect.fromLTWH(0, 0, 669, 30),
          Rect.fromLTWH(0, 940, 669, 30),
        ],
      );
      expect(geometry.horizontalDivision(const Size(669, 951)), isNull);
    },
  );

  test('malformed or future bridge messages safely retain normal layout', () {
    for (final event in [
      null,
      'invalid',
      {'version': 2},
      {'version': 1},
    ]) {
      expect(FoldGeometry.fromEvent(event), const FoldGeometry());
    }
    final geometry = FoldGeometry.fromEvent({
      ..._event(),
      'status': 'futurePosture',
      'divisions': [
        {'x': double.nan, 'y': 0, 'width': 5, 'height': 10},
        {'x': 0, 'y': 0, 'width': -5, 'height': 10},
        {'x': 0, 'y': 0, 'width': 0, 'height': 0},
      ],
    });
    expect(geometry.status, HingePosture.unknown);
    expect(geometry.divisions, isEmpty);
  });

  test(
    'native unfold updates clear geometry without redundant notifications',
    () async {
      final events = StreamController<dynamic>();
      final posture = FoldPosture(events: events.stream);
      var notifications = 0;
      posture.addListener(() => notifications++);
      events.add(_event());
      await Future<void>.delayed(Duration.zero);
      expect(notifications, 1);
      events.add(_event());
      await Future<void>.delayed(Duration.zero);
      expect(notifications, 1);
      events.add({..._event(), 'divisions': [], 'status': 'fullyOpen'});
      await Future<void>.delayed(Duration.zero);
      expect(posture.value.divisions, isEmpty);
      expect(posture.value.status, HingePosture.fullyOpen);
      expect(notifications, 2);
      posture.dispose();
      await events.close();
    },
  );

  test(
    'layout-only changes notify once and identical anchors deduplicate',
    () async {
      final events = StreamController<dynamic>();
      final posture = FoldPosture(events: events.stream);
      var notifications = 0;
      posture.addListener(() => notifications++);
      final initial = {
        ..._event(),
        'status': 'fullyOpen',
        'divisions': <Object>[],
        'layoutDivisions': [_region(const Rect.fromLTWH(0, 475.5, 669, 0))],
      };
      events.add(initial);
      await Future<void>.delayed(Duration.zero);
      final first = posture.value;
      expect(notifications, 1);
      events.add({...initial});
      await Future<void>.delayed(Duration.zero);
      expect(posture.value, first);
      expect(posture.value.hashCode, first.hashCode);
      expect(notifications, 1);

      events.add({
        ...initial,
        'layoutDivisions': [_region(const Rect.fromLTWH(0, 476.5, 669, 0))],
      });
      await Future<void>.delayed(Duration.zero);
      expect(posture.value, isNot(first));
      expect(notifications, 2);
      events.add({...initial, 'layoutDivisions': <Object>[]});
      await Future<void>.delayed(Duration.zero);
      expect(posture.value.layoutDivisions, isEmpty);
      expect(notifications, 3);
      posture.dispose();
      await events.close();
    },
  );

  test('stream errors and closure clear stale folding state', () async {
    final events = StreamController<dynamic>();
    final posture = FoldPosture(events: events.stream);
    events.add(_event());
    await Future<void>.delayed(Duration.zero);
    events.addError(PlatformException(code: 'unavailable'));
    await Future<void>.delayed(Duration.zero);
    expect(posture.value, const FoldGeometry());
    events.add(_event());
    await Future<void>.delayed(Duration.zero);
    await events.close();
    expect(posture.value, const FoldGeometry());
    posture.dispose();
  });

  test(
    'older native binaries and iOS test platforms need no manual switch',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      final posture = FoldPosture();
      await Future<void>.delayed(Duration.zero);
      expect(posture.value, const FoldGeometry());
      posture.dispose();
    },
  );
}

Map<String, double> _region(Rect rect) => {
  'x': rect.left,
  'y': rect.top,
  'width': rect.width,
  'height': rect.height,
};

Map<String, Object> _event() => {
  'version': 1,
  'supported': true,
  'width': 669.0,
  'height': 951.0,
  'status': 'partiallyOpen',
  'divisions': [
    {'x': 0.0, 'y': 461.0, 'width': 669.0, 'height': 28.0},
  ],
  'occlusions': [
    {'x': 641.0, 'y': -5.0, 'width': 33.0, 'height': 24.0},
  ],
};
