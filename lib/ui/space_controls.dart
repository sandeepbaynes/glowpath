import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'design.dart';

/// A quiet orbital instrument with a stable, generous touch target.
/// The rectangular hit target stays fixed while its artwork presses inward.
class SpaceAction extends StatelessWidget {
  const SpaceAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.accent = Palette.light,
    this.reduceMotion = false,
    this.icon,
    this.quiet = false,
    this.compact = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final Color accent;
  final bool reduceMotion, quiet, compact;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => _SpaceKey(
    label: label,
    onPressed: onPressed,
    accent: accent,
    reduceMotion: reduceMotion,
    icon: icon,
    quiet: quiet,
    compact: compact,
  );
}

/// Navigation reads as two labelled orbital signals; it has no extra menu.
class OrbitMode extends StatelessWidget {
  const OrbitMode({
    super.key,
    required this.label,
    required this.selected,
    required this.onPressed,
    this.reduceMotion = false,
  });
  final String label;
  final bool selected, reduceMotion;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => _SpaceKey(
    label: label,
    onPressed: onPressed,
    accent: Palette.rust,
    selected: selected,
    reduceMotion: reduceMotion,
  );
}

/// A shallow, shared console at thumb height. Its controls keep their own
/// full rectangular touch areas; the hull is decoration only.
class OrbitDock extends StatelessWidget {
  const OrbitDock({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: const _OrbitDockPainter(),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: child,
    ),
  );
}

class OrbitUtility extends StatelessWidget {
  const OrbitUtility({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.reduceMotion = false,
    this.width = 56,
  });
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool reduceMotion;
  final double width;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: label,
    excludeFromSemantics: true,
    child: SizedBox(
      width: width,
      child: _SpaceKey(
        label: label,
        onPressed: onPressed,
        accent: Palette.rust,
        icon: icon,
        iconOnly: true,
        reduceMotion: reduceMotion,
      ),
    ),
  );
}

