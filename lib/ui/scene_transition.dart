import 'package:material_ui/material_ui.dart';

/// Dissolves keyed scenes without moving their controls or delaying input.
///
/// On rapid A -> B -> C changes, existing layers fade from their current
/// opacity instead of restarting at full visibility. Transparent incoming
/// scenes also reveal the content behind them. Only the newest scene is active.
class SceneTransition extends StatefulWidget {
  const SceneTransition({
    super.key,
    required this.child,
    this.reduceMotion = false,
    this.duration = const Duration(milliseconds: 320),
    this.fill = true,
  });

  final Widget child;
  final bool reduceMotion, fill;
  final Duration duration;

  @override
  State<SceneTransition> createState() => _SceneTransitionState();
}

class _SceneTransitionState extends State<SceneTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: 1,
  )..addStatusListener(_statusChanged);
  late final Animation<double> _opacity = _controller.drive(
    CurveTween(curve: Curves.easeInOutCubic),
  );
  late Widget _current = widget.child;
  final List<_RetainedScene> _previous = [];
  int _identity = 0;
  bool _still = true;

  void _statusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed && _previous.isNotEmpty) {
      setState(_previous.clear);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncMotion();
  }

  void _syncMotion() {
    _still =
        widget.reduceMotion ||
        widget.duration == Duration.zero ||
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.reduceMotionOf(context);
    if (_still) {
      _previous.clear();
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(SceneTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.duration;
    _syncMotion();
    if (!Widget.canUpdate(_current, widget.child)) {
      if (!_still) {
        final progress = _opacity.value;
        for (var i = 0; i < _previous.length; i++) {
          final old = _previous[i];
          _previous[i] = _RetainedScene(
            old.identity,
            old.child,
            old.opacity * (1 - progress),
          );
        }
        _previous.removeWhere((scene) => scene.opacity <= 0);
      }
      if (!_still && _opacity.value > 0) {
        _previous.add(_RetainedScene(_identity, _current, _opacity.value));
      }
      _identity++;
      if (!_still) _controller.forward(from: 0);
    }
    _current = widget.child;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _layer({
    required int identity,
    required Widget child,
    required Animation<double> opacity,
    required bool active,
  }) => KeyedSubtree(
    key: ValueKey(identity),
    child: ExcludeSemantics(
      excluding: !active,
      child: ExcludeFocus(
        excluding: !active,
        child: IgnorePointer(
          ignoring: !active,
          child: TickerMode(
            enabled: active,
            child: FadeTransition(
              opacity: opacity,
              // Incoming actions and announcements exist from the first frame.
              alwaysIncludeSemantics: active,
              child: child,
            ),
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final stack = Stack(
      fit: widget.fill ? StackFit.expand : StackFit.loose,
      alignment: Alignment.topCenter,
      // Intrinsic outgoing content keeps its natural height while the outer
      // AnimatedSize clips to the smoothly changing visible height.
      clipBehavior: widget.fill ? Clip.hardEdge : Clip.none,
      children: [
        for (final old in _previous)
          Positioned(
            key: ValueKey(old.identity),
            left: widget.fill ? null : 0,
            top: widget.fill ? null : 0,
            right: widget.fill ? null : 0,
            child: _layer(
              identity: old.identity,
              child: old.child,
              opacity: _opacity.drive(Tween(begin: old.opacity, end: 0.0)),
              active: false,
            ),
          ),
        Positioned(
          key: ValueKey(_identity),
          child: _layer(
            identity: _identity,
            child: _current,
            opacity: _opacity,
            active: true,
          ),
        ),
      ],
    );
    return widget.fill || _still
        ? stack
        : AnimatedSize(
            duration: widget.duration,
            curve: Curves.easeInOutCubic,
            alignment: Alignment.topCenter,
            clipBehavior: Clip.hardEdge,
            child: stack,
          );
  }
}

class _RetainedScene {
  const _RetainedScene(this.identity, this.child, this.opacity);
  final int identity;
  final Widget child;
  final double opacity;
}
