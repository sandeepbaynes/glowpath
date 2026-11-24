import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'design.dart';

/// A custom spacecraft control. Visual styling is independent of Material
/// buttons; keyboard, focus, and semantic activation remain conventional.
class FlightControl extends StatefulWidget {
  const FlightControl({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.accent = Palette.rust,
    this.primary = false,
    this.compact = false,
    this.value,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final Color accent;
  final bool primary, compact;
  final String? value;
  @override
  State<FlightControl> createState() => _FlightControlState();
}

class _FlightControlState extends State<FlightControl> {
  bool _focused = false, _pressed = false;
  void _activate() => widget.onTap?.call();
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    final color = enabled
        ? widget.accent
        : Palette.secondary.withValues(alpha: .45);
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      value: widget.value,
      onTap: enabled ? _activate : null,
      child: ExcludeSemantics(
        child: FocusableActionDetector(
          enabled: enabled,
          onShowFocusHighlight: (v) => setState(() => _focused = v),
          mouseCursor: enabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
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
            onTap: enabled ? _activate : null,
            onTapDown: enabled ? (_) => setState(() => _pressed = true) : null,
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            child: CustomPaint(
              painter: _ControlPainter(
                color,
                widget.primary,
                _focused,
                _pressed,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: widget.primary ? 72 : 56,
                  minWidth: 56,
                ),
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.compact ? 8 : 18,
                    vertical: 12,
                  ),
                  child: widget.compact
                      ? Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(widget.icon, size: 23, color: color),
                            const SizedBox(height: 5),
                            Text(
                              widget.label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                color: enabled
                                    ? Palette.white
                                    : Palette.secondary,
                              ),
                            ),
                          ],
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              widget.icon,
                              size: widget.primary ? 29 : 22,
                              color: color,
                            ),
                            const SizedBox(width: 12),
                            Flexible(
                              child: Text(
                                widget.label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: widget.primary ? 18 : 15,
                                  letterSpacing: widget.primary ? 1.3 : .3,
                                  fontWeight: FontWeight.w600,
                                  color: enabled
                                      ? Palette.white
                                      : Palette.secondary,
                                ),
                              ),
                            ),
                            if (widget.primary) ...[
                              const SizedBox(width: 12),
                              Icon(Icons.chevron_right_rounded, color: color),
                            ],
                          ],
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ControlPainter extends CustomPainter {
  const _ControlPainter(this.color, this.primary, this.focused, this.pressed);
  final Color color;
  final bool primary, focused, pressed;
  @override
  void paint(Canvas canvas, Size size) {
    const cut = 13.0;
    final p = Path()
      ..moveTo(cut, 1)
      ..lineTo(size.width - 1, 1)
      ..lineTo(size.width - 1, size.height - cut)
      ..lineTo(size.width - cut, size.height - 1)
      ..lineTo(1, size.height - 1)
      ..lineTo(1, cut)
      ..close();
    canvas.drawPath(
      p,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(
              alpha: pressed
                  ? .28
                  : primary
                  ? .19
                  : .07,
            ),
            const Color(0xFF0B1425),
          ],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      p,
      Paint()
        ..color = color.withValues(alpha: focused ? 1 : .6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = focused ? 2.5 : 1,
    );
    canvas.drawLine(
      Offset(17, size.height - 1),
      Offset(primary ? size.width * .35 : 32, size.height - 1),
      Paint()
        ..color = color
        ..strokeWidth = primary ? 3 : 2,
    );
    if (primary) {
      for (var i = 0; i < 3; i++) {
        canvas.drawLine(
          Offset(size.width - 23 - i * 5, 5),
          Offset(size.width - 20 - i * 5, 11),
          Paint()
            ..color = color.withValues(alpha: .6)
            ..strokeWidth = 1,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ControlPainter old) =>
      old.color != color ||
      old.primary != primary ||
      old.focused != focused ||
      old.pressed != pressed;
}

/// The countdown is a graphic instrument, with text used for precision and AT.
class OrbitClock extends StatelessWidget {
  const OrbitClock({
    super.key,
    required this.progress,
    required this.readout,
    required this.label,
    this.accent = Palette.rust,
    this.size = 88,
    this.urgent = false,
  });
  final double progress, size;
  final String readout, label;
  final Color accent;
  final bool urgent;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '$label. $readout',
    child: ExcludeSemantics(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(
          painter: _ClockPainter(progress.clamp(0, 1), accent, urgent),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      readout,
                      style: TextStyle(
                        color: accent,
                        fontSize: size * .23,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label.toUpperCase(),
                      style: TextStyle(
                        fontSize: size * .085,
                        color: Palette.secondary,
                        letterSpacing: .8,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _ClockPainter extends CustomPainter {
  const _ClockPainter(this.progress, this.color, this.urgent);
  final double progress;
  final Color color;
  final bool urgent;
  @override
  void paint(Canvas c, Size s) {
    final center = s.center(Offset.zero), r = s.shortestSide / 2 - 5;
    final rect = Rect.fromCircle(center: center, radius: r);
    c.drawCircle(
      center,
      r - 8,
      Paint()..color = Palette.board.withValues(alpha: .8),
    );
    c.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2,
      false,
      Paint()
        ..color = Palette.line
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    c.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = urgent ? 4 : 3
        ..strokeCap = StrokeCap.round,
    );
    for (var i = 0; i < 24; i++) {
      final angle = i / 24 * math.pi * 2;
      final d = Offset(math.cos(angle), math.sin(angle));
      c.drawLine(
        center + d * (r - 5),
        center + d * (r - (i % 3 == 0 ? 10 : 7)),
        Paint()
          ..color = color.withValues(alpha: i / 24 <= progress ? .65 : .15)
          ..strokeWidth = 1,
      );
    }
    final a = -math.pi / 2 + progress * math.pi * 2;
    c.drawCircle(
      center + Offset(math.cos(a), math.sin(a)) * r,
      3,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_ClockPainter old) =>
      progress != old.progress || color != old.color || urgent != old.urgent;
}

class FlightMeter extends StatelessWidget {
  const FlightMeter({
    super.key,
    required this.label,
    required this.value,
    required this.fraction,
    this.accent = Palette.rust,
  });
  final String label, value;
  final double fraction;
  final Color accent;
  @override
  Widget build(BuildContext context) => Semantics(
    label: label,
    value: value,
    child: ExcludeSemantics(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 10,
                    letterSpacing: 1.2,
                    color: Palette.secondary,
                  ),
                ),
              ),
              Text(value, style: TextStyle(fontSize: 12, color: accent)),
            ],
          ),
          const SizedBox(height: 7),
          SizedBox(
            height: 5,
            child: Row(
              children: List.generate(
                16,
                (i) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 3),
                    child: ColoredBox(
                      color: i < fraction.clamp(0, 1) * 16
                          ? accent
                          : Palette.line.withValues(alpha: .5),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