class _SpaceKey extends StatefulWidget {
  const _SpaceKey({
    required this.label,
    required this.onPressed,
    required this.accent,
    required this.reduceMotion,
    this.selected,
    this.icon,
    this.quiet = false,
    this.iconOnly = false,
    this.compact = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final Color accent;
  final bool reduceMotion;
  final bool? selected;
  final IconData? icon;
  final bool quiet;
  final bool iconOnly, compact;
  @override
  State<_SpaceKey> createState() => _SpaceKeyState();
}

typedef _KeyVisual = ({
  double selection,
  double focus,
  double enabled,
  Color accent,
});

class _KeyVisualTween extends Tween<_KeyVisual> {
  _KeyVisualTween({required super.end});
  @override
  _KeyVisual lerp(double t) => (
    selection: begin!.selection + (end!.selection - begin!.selection) * t,
    focus: begin!.focus + (end!.focus - begin!.focus) * t,
    enabled: begin!.enabled + (end!.enabled - begin!.enabled) * t,
    accent: Color.lerp(begin!.accent, end!.accent, t)!,
  );
}

class _SpaceKeyState extends State<_SpaceKey>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 90),
    reverseDuration: const Duration(milliseconds: 220),
  );
  bool _focused = false;
  bool get _enabled => widget.onPressed != null;
  bool get _still =>
      widget.reduceMotion ||
      MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.reduceMotionOf(context);

  void _activate() {
    if (!_enabled) return;
    // Keyboard and quick taps get the same visual response. Activation itself
    // is immediate, even if this control disappears during the response.
    if (!_still) {
      _press
          .animateTo(
            1,
            duration: const Duration(milliseconds: 70),
            curve: Curves.easeOutCubic,
          )
          .then((_) {
            if (mounted) _release();
          });
    }
    widget.onPressed!();
  }

  void _release() {
    if (_still) {
      _press.value = 0;
    } else {
      _press.animateBack(
        0,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_still) _press.value = 0;
  }

  @override
  void didUpdateWidget(_SpaceKey oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_enabled || _still) _release();
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  Widget _swap(Widget child) => AnimatedSwitcher(
    duration: _still ? Duration.zero : const Duration(milliseconds: 180),
    switchInCurve: Curves.easeOutCubic,
    switchOutCurve: Curves.easeInCubic,
    // Outgoing content is decorative only; the surrounding single semantic
    // button always exposes the new label and action immediately.
    layoutBuilder: (current, previous) => Stack(
      alignment: Alignment.center,
      children: [
        for (final old in previous)
          Positioned.fill(
            child: Center(child: IgnorePointer(child: old)),
          ),
        ?current,
      ],
    ),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final mode = widget.selected != null;
    final still = _still;
    return Semantics(
      container: true,
      button: true,
      enabled: _enabled,
      selected: widget.selected,
      label: widget.label,
      onTap: _enabled ? _activate : null,
      child: ExcludeSemantics(
        child: FocusableActionDetector(
          enabled: _enabled,
          mouseCursor: _enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          onShowFocusHighlight: (value) => setState(() => _focused = value),
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                _activate();
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _enabled ? _activate : null,
            onTapDown: _enabled
                ? (_) {
                    if (!still) _press.animateTo(1, curve: Curves.easeOutCubic);
                  }
                : null,
            onTapUp: (_) => _release(),
            onTapCancel: _release,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: mode || widget.iconOnly
                    ? 64
                    : widget.compact
                    ? 48
                    : 54,
                minWidth: 48,
              ),
              child: TweenAnimationBuilder<_KeyVisual>(
                tween: _KeyVisualTween(
                  end: (
                    selection: widget.selected == false ? 0 : 1,
                    focus: _focused ? 1 : 0,
                    enabled: _enabled ? 1 : 0,
                    accent: widget.accent,
                  ),
                ),
                duration: still
                    ? Duration.zero
                    : const Duration(milliseconds: 220),
                curve: Curves.easeInOutCubic,
                builder: (context, visual, _) {
                  final color = Color.lerp(
                    Palette.secondary,
                    visual.accent,
                    visual.enabled,
                  )!;
                  final textColor = Color.lerp(
                    Palette.secondary,
                    Palette.white,
                    visual.selection * visual.enabled,
                  )!;
                  return AnimatedBuilder(
                    animation: _press,
                    builder: (context, child) => Transform.scale(
                      scale: 1 - _press.value * .014,
                      transformHitTests: false,
                      child: CustomPaint(
                        painter: _SpaceKeyPainter(
                          accent: color,
                          mode: mode,
                          selected: visual.selection,
                          focused: visual.focus,
                          pressed: _press.value,
                          enabled: visual.enabled,
                          quiet: widget.quiet,
                          utility: widget.iconOnly,
                        ),
                        child: child,
                      ),
                    ),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        mode
                            ? 4
                            : widget.iconOnly
                            ? 8
                            : widget.compact
                            ? 10
                            : 16,
                        mode
                            ? 12
                            : widget.compact
                            ? 8
                            : 15,
                        mode
                            ? 4
                            : widget.iconOnly
                            ? 8
                            : widget.compact
                            ? 10
                            : 16,
                        widget.compact ? 8 : 15,
                      ),
                      child: widget.iconOnly
                          ? Center(
                              child: Icon(
                                widget.icon,
                                size: 26,
                                color: textColor,
                              ),
                            )
                          : mode
                          ? FittedBox(
                              fit: BoxFit.scaleDown,
                              child: _swap(
                                Text(
                                  widget.label,
                                  key: ValueKey(widget.label),
                                  textAlign: TextAlign.center,
                                  maxLines: 1,
                                  softWrap: false,
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox.square(
                                  dimension: widget.compact ? 18 : 22,
                                  child: _swap(
                                    widget.icon != null
                                        ? Icon(
                                            widget.icon,
                                            key: ValueKey(widget.icon),
                                            size: widget.compact ? 18 : 20,
                                            color: color,
                                          )
                                        : SizedBox.square(
                                            key: const ValueKey('launch-glyph'),
                                            dimension: 22,
                                            child: CustomPaint(
                                              painter: _LaunchGlyph(color),
                                            ),
                                          ),
                                  ),
                                ),
                                SizedBox(width: widget.compact ? 7 : 13),
                                Flexible(
                                  // Fixed-height cockpit controls must fit both
                                  // text dimensions. The outer semantic button
                                  // retains its full label and touch target.
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: _sizeTransition(
                                      still: still,
                                      child: _swap(
                                        Text(
                                          widget.label,
                                          key: ValueKey(widget.label),
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          softWrap: false,
                                          style: TextStyle(
                                            color: textColor,
                                            fontSize: widget.compact ? 14 : 15,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: .5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (!widget.compact) const SizedBox(width: 22),
                              ],
                            ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _sizeTransition({required bool still, required Widget child}) => still
    ? child
    : AnimatedSize(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeInOutCubic,
        child: child,
      );

class _LaunchGlyph extends CustomPainter {
  const _LaunchGlyph(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    canvas.drawCircle(
      center,
      size.width * .44,
      Paint()
        ..color = color.withValues(alpha: .24)
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8,
    );
    final mark = Path()
      ..moveTo(center.dx - 2.5, center.dy - 4.5)
      ..quadraticBezierTo(
        center.dx - 3.5,
        center.dy - 5,
        center.dx - 3.5,
        center.dy - 3.5,
      )
      ..lineTo(center.dx - 3.5, center.dy + 3.5)
      ..quadraticBezierTo(
        center.dx - 3.5,
        center.dy + 5,
        center.dx - 2.5,
        center.dy + 4.5,
      )
      ..lineTo(center.dx + 4, center.dy + .7)
      ..quadraticBezierTo(
        center.dx + 5,
        center.dy,
        center.dx + 4,
        center.dy - .7,
      )
      ..close();
    canvas.drawPath(mark, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_LaunchGlyph old) => color != old.color;
}

class _OrbitDockPainter extends CustomPainter {
  const _OrbitDockPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = (Offset.zero & size).deflate(1);
    final dock = RRect.fromRectAndRadius(bounds, const Radius.circular(24));
    canvas.drawRRect(
      dock.shift(const Offset(0, 5)),
      Paint()
        ..color = Colors.black.withValues(alpha: .18)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawRRect(
      dock,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(Palette.board, Palette.white, .035)!,
            Palette.paper.withValues(alpha: .96),
          ],
        ).createShader(bounds),
    );
    canvas.drawRRect(
      dock,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..color = Palette.secondary.withValues(alpha: .13),
    );
  }

  @override
  bool shouldRepaint(_OrbitDockPainter old) => false;
}

class _SpaceKeyPainter extends CustomPainter {
  const _SpaceKeyPainter({
    required this.accent,
    required this.mode,
    required this.selected,
    required this.focused,
    required this.pressed,
    required this.enabled,
    this.quiet = false,
    this.utility = false,
  });
  final Color accent;
  final bool mode, quiet, utility;
  final double selected, focused, pressed, enabled;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    if (utility) {
      // Utility glyphs sit quietly until touched; no permanent HUD brackets.
      if (pressed > 0 || focused > 0) {
        canvas.drawCircle(
          center,
          21,
          Paint()..color = accent.withValues(alpha: .07 * pressed),
        );
        canvas.drawCircle(
          center,
          21,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1
            ..color = accent.withValues(alpha: .5 * focused + .12 * pressed),
        );
      }
      return;
    }
    if (mode) {
      // Selection and keyboard focus share one precise underline, never a fill.
      final visibility = math.max(selected, focused);
      final half = math.min(24.0, size.width * .26);
      final y = size.height - 7;
      canvas.drawLine(
        Offset(center.dx - half, y),
        Offset(center.dx + half, y),
        Paint()
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 1.7 + focused * .6
          ..color = Color.lerp(
            accent,
            Palette.white,
            focused,
          )!.withValues(alpha: visibility),
      );
      return;
    }
    final bounds = (Offset.zero & size).deflate(1);
    final radius = math.min(18.0, size.height * .28);
    final surface = RRect.fromRectAndRadius(bounds, Radius.circular(radius));
    if (!quiet) {
      canvas.drawRRect(
        surface.shift(Offset(0, 2 * (1 - pressed))),
        Paint()..color = Colors.black.withValues(alpha: .16),
      );
    }
    canvas.drawRRect(
      surface,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(
              Palette.board,
              accent,
              (quiet ? .025 : .09) + pressed * .035,
            )!,
            Color.lerp(Palette.paper, accent, quiet ? .01 : .035)!,
          ],
        ).createShader(bounds),
    );
    canvas.drawRRect(
      surface,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .85 + focused * .6
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(
              Palette.secondary,
              accent,
              quiet ? .15 : .7,
            )!.withValues(alpha: .17 + enabled * .23 + focused * .4),
            accent.withValues(alpha: .07 + pressed * .12 + focused * .4),
          ],
        ).createShader(bounds),
    );
    if (!quiet) {
      final sheen = Path()
        ..moveTo(bounds.left + radius, bounds.top + 2)
        ..lineTo(bounds.right - radius, bounds.top + 2);
      canvas.drawPath(
        sheen,
        Paint()
          ..strokeWidth = .65
          ..color = Palette.white.withValues(alpha: .045 * (1 - pressed)),
      );
    }
  }

  @override
  bool shouldRepaint(_SpaceKeyPainter old) =>
      accent != old.accent ||
      mode != old.mode ||
      selected != old.selected ||
      focused != old.focused ||
      pressed != old.pressed ||
      enabled != old.enabled ||
      utility != old.utility ||
      quiet != old.quiet;
}
