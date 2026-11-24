import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../game/cargo.dart';
import '../game/voyage_records.dart';
import 'cargo_art.dart';
import 'cargo_model.dart';
import 'design.dart';
import 'space_controls.dart';

/// One specimen at a time, with separate gestures for turning and browsing.
/// Discovery history remains independent of consumable power-up charges.
class CargoGallery extends StatefulWidget {
  const CargoGallery({
    super.key,
    required this.collection,
    this.powerUps = const {},
    this.coinBalance = 0,
    this.reduceMotion = false,
    this.initialKind,
  });
  final Map<CargoKind, int> collection;
  final Map<PowerUp, int> powerUps;
  final int coinBalance;
  final bool reduceMotion;
  final CargoKind? initialKind;
  @override
  State<CargoGallery> createState() => _CargoGalleryState();
}

class _CargoGalleryState extends State<CargoGallery> {
  late int _index = widget.initialKind?.index ?? 0;
  bool _details = false;
  double _drag = 0;
  int _direction = 1;
  CargoKind get _kind => CargoKind.values[_index];
  int get _found => widget.collection[_kind] ?? 0;
  int get _charges => switch (_kind.power) {
    CargoPower.time => widget.powerUps[PowerUp.timeCell] ?? 0,
    CargoPower.lens => widget.powerUps[PowerUp.routeLens] ?? 0,
    CargoPower.none => 0,
  };
  String get _inventoryLabel => _found == 0 && _charges == 0
      ? 'Undiscovered${_kind.isRare ? ' · rare' : ''}'
      : '$_found collected${_kind.power != CargoPower.none ? ' · $_charges ready' : ''}';
  bool get _still =>
      widget.reduceMotion ||
      MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.reduceMotionOf(context);
  String get _reading =>
      '${_kind.label}. ${_kind.description} '
      'Collected $_found in total. '
      '${_kind.power != CargoPower.none ? '$_charges charges ready. Used charges remain in your discovery history. ' : ''}'
      '${_kind.isRare ? 'Appears ${_kind.windowLabel} on the first salvage route of a planet. This window returns every day. ' : ''}'
      'Salvage begins on Planet 3, then appears once in each five-route leg. '
      'Cargo is optional: include it in your winning path to collect it, or take the shorter route. '
      'All three stars are still needed to finish. Cargo already on your board stays there when its time window ends.';

  void _browse(int direction) {
    final next = (_index + direction).clamp(0, CargoKind.values.length - 1);
    setState(() {
      _direction = direction;
      _drag = 0;
      _index = next;
    });
  }

