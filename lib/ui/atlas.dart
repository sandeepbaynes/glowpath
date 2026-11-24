import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'design.dart';

const atlasNames = [
  'Little Dipper',
  'Wandering Kite',
  'Quiet Crown',
  'Northbound',
];
const _charts = <List<Offset>>[
  [
    Offset(.13, .75),
    Offset(.26, .6),
    Offset(.43, .57),
    Offset(.54, .4),
    Offset(.76, .28),
    Offset(.86, .48),
    Offset(.65, .6),
  ],
  [
    Offset(.2, .8),
    Offset(.42, .62),
    Offset(.3, .35),
    Offset(.58, .16),
    Offset(.8, .4),
    Offset(.42, .62),
  ],
  [
    Offset(.14, .65),
    Offset(.22, .3),
    Offset(.43, .5),
    Offset(.56, .22),
    Offset(.72, .5),
    Offset(.86, .33),
    Offset(.8, .7),
  ],
  [
    Offset(.5, .13),
    Offset(.5, .86),
    Offset(.5, .5),
    Offset(.17, .5),
    Offset(.83, .5),
    Offset(.5, .5),
    Offset(.3, .7),
    Offset(.7, .3),
  ],
];

class Constellation extends StatelessWidget {
  const Constellation({
    super.key,
    required this.index,
    this.progress = 1,
    this.dark = false,
  });
  final int index;
  final double progress;
  final bool dark;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: CustomPaint(
      painter: _ChartPainter(index, progress, dark),
      size: const Size(100, 90),
    ),
  );
}

class _ChartPainter extends CustomPainter {
  const _ChartPainter(this.index, this.progress, this.dark);
  final int index;
  final double progress;
  final bool dark;
  @override
  void paint(Canvas canvas, Size size) {
    final points = _charts[index.clamp(0, 3)]
        .map((p) => Offset(p.dx * size.width, p.dy * size.height))
        .toList();
    final color = dark ? Palette.light : Palette.ink;
    final line = Paint()
      ..color = color.withValues(alpha: .25)
      ..strokeWidth = 1.2;
    for (var i = 1; i < points.length; i++) {
      canvas.drawLine(points[i - 1], points[i], line);
    }
    if (index == 0) canvas.drawLine(points.last, points[3], line);
    final lit = (points.length * progress.clamp(0, 1)).ceil();
    for (var i = 0; i < points.length; i++) {
      final point = points[i];
      final active = i < lit;
      if (active) {
        canvas.drawCircle(
          point,
          7,
          Paint()..color = color.withValues(alpha: .09),
        );
      }
      canvas.drawCircle(
        point,
        active ? 2.8 : 2,
        Paint()..color = active ? color : color.withValues(alpha: .3),
      );
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      index != old.index || progress != old.progress || dark != old.dark;
}

class AtlasPreview extends StatelessWidget {
  const AtlasPreview({super.key, required this.stars, required this.onTap});
  final int stars;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final index = math.min(stars ~/ 15, 3);
    final current = math.min(15, stars - index * 15);
    return Semantics(
      button: true,
      label: 'Open your star atlas. $stars stars earned.',
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            key: const ValueKey('open-atlas'),
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 64,
                    height: 55,
                    child: Constellation(index: index, progress: current / 15),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          stars >= 60
                              ? 'Your atlas is complete'
                              : atlasNames[index],
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          stars >= 60
                              ? 'Four constellations, all yours'
                              : '$current / 15 stars · Your atlas',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Palette.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 22),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AtlasSheet extends StatelessWidget {
  const AtlasSheet({super.key, required this.stars});
  final int stars;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text('A sky of your own.', style: bookTitle(30)),
      const SizedBox(height: 10),
      const Text(
        'Every solved path adds three stars. Fifteen stars finish a constellation.',
      ),
      const SizedBox(height: 24),
      for (var i = 0; i < atlasNames.length; i++) ...[
        Semantics(
          label:
              '${atlasNames[i]}, ${stars >= (i + 1) * 15 ? 'complete' : '${(stars - i * 15).clamp(0, 15)} of 15 stars'}',
          child: ExcludeSemantics(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  SizedBox(
                    width: 82,
                    height: 72,
                    child: Constellation(
                      index: i,
                      progress: ((stars - i * 15) / 15).clamp(0, 1),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(atlasNames[i], style: bookTitle(21)),
                        const SizedBox(height: 6),
                        Text(
                          stars >= (i + 1) * 15
                              ? 'Complete'
                              : '${(stars - i * 15).clamp(0, 15)} / 15 stars',
                          style: const TextStyle(color: Palette.secondary),
                        ),
                      ],
                    ),
                  ),
                  if (stars >= (i + 1) * 15)
                    const Icon(Icons.check_circle_outline_rounded),
                ],
              ),
            ),
          ),
        ),
        if (i < 3) const Divider(),
      ],
    ],
  );
}
