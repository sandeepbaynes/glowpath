import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// A snapshot of the visible craft, in global logical screen coordinates.
/// The rendered transform includes the vertical fold rail and pressure pulse.
class LaunchFlightOrigin {
  const LaunchFlightOrigin({
    required this.position,
    required this.angle,
    required this.length,
    required this.heat,
    required this.urgent,
    required this.trailColor,
  });
  final Offset position;
  final double angle, length, heat;
  final bool urgent;
  final Color trailColor;

  LaunchFlightOrigin shifted(Offset offset) => LaunchFlightOrigin(
    position: position + offset,
    angle: angle,
    length: length,
    heat: heat,
    urgent: urgent,
    trailColor: trailColor,
  );
}

/// Captures geometry on demand, before the countdown changes to its failed
/// layout. It adds no ticker, widget rebuild or global-key reparenting.
class CountdownFlightTracker {
  RenderCountdownFlight? _current;
  LaunchFlightOrigin? capture() => _current?._capture();
}

class CountdownFlightAnchor extends SingleChildRenderObjectWidget {
  const CountdownFlightAnchor({
    super.key,
    required this.tracker,
    required this.heat,
    required this.urgent,
    required this.trailColor,
    required super.child,
  });
  final CountdownFlightTracker? tracker;
  final double heat;
  final bool urgent;
  final Color trailColor;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderCountdownFlight(tracker, heat, urgent, trailColor);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderCountdownFlight renderObject,
  ) {
    renderObject.update(tracker, heat, urgent, trailColor);
  }
}

class RenderCountdownFlight extends RenderProxyBox {
  RenderCountdownFlight(this.tracker, this.heat, this.urgent, this.trailColor);
  CountdownFlightTracker? tracker;
  double heat;
  bool urgent;
  Color trailColor;

  void update(
    CountdownFlightTracker? next,
    double nextHeat,
    bool nextUrgent,
    Color nextTrail,
  ) {
    if (tracker != next && tracker?._current == this) tracker?._current = null;
    tracker = next;
    heat = nextHeat;
    urgent = nextUrgent;
    trailColor = nextTrail;
    if (attached) tracker?._current = this;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    tracker?._current = this;
  }

  @override
  void detach() {
    if (tracker?._current == this) tracker?._current = null;
    super.detach();
  }

  LaunchFlightOrigin? _capture() {
    if (!attached || !hasSize || size.isEmpty) return null;
    final local = Offset(size.width * 36 / 58, size.height / 2);
    final center = localToGlobal(local);
    final forward = localToGlobal(local + Offset(size.width / 58, 0)) - center;
    if (!center.dx.isFinite || !center.dy.isFinite || forward.distance == 0) {
      return null;
    }
    return LaunchFlightOrigin(
      position: center,
      angle: math.atan2(forward.dx, -forward.dy),
      length: forward.distance * 13.2 * 2.31,
      heat: heat,
      urgent: urgent,
      trailColor: trailColor,
    );
  }
}
