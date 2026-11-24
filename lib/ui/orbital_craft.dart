import 'package:material_ui/material_ui.dart';

/// Original spacecraft artwork, pointing toward negative Y. The narrow ceramic
/// fuselage, swept wings and inset canopy share a single directional light.
/// Callers transform a unit ship with bounds x ±.77, y -1.35… .96.
void drawOrbitalCraft(Canvas canvas, {Color accent = const Color(0xFF9ADDDC)}) {
  const bounds = Rect.fromLTWH(-.77, -1.35, 1.54, 2.31);
  final wings = Path()
    ..moveTo(-.18, -.32)
    ..lineTo(-.72, .72)
    ..lineTo(-.62, .84)
    ..lineTo(-.16, .56)
    ..lineTo(.16, .56)
    ..lineTo(.62, .84)
    ..lineTo(.72, .72)
    ..lineTo(.18, -.32)
    ..close();
  canvas.drawPath(
    wings,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFFB7C4CB), Color(0xFF50616D), Color(0xFF182635)],
      ).createShader(bounds),
  );
  canvas.drawPath(
    wings,
    Paint()
      ..color = const Color(0xFFB9CBD2).withValues(alpha: .48)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .018,
  );
  final body = Path()
    ..moveTo(0, -1.35)
    ..cubicTo(-.09, -1.10, -.22, -.42, -.22, .52)
    ..lineTo(-.15, .84)
    ..lineTo(.15, .84)
    ..lineTo(.22, .52)
    ..cubicTo(.22, -.42, .09, -1.10, 0, -1.35)
    ..close();
  canvas.drawPath(
    body,
    Paint()
      ..shader = const LinearGradient(
        colors: [
          Color(0xFF586C7A),
          Color(0xFFF0F0E7),
          Color(0xFFC5D1D5),
          Color(0xFF435561),
        ],
        stops: [0, .26, .49, 1],
      ).createShader(const Rect.fromLTWH(-.22, -1.35, .44, 2.2)),
  );
  final canopy = Path()
    ..moveTo(0, -.80)
    ..quadraticBezierTo(-.12, -.49, -.11, -.13)
    ..quadraticBezierTo(0, -.02, .11, -.13)
    ..quadraticBezierTo(.12, -.49, 0, -.80)
    ..close();
  canvas.drawPath(
    canopy,
    Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF8EAFBD), Color(0xFF294454), Color(0xFF08121E)],
        stops: [0, .25, 1],
      ).createShader(const Rect.fromLTWH(-.12, -.8, .24, .75)),
  );
  canvas.drawPath(
    Path()
      ..moveTo(-.035, -.65)
      ..quadraticBezierTo(-.08, -.4, -.065, -.21),
    Paint()
      ..color = const Color(0xFFCBE6E7).withValues(alpha: .65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = .018,
  );
  for (final side in [-1.0, 1.0]) {
    canvas.drawLine(
      Offset(side * .22, .35),
      Offset(side * .55, .70),
      Paint()
        ..color = const Color(0xFF152B3C)
        ..strokeWidth = .022,
    );
    canvas.drawLine(
      Offset(side * .38, .51),
      Offset(side * .50, .66),
      Paint()
        ..color = accent.withValues(alpha: .7)
        ..strokeWidth = .018,
    );
  }
  canvas.drawLine(
    const Offset(-.15, .57),
    const Offset(.15, .57),
    Paint()
      ..color = const Color(0xFF53616B)
      ..strokeWidth = .025,
  );
  canvas.drawRRect(
    RRect.fromRectAndRadius(
      const Rect.fromLTWH(-.13, .77, .26, .15),
      const Radius.circular(.02),
    ),
    Paint()..color = const Color(0xFF111C29),
  );
  canvas.drawLine(
    const Offset(-.09, .88),
    const Offset(.09, .88),
    Paint()
      ..color = accent
      ..strokeWidth = .025,
  );
}
