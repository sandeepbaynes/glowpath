import 'dart:math' as math;
import 'dart:ui' show DisplayFeature, DisplayFeatureState, DisplayFeatureType;

import 'package:flutter/widgets.dart';

import '../services/fold_posture.dart';

/// Two usable panes in root-view coordinates, with the entire hinge reserved.
/// Native frames are accepted only for the viewport that produced them.
@immutable
class FoldPaneLayout {
  const FoldPaneLayout._({
    required this.horizontal,
    required this.expanded,
    required this.division,
    required this.missionRect,
    required this.actionRect,
    required this.gap,
  });

  final bool horizontal;
  final bool expanded;
  final Rect division;
  final Rect missionRect;
  final Rect actionRect;
  final Rect gap;
  Axis get axis => horizontal ? Axis.vertical : Axis.horizontal;

  /// By default only active folds divide modal and home content. Gameplay may
  /// retain an inactive anchor with [includeInactive] to keep its board stable.
  static FoldPaneLayout? resolve(
    MediaQueryData media,
    FoldGeometry geometry, {
    bool includeInactive = false,
  }) {
    final size = media.size;
    if (!size.isFinite || size.width <= 0 || size.height <= 0) return null;
    final nativeMatches = geometry.matchesViewport(size);
    final useAnchor =
        includeInactive || geometry.status == HingePosture.partiallyOpen;
    Rect? horizontal = geometry.horizontalDivision(size);
    Rect? vertical = geometry.verticalDivision(size);
    if (useAnchor) {
      horizontal = includeInactive
          ? geometry.horizontalLayoutDivision(size) ?? horizontal
          : horizontal ?? geometry.horizontalLayoutDivision(size);
      vertical = includeInactive
          ? geometry.verticalLayoutDivision(size) ?? vertical
          : vertical ?? geometry.verticalLayoutDivision(size);
    }
    var expanded = nativeMatches && geometry.status == HingePosture.fullyOpen;
    for (final feature in media.displayFeatures) {
      final active =
          feature.type == DisplayFeatureType.hinge ||
          feature.state == DisplayFeatureState.postureHalfOpened;
      if ((feature.type != DisplayFeatureType.fold &&
              feature.type != DisplayFeatureType.hinge) ||
          (!includeInactive && !active)) {
        continue;
      }
      final frame = feature.bounds;
      if (_isDivision(frame, size, horizontal: true)) {
        if (horizontal == null && vertical == null) {
          horizontal = frame.intersect(Offset.zero & size);
          expanded = feature.state == DisplayFeatureState.postureFlat;
        }
      } else if (_isDivision(frame, size, horizontal: false)) {
        if (horizontal == null && vertical == null) {
          vertical = frame.intersect(Offset.zero & size);
          expanded = feature.state == DisplayFeatureState.postureFlat;
        }
      }
    }
    if (horizontal == null && vertical == null) return null;
    final isHorizontal = horizontal != null;
    final division = horizontal ?? vertical!;
    final safe = Rect.fromLTRB(
      media.padding.left,
      media.padding.top,
      size.width - media.padding.right,
      size.height - media.padding.bottom,
    );
    final halfGap =
        math.max(40.0, isHorizontal ? division.height : division.width) / 2 + 8;
    final gap = isHorizontal
        ? Rect.fromLTRB(
            safe.left,
            division.center.dy - halfGap,
            safe.right,
            division.center.dy + halfGap,
          )
        : Rect.fromLTRB(
            division.center.dx - halfGap,
            safe.top,
            division.center.dx + halfGap,
            safe.bottom,
          );
    var mission = isHorizontal
        ? Rect.fromLTRB(safe.left, safe.top, safe.right, gap.top)
        : Rect.fromLTRB(safe.left, safe.top, gap.left, safe.bottom);
    var action = isHorizontal
        ? Rect.fromLTRB(safe.left, gap.bottom, safe.right, safe.bottom)
        : Rect.fromLTRB(gap.right, safe.top, safe.right, safe.bottom);
    if (!_usable(mission) || !_usable(action) || !safe.contains(gap.center)) {
      return null;
    }
    final occlusions = [
      if (nativeMatches) ...geometry.occlusions,
      for (final feature in media.displayFeatures)
        if (feature.type == DisplayFeatureType.cutout) feature.bounds,
    ];
    mission = _unobscured(mission, occlusions);
    action = _unobscured(action, occlusions);
    if (!_usable(mission) || !_usable(action)) return null;
    return FoldPaneLayout._(
      horizontal: isHorizontal,
      expanded: expanded,
      division: division,
      missionRect: mission,
      actionRect: action,
      gap: gap,
    );
  }

  /// A pane has already consumed the root safe area and reserved regions.
  /// Child breakpoints and remaining keyboard insets use local coordinates.
  static MediaQueryData paneMediaQuery(MediaQueryData media, Rect pane) {
    final viewport = Offset.zero & media.size;
    final keyboardSafe = Rect.fromLTRB(
      media.viewInsets.left,
      media.viewInsets.top,
      viewport.right - media.viewInsets.right,
      viewport.bottom - media.viewInsets.bottom,
    );
    return media.copyWith(
      size: pane.size,
      padding: EdgeInsets.zero,
      viewPadding: EdgeInsets.zero,
      viewInsets: EdgeInsets.fromLTRB(
        (keyboardSafe.left - pane.left).clamp(0, pane.width),
        (keyboardSafe.top - pane.top).clamp(0, pane.height),
        (pane.right - keyboardSafe.right).clamp(0, pane.width),
        (pane.bottom - keyboardSafe.bottom).clamp(0, pane.height),
      ),
      displayFeatures: [
        for (final feature in media.displayFeatures)
          if (pane.overlaps(feature.bounds))
            DisplayFeature(
              bounds: feature.bounds.intersect(pane).shift(-pane.topLeft),
              type: feature.type,
              state: feature.state,
            ),
      ],
    );
  }

  static bool _isDivision(Rect frame, Size size, {required bool horizontal}) {
    if (!frame.isFinite || frame.width < 0 || frame.height < 0) return false;
    return horizontal
        ? frame.width > frame.height &&
              frame.left <= 1 &&
              frame.right >= size.width - 1 &&
              frame.top > 0 &&
              frame.bottom < size.height
        : frame.height > frame.width &&
              frame.top <= 1 &&
              frame.bottom >= size.height - 1 &&
              frame.left > 0 &&
              frame.right < size.width;
  }

  static bool _usable(Rect rect) =>
      rect.isFinite && rect.width > 0 && rect.height > 0;

  static Rect _unobscured(Rect pane, List<Rect> occlusions) {
    var candidates = [pane];
    for (final occlusion in occlusions) {
      if (!occlusion.isFinite || occlusion.isEmpty) continue;
      final reserved = occlusion.inflate(8);
      candidates = [
        for (final candidate in candidates)
          if (!candidate.overlaps(reserved))
            candidate
          else
            ..._subtract(candidate, reserved.intersect(candidate)),
      ];
      if (candidates.isEmpty) return Rect.zero;
    }
    candidates.sort(
      (a, b) => (b.width * b.height).compareTo(a.width * a.height),
    );
    return candidates.first;
  }

  static Iterable<Rect> _subtract(Rect pane, Rect blocked) => [
    Rect.fromLTRB(pane.left, pane.top, blocked.left, pane.bottom),
    Rect.fromLTRB(blocked.right, pane.top, pane.right, pane.bottom),
    Rect.fromLTRB(pane.left, pane.top, pane.right, blocked.top),
    Rect.fromLTRB(pane.left, blocked.bottom, pane.right, pane.bottom),
  ].where(_usable);
}
