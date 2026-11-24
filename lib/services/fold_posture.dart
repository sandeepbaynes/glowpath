import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

enum HingePosture { unavailable, unknown, closed, partiallyOpen, fullyOpen }

/// Public iOS reserved regions in the root Flutter view's logical coordinates.
/// Division frames already include the system's interactive margins. Native
/// layout geometry is authoritative; hinge status is informational only.
@immutable
class FoldGeometry {
  const FoldGeometry({
    this.viewport = Size.zero,
    this.divisions = const <Rect>[],
    this.layoutDivisions = const <Rect>[],
    this.occlusions = const <Rect>[],
    this.status = HingePosture.unavailable,
    this.supported = false,
  });

  final Size viewport;
  final List<Rect> divisions;

  /// Includes inactive creases on an unfolded display. Keeping these anchors
  /// prevents the board from changing panes as the hinge reaches flat.
  final List<Rect> layoutDivisions;
  final List<Rect> occlusions;
  final HingePosture status;
  final bool supported;

  factory FoldGeometry.fromEvent(Object? event) {
    if (event is! Map || event['version'] != 1) {
      return const FoldGeometry();
    }
    final width = _number(event['width']);
    final height = _number(event['height']);
    if (width == null || height == null || width <= 0 || height <= 0) {
      return const FoldGeometry();
    }
    return FoldGeometry(
      viewport: Size(width, height),
      divisions: _regions(event['divisions']),
      layoutDivisions: _regions(event['layoutDivisions']),
      occlusions: _regions(event['occlusions']),
      status: HingePosture.values.firstWhere(
        (value) => value.name == event['status'],
        orElse: () => HingePosture.unknown,
      ),
      supported: event['supported'] == true,
    );
  }

  /// A stale native frame must not be applied while a rotation is in progress.
  bool matchesViewport(Size currentViewport) =>
      viewport.width > 0 &&
      viewport.height > 0 &&
      (viewport.width - currentViewport.width).abs() <= 1 &&
      (viewport.height - currentViewport.height).abs() <= 1;

  Rect? horizontalDivision(Size currentViewport) =>
      _division(currentViewport, divisions, horizontal: true);

  Rect? verticalDivision(Size currentViewport) =>
      _division(currentViewport, divisions, horizontal: false);

  Rect? horizontalLayoutDivision(Size currentViewport) => _division(
    currentViewport,
    layoutDivisions.isEmpty ? divisions : layoutDivisions,
    horizontal: true,
  );

  Rect? verticalLayoutDivision(Size currentViewport) => _division(
    currentViewport,
    layoutDivisions.isEmpty ? divisions : layoutDivisions,
    horizontal: false,
  );

  Rect? _division(Size size, List<Rect> regions, {required bool horizontal}) {
    if (!matchesViewport(size)) return null;
    final candidates = regions.where((frame) {
      if (!frame.isFinite || frame.width < 0 || frame.height < 0) return false;
      if (horizontal) {
        return frame.width > frame.height &&
            frame.left <= 1 &&
            frame.right >= size.width - 1 &&
            frame.top > 0 &&
            frame.bottom < size.height;
      }
      return frame.height > frame.width &&
          frame.top <= 1 &&
          frame.bottom >= size.height - 1 &&
          frame.left > 0 &&
          frame.right < size.width;
    }).toList();
    if (candidates.isEmpty) return null;
    candidates.sort(
      (a, b) => (b.width * b.height).compareTo(a.width * a.height),
    );
    return candidates.first.intersect(Offset.zero & size);
  }

  static double? _number(Object? value) {
    if (value is! num) return null;
    final result = value.toDouble();
    return result.isFinite ? result : null;
  }

  static List<Rect> _regions(Object? value) {
    if (value is! List) return const <Rect>[];
    final result = <Rect>[];
    for (final item in value) {
      if (item is! Map) continue;
      final x = _number(item['x']);
      final y = _number(item['y']);
      final width = _number(item['width']);
      final height = _number(item['height']);
      if (x == null || y == null || width == null || height == null) continue;
      if (width < 0 || height < 0 || (width == 0 && height == 0)) continue;
      result.add(Rect.fromLTWH(x, y, width, height));
    }
    return List<Rect>.unmodifiable(result);
  }

  @override
  bool operator ==(Object other) =>
      other is FoldGeometry &&
      viewport == other.viewport &&
      listEquals(divisions, other.divisions) &&
      listEquals(layoutDivisions, other.layoutDivisions) &&
      listEquals(occlusions, other.occlusions) &&
      status == other.status &&
      supported == other.supported;

  @override
  int get hashCode => Object.hash(
    viewport,
    Object.hashAll(divisions),
    Object.hashAll(layoutDivisions),
    Object.hashAll(occlusions),
    status,
    supported,
  );
}

/// A platform stream with injectable events for deterministic fold tests.
/// Unsupported platforms and absent plugins keep the ordinary play layout.
class FoldPosture extends ValueNotifier<FoldGeometry> {
  FoldPosture({Stream<dynamic>? events}) : super(const FoldGeometry()) {
    final source =
        events ??
        (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS
            ? _nativeEvents()
            : null);
    _subscription = source?.listen(
      (event) {
        if (!_disposed) value = FoldGeometry.fromEvent(event);
      },
      onError: (Object error) {
        if (!_disposed) value = const FoldGeometry();
      },
      onDone: () {
        if (!_disposed) value = const FoldGeometry();
      },
    );
  }

  static const _channel = EventChannel('app.glowpath/fold_geometry');
  static const _capability = OptionalMethodChannel(
    'app.glowpath/fold_geometry_support',
  );
  StreamSubscription<dynamic>? _subscription;
  bool _disposed = false;

  static Stream<dynamic> _nativeEvents() async* {
    // EventChannel reports an absent native plugin as a framework error before
    // stream onError can handle it. A nullable capability call keeps old iOS
    // binaries and widget-test platforms on the ordinary layout gracefully.
    if (await _capability.invokeMethod<bool>('available') != true) return;
    yield* _channel.receiveBroadcastStream();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    _subscription = null;
    super.dispose();
  }
}
