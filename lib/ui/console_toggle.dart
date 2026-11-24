import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'design.dart';

/// A single accessible switch row with a small illuminated instrument rail.
/// Artwork moves within a fixed touch target; text always has room to wrap.
class ConsoleToggle extends StatefulWidget {
  const ConsoleToggle({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.compact = false,
  });

  final String title, subtitle;
  final bool value;
  final bool compact;
  final ValueChanged<bool>? onChanged;

  @override
  State<ConsoleToggle> createState() => _ConsoleToggleState();
}

class _ConsoleToggleState extends State<ConsoleToggle> {
  bool _focused = false;
  bool _pressed = false;
  bool get _enabled => widget.onChanged != null;

  void _toggle() => widget.onChanged?.call(!widget.value);

  @override
  void didUpdateWidget(ConsoleToggle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_enabled) _pressed = false;
  }

  @override
  Widget build(BuildContext context) {
    final still =
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.reduceMotionOf(context);
    final large = MediaQuery.textScalerOf(context).scale(1) > 1.7;
    final shortPane = widget.compact && MediaQuery.sizeOf(context).height < 450;
    final rail = SizedBox(
      width: 54,
      height: 26,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: widget.value ? 1 : 0),
        duration: still ? Duration.zero : const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => CustomPaint(
          painter: _InstrumentRail(value: value, enabled: _enabled),
        ),
      ),
    );
    final title = Text(
      widget.title,
      style: TextStyle(
        color: _enabled ? Palette.white : Palette.secondary,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.25,
      ),
    );
    final subtitle = Text(
      widget.subtitle,
      style: const TextStyle(
        color: Palette.secondary,
        fontSize: 13,
        height: 1.4,
      ),
    );
    return Semantics(
      container: true,
      label: widget.title,
      hint: widget.subtitle,
      toggled: widget.value,
      enabled: _enabled,
      onTap: _enabled ? _toggle : null,
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
                _toggle();
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _enabled ? _toggle : null,
            onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            child: AnimatedContainer(
              duration: still
                  ? Duration.zero
                  : const Duration(milliseconds: 160),
              curve: Curves.easeOutCubic,
              constraints: const BoxConstraints(minHeight: 72, minWidth: 48),
              padding: EdgeInsets.symmetric(
                vertical: shortPane ? 6 : 14,
                horizontal: 4,
              ),
              decoration: BoxDecoration(
                color: _pressed
                    ? Palette.rust.withValues(alpha: .035)
                    : Colors.transparent,
                border: _focused
                    ? Border.all(color: Palette.rust)
                    : Border.all(color: Colors.transparent),
                borderRadius: BorderRadius.circular(12),
              ),
              child:
                  large &&
                      (!widget.compact ||
                          MediaQuery.sizeOf(context).width < 500)
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        title,
                        const SizedBox(height: 10),
                        Align(alignment: Alignment.centerLeft, child: rail),
                        if (!widget.compact) ...[
                          const SizedBox(height: 10),
                          subtitle,
                        ],
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              title,
                              if (!widget.compact) ...[
                                const SizedBox(height: 4),
                                subtitle,
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        rail,
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InstrumentRail extends CustomPainter {
  const _InstrumentRail({required this.value, required this.enabled});
  final double value;
  final bool enabled;

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final accent = enabled ? Palette.rust : Palette.secondary;
    final track = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, centerY - 10, size.width - 2, 20),
      const Radius.circular(10),
    );
    canvas.drawRRect(track, Paint()..color = Palette.paper);
    canvas.drawRRect(
      track,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .8
        ..color = Color.lerp(
          Palette.line,
          accent.withValues(alpha: .55),
          value,
        )!,
    );
    final start = const Offset(11, 13);
    final end = Offset(size.width - 11, centerY);
    canvas.drawLine(
      start,
      end,
      Paint()
        ..strokeWidth = 1
        ..color = Palette.secondary.withValues(alpha: .25),
    );
    canvas.drawLine(
      start,
      Offset.lerp(start, end, value)!,
      Paint()
        ..strokeWidth = 1.5
        ..color = accent.withValues(alpha: .65),
    );
    final marker = Offset.lerp(start, end, value)!;
    canvas.drawCircle(
      marker.translate(0, 1),
      7.2,
      Paint()..color = Colors.black26,
    );
    canvas.drawCircle(
      marker,
      7,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-.4, -.6),
          colors: [
            Color.lerp(Palette.secondary, Palette.white, value * .8)!,
            Color.lerp(Palette.tile, accent, .2 + value * .65)!,
          ],
        ).createShader(Rect.fromCircle(center: marker, radius: 7)),
    );
    canvas.drawCircle(
      marker,
      7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = .6
        ..color = Palette.white.withValues(alpha: .3),
    );
    if (value > .5) {
      canvas.drawCircle(marker, 1.5, Paint()..color = Palette.paper);
    }
  }

  @override
  bool shouldRepaint(_InstrumentRail old) =>
      value != old.value || enabled != old.enabled;
}
