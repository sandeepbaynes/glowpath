import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'design.dart';

/// A setting choice, deliberately separate from the underlined section tabs.
/// The complete card is the touch target; its drawn indicator shows selection.
class FlightPaceChoice extends StatefulWidget {
  const FlightPaceChoice({
    super.key,
    required this.label,
    required this.description,
    required this.selected,
    required this.onPressed,
    required this.reduceMotion,
  });
  final String label, description;
  final bool selected, reduceMotion;
  final VoidCallback onPressed;

  @override
  State<FlightPaceChoice> createState() => _FlightPaceChoiceState();
}

class _FlightPaceChoiceState extends State<FlightPaceChoice> {
  bool _focused = false, _pressed = false;

  @override
  Widget build(BuildContext context) {
    final still =
        widget.reduceMotion ||
        MediaQuery.disableAnimationsOf(context) ||
        MediaQuery.reduceMotionOf(context);
    return Semantics(
      container: true,
      checked: widget.selected,
      inMutuallyExclusiveGroup: true,
      label: '${widget.label}. ${widget.description}',
      onTap: widget.onPressed,
      child: ExcludeSemantics(
        child: FocusableActionDetector(
          mouseCursor: SystemMouseCursors.click,
          onShowFocusHighlight: (focused) => setState(() => _focused = focused),
          shortcuts: const {
            SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
            SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
          },
          actions: {
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (_) {
                widget.onPressed();
                return null;
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onPressed,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            child: AnimatedContainer(
              duration: still
                  ? Duration.zero
                  : const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              constraints: const BoxConstraints(minHeight: 58, minWidth: 48),
              padding: EdgeInsets.symmetric(
                horizontal: 14,
                vertical: MediaQuery.sizeOf(context).height < 450 ? 4 : 9,
              ),
              decoration: BoxDecoration(
                color: Palette.rust.withValues(
                  alpha: _pressed
                      ? .13
                      : widget.selected
                      ? .07
                      : .015,
                ),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: _focused
                      ? Palette.white
                      : widget.selected
                      ? Palette.rust.withValues(alpha: .55)
                      : Palette.line.withValues(alpha: .75),
                  width: _focused ? 1.5 : .8,
                ),
              ),
              child: Row(
                children: [
                  SizedBox.square(
                    dimension: 24,
                    child: CustomPaint(
                      painter: _PaceIndicator(widget.selected),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.label,
                          style: const TextStyle(
                            color: Palette.white,
                            fontSize: 16,
                            height: 1.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          widget.description,
                          style: const TextStyle(
                            color: Palette.secondary,
                            fontSize: 13,
                            height: 1.25,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PaceIndicator extends CustomPainter {
  const _PaceIndicator(this.selected);
  final bool selected;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    canvas.drawCircle(
      center,
      10,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = selected
            ? Palette.rust
            : Palette.secondary.withValues(alpha: .6),
    );
    if (selected) {
      canvas.drawCircle(center, 7.4, Paint()..color = Palette.rust);
      canvas.drawPath(
        Path()
          ..moveTo(center.dx - 3.6, center.dy)
          ..lineTo(center.dx - .8, center.dy + 2.8)
          ..lineTo(center.dx + 4, center.dy - 3.2),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = Palette.paper,
      );
    } else {
      canvas.drawCircle(center, 1.5, Paint()..color = Palette.line);
    }
  }

  @override
  bool shouldRepaint(_PaceIndicator old) => selected != old.selected;
}