  Widget _arrow({required bool next}) {
    final enabled = next ? _index + 1 < CargoKind.values.length : _index > 0;
    final label = next ? 'Next cargo' : 'Previous cargo';
    final action = enabled ? () => _browse(next ? 1 : -1) : null;
    return Semantics(
      key: ValueKey(next ? 'cargo-next' : 'cargo-previous'),
      button: true,
      enabled: enabled,
      label: label,
      onTap: action,
      child: ExcludeSemantics(
        child: ExcludeFocus(
          excluding: !enabled,
          child: IgnorePointer(
            ignoring: !enabled,
            child: Opacity(
              opacity: enabled ? 1 : .3,
              child: OrbitUtility(
                label: label,
                icon: next
                    ? Icons.chevron_right_rounded
                    : Icons.chevron_left_rounded,
                width: 56,
                reduceMotion: _still,
                onPressed: action ?? () {},
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      if (_details) {
        return SpecimenReadingView(
          key: ValueKey('cargo-reading-${_kind.name}'),
          text: _reading,
          kind: _kind,
          reduceMotion: _still,
          onBack: () => setState(() => _details = false),
        );
      }
      final enlarged = MediaQuery.textScalerOf(context).scale(1) > 1.5;
      final compact = bounds.maxHeight < 360 || enlarged;
      final discovered = widget.collection.values
          .where((count) => count > 0)
          .length;
      return GestureDetector(
        key: const ValueKey('cargo-carousel'),
        behavior: HitTestBehavior.opaque,
        onHorizontalDragStart: (_) => _drag = 0,
        onHorizontalDragUpdate: (details) =>
            setState(() => _drag += details.delta.dx),
        onHorizontalDragCancel: () => setState(() => _drag = 0),
        onHorizontalDragEnd: (details) {
          final velocity = details.primaryVelocity ?? 0;
          if (_drag.abs() > 38 || velocity.abs() > 350) {
            _browse((_drag.abs() > 38 ? _drag : velocity) < 0 ? 1 : -1);
          } else {
            setState(() => _drag = 0);
          }
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  const CoinMark(size: 20),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Semantics(
                      label: '${widget.coinBalance} earned coins',
                      child: ExcludeSemantics(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            '${widget.coinBalance} coins',
                            style: const TextStyle(
                              fontSize: 15,
                              color: Palette.light,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  OrbitUtility(
                    key: const ValueKey('cargo-details'),
                    label: 'Cargo details and discovery windows',
                    icon: Icons.info_outline_rounded,
                    width: 48,
                    reduceMotion: _still,
                    onPressed: () => setState(() => _details = true),
                  ),
                ],
              ),
            ),
            Expanded(
              child: AnimatedSlide(
                offset: Offset(
                  _still ? 0 : .05 * (_drag / (70 + _drag.abs())),
                  0,
                ),
                duration: _drag == 0 && !_still
                    ? const Duration(milliseconds: 260)
                    : Duration.zero,
                curve: Curves.easeOutCubic,
                child: AnimatedSwitcher(
                  duration: _still
                      ? Duration.zero
                      : const Duration(milliseconds: 320),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: Offset(.08 * _direction, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  layoutBuilder: (current, previous) => Stack(
                    fit: StackFit.expand,
                    children: [
                      ...previous.map(
                        (child) => IgnorePointer(
                          child: ExcludeFocus(
                            child: ExcludeSemantics(child: child),
                          ),
                        ),
                      ),
                      ?current,
                    ],
                  ),
                  child: LayoutBuilder(
                    key: ValueKey('cargo-specimen-${_kind.name}'),
                    builder: (context, area) {
                      final tight = area.maxHeight < 164;
                      final model = CargoModelView(
                        key: ValueKey('cargo-model-${_kind.name}'),
                        kind: _kind,
                        discovered: _found > 0 || _charges > 0,
                      );
                      final title = ExcludeSemantics(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            _kind.label,
                            style: bookTitle(tight ? 20 : 30),
                          ),
                        ),
                      );
                      final inventory = Semantics(
                        liveRegion: true,
                        label:
                            '${_kind.label}. $_inventoryLabel. ${_kind.windowLabel}. Optional cargo.',
                        child: ExcludeSemantics(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              _inventoryLabel,
                              style: TextStyle(
                                fontSize: tight ? 13 : 15,
                                color: Color(_kind.colorValue),
                              ),
                            ),
                          ),
                        ),
                      );
                      if (tight) {
                        return Row(
                          children: [
                            SizedBox(
                              width: math.min(
                                area.maxWidth * .3,
                                area.maxHeight * 1.3,
                              ),
                              child: model,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(height: 27, child: title),
                                  const SizedBox(height: 3),
                                  SizedBox(height: 23, child: inventory),
                                ],
                              ),
                            ),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          SizedBox(
                            height: enlarged
                                ? math.min(96, area.maxHeight * .28)
                                : compact
                                ? 36
                                : 44,
                            child: title,
                          ),
                          Expanded(child: model),
                          SizedBox(
                            height: enlarged
                                ? math.min(58, area.maxHeight * .16)
                                : 23,
                            child: inventory,
                          ),
                          if (!compact) ...[
                            const SizedBox(height: 8),
                            Text(
                              _kind.isRare
                                  ? _kind.windowLabel
                                  : _kind.description,
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.45,
                                color: Palette.secondary,
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                          if (!enlarged)
                            SizedBox(
                              height: 20,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  'Drag to turn · Swipe below to browse',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Palette.secondary.withValues(
                                      alpha: .75,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ),
            if (!compact)
              Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 4),
                child: Text(
                  '$discovered / ${CargoKind.values.length} discovered · Optional detours from Planet 3',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Palette.secondary,
                  ),
                ),
              ),
            SizedBox(
              height: 48,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _arrow(next: false),
                  Expanded(
                    child: Semantics(
                      label:
                          'Cargo ${_index + 1} of ${CargoKind.values.length}. Swipe left or right to browse.',
                      child: ExcludeSemantics(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            '${_index + 1}/6',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Palette.secondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  _arrow(next: true),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

/// Large text gets paged copy rather than a scroll view or reduced text scale.
/// Shared by cargo details and the earned-resource shelf.
class SpecimenReadingView extends StatefulWidget {
  const SpecimenReadingView({
    super.key,
    required this.text,
    required this.onBack,
    this.kind,
    this.reduceMotion = false,
  });
  final String text;
  final CargoKind? kind;
  final VoidCallback onBack;
  final bool reduceMotion;
  @override
  State<SpecimenReadingView> createState() => _SpecimenReadingViewState();
}

class _SpecimenReadingViewState extends State<SpecimenReadingView> {
  int _page = 0;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      const style = TextStyle(fontSize: 16, height: 1.25, color: Palette.white);
      final pages = <String>[];
      final words = widget.text.split(RegExp(r'\s+'));
      var line = '';
      final painter = TextPainter(
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      );
      for (final word in words) {
        final attempt = line.isEmpty ? word : '$line $word';
        painter.text = TextSpan(text: attempt, style: style);
        painter.layout(maxWidth: math.max(1, bounds.maxWidth - 16));
        if (painter.height > math.max(1, bounds.maxHeight - 60) &&
            line.isNotEmpty) {
          pages.add(line);
          line = word;
        } else {
          line = attempt;
        }
      }
      if (line.isNotEmpty) pages.add(line);
      painter.dispose();
      final selected = _page.clamp(0, pages.length - 1);
      return Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                if (widget.kind != null)
                  Positioned.fill(
                    child: Opacity(
                      opacity: .09,
                      child: Center(
                        child: CargoMark(
                          kind: widget.kind!,
                          size: math.max(
                            16,
                            math.min(
                              bounds.maxWidth * .8,
                              bounds.maxHeight - 56,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Center(
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        pages[selected],
                        key: const ValueKey('specimen-reading-body'),
                        style: style,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: Row(
              children: [
                Expanded(
                  child: SpaceAction(
                    key: const ValueKey('specimen-reading-previous'),
                    label: 'Previous',
                    icon: Icons.chevron_left_rounded,
                    compact: true,
                    quiet: true,
                    reduceMotion: widget.reduceMotion,
                    onPressed: selected > 0
                        ? () => setState(() => _page = selected - 1)
                        : null,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: SpaceAction(
                    key: const ValueKey('specimen-reading-back'),
                    label: 'Back',
                    icon: Icons.close_rounded,
                    compact: true,
                    quiet: true,
                    reduceMotion: widget.reduceMotion,
                    onPressed: widget.onBack,
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: SpaceAction(
                    key: const ValueKey('specimen-reading-next'),
                    label: 'Next',
                    icon: Icons.chevron_right_rounded,
                    compact: true,
                    quiet: true,
                    reduceMotion: widget.reduceMotion,
                    onPressed: selected + 1 < pages.length
                        ? () => setState(() => _page = selected + 1)
                        : null,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );
}
