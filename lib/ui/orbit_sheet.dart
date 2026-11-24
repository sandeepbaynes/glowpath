import 'dart:math' as math;
import 'dart:ui' show DisplayFeatureType;

import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

import '../services/fold_posture.dart';
import 'design.dart';
import 'fold_layout.dart';

/// Shared geometry for the live route and visual review fixtures.
class OrbitPanelLayout {
  OrbitPanelLayout.fromSize(Size size, {double? preferredDesktopHeight})
    : floating = size.shortestSide >= 600,
      maxWidth = math.min(
        600,
        math.max(0, size.width - (size.shortestSide >= 600 ? 64 : 0)),
      ),
      maxHeight = size.shortestSide >= 600
          ? math.min(
              preferredDesktopHeight ?? 780,
              math.max(0, size.height - 64),
            )
          : math.min(820, size.height * .92);

  final bool floating;
  final double maxWidth, maxHeight;
  Alignment get alignment =>
      floating ? Alignment.center : Alignment.bottomCenter;
  BoxConstraints get constraints =>
      BoxConstraints(maxWidth: maxWidth, maxHeight: maxHeight);
}

/// Full viewport presentation used by centered dialogs and review captures.
class OrbitPanelFrame extends StatefulWidget {
  const OrbitPanelFrame({
    super.key,
    required this.title,
    required this.child,
    required this.onClose,
    this.fit = false,
    this.preferredDesktopHeight,
    this.foldGeometry,
    this.foldCompanionBuilder,
    this.legacyPhoneBottomSheet = false,
    this.transitionController,
  });
  final String title;
  final Widget child;
  final VoidCallback onClose;
  final bool fit;

  /// A tighter presentation for short panels; touch and larger type keep room.
  final double? preferredDesktopHeight;

  final ValueListenable<FoldGeometry>? foldGeometry;
  final WidgetBuilder? foldCompanionBuilder;

  /// Full-viewport routes retain the familiar bottom-sheet interaction on a
  /// phone while remaining able to move into a pane after the route is open.
  final bool legacyPhoneBottomSheet;
  final AnimationController? transitionController;

  @override
  State<OrbitPanelFrame> createState() => _OrbitPanelFrameState();
}

class _OrbitPanelFrameState extends State<OrbitPanelFrame> {
  final _contentKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final geometry = widget.foldGeometry;
    if (geometry == null) return _frame(context, const FoldGeometry());
    return ValueListenableBuilder<FoldGeometry>(
      valueListenable: geometry,
      builder: (context, value, _) => _frame(context, value),
    );
  }

  Widget _frame(BuildContext context, FoldGeometry geometry) {
    final media = MediaQuery.of(context);
    final panes = FoldPaneLayout.resolve(media, geometry);
    final content = KeyedSubtree(key: _contentKey, child: widget.child);
    if (panes != null) {
      final reduced =
          media.disableAnimations ||
          media.reduceMotion ||
          widget.transitionController?.duration == Duration.zero;
      return Stack(
        fit: StackFit.expand,
        children: [
          if (widget.foldCompanionBuilder != null)
            Positioned.fromRect(
              rect: panes.missionRect,
              child: ClipRect(
                key: const ValueKey('fold-panel-companion'),
                child: MediaQuery(
                  data: FoldPaneLayout.paneMediaQuery(media, panes.missionRect),
                  child: Builder(builder: widget.foldCompanionBuilder!),
                ),
              ),
            ),
          Positioned.fromRect(
            rect: panes.gap,
            child: const IgnorePointer(
              child: SizedBox(key: ValueKey('fold-panel-gap')),
            ),
          ),
          Positioned.fromRect(
            rect: panes.actionRect,
            child: ClipRect(
              key: const ValueKey('fold-panel-action'),
              child: MediaQuery(
                data: FoldPaneLayout.paneMediaQuery(media, panes.actionRect),
                child: TweenAnimationBuilder<double>(
                  key: ValueKey(panes.axis),
                  tween: Tween(begin: 0, end: 1),
                  duration: reduced
                      ? Duration.zero
                      : const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  child: Align(
                    alignment: Alignment.center,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: math.min(600, panes.actionRect.width),
                        maxHeight: math.min(820, panes.actionRect.height),
                      ),
                      child: OrbitSheet(
                        title: widget.title,
                        fit: widget.fit,
                        floating: true,
                        onClose: widget.onClose,
                        child: content,
                      ),
                    ),
                  ),
                  builder: (context, value, child) => Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: panes.horizontal
                          ? Offset(0, 10 * (1 - value))
                          : Offset(10 * (1 - value), 0),
                      child: child,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }
    final layout = OrbitPanelLayout.fromSize(
      media.size,
      preferredDesktopHeight: _desktopHeight(
        context,
        widget.preferredDesktopHeight,
      ),
    );
    Widget sheet = OrbitSheet(
      title: widget.title,
      fit: widget.fit,
      floating: layout.floating,
      onClose: widget.onClose,
      child: content,
    );
    if (!layout.floating && widget.legacyPhoneBottomSheet) {
      final surface = sheet;
      sheet = BottomSheet(
        onClosing: widget.onClose,
        animationController: widget.transitionController,
        enableDrag: widget.transitionController != null,
        backgroundColor: Colors.transparent,
        showDragHandle: false,
        builder: (_) => surface,
      );
    }
    return SafeArea(
      top: layout.floating,
      child: Align(
        alignment: layout.alignment,
        child: ConstrainedBox(constraints: layout.constraints, child: sheet),
      ),
    );
  }
}

/// Keeps phone sheets familiar while making larger screens proper dialogs.
/// The caller owns [motion], including reduced-motion changes and disposal.
Future<void> showOrbitPanel({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
  required AnimationController motion,
  bool fit = false,
  double? preferredDesktopHeight,
  ValueListenable<FoldGeometry>? foldGeometry,
  WidgetBuilder? foldCompanionBuilder,
}) {
  final foldAware =
      foldGeometry != null ||
      MediaQuery.of(context).displayFeatures.any(
        (feature) =>
            feature.type == DisplayFeatureType.fold ||
            feature.type == DisplayFeatureType.hinge,
      );
  final layout = OrbitPanelLayout.fromSize(
    MediaQuery.sizeOf(context),
    preferredDesktopHeight: _desktopHeight(context, preferredDesktopHeight),
  );
  if (!layout.floating && !foldAware) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      transitionAnimationController: motion,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Palette.paper.withValues(alpha: .78),
      showDragHandle: false,
      constraints: layout.constraints,
      builder: (context) => SafeArea(
        top: false,
        child: OrbitSheet(
          title: title,
          fit: fit,
          onClose: () => Navigator.pop(context),
          child: builder(context),
        ),
      ),
    );
  }
  final navigator = Navigator.of(context);
  final themes = InheritedTheme.capture(from: context, to: navigator.context);
  return navigator.push<void>(
    _OrbitDialogRoute(
      motion: motion,
      foldAware: foldAware,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      pageBuilder: (context, animation, secondaryAnimation) => themes.wrap(
        Material(
          type: MaterialType.transparency,
          child: Semantics(
            namesRoute: true,
            label: title,
            child: OrbitPanelFrame(
              title: title,
              fit: fit,
              preferredDesktopHeight: preferredDesktopHeight,
              foldGeometry: foldGeometry,
              foldCompanionBuilder: foldCompanionBuilder,
              legacyPhoneBottomSheet: foldAware,
              transitionController: motion,
              onClose: () => Navigator.pop(context),
              child: Builder(builder: builder),
            ),
          ),
        ),
      ),
    ),
  );
}

double? _desktopHeight(BuildContext context, double? preferred) {
  if (MediaQuery.textScalerOf(context).scale(1) >= 1.3) return null;
  return switch (Theme.of(context).platform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux => preferred,
    _ => null,
  };
}

/// A modal route whose content owns both sides of a folding display.
/// Flutter's default dialog route selects a single display sub-screen before
/// building its page; fold-aware pages need the original viewport instead.
class FoldDialogRoute<T> extends RawDialogRoute<T> {
  FoldDialogRoute({
    required super.pageBuilder,
    super.barrierDismissible,
    super.barrierLabel,
    super.barrierColor,
    super.transitionDuration,
    super.transitionBuilder,
    super.barrierBuilder,
    super.settings,
    super.requestFocus,
    super.traversalEdgeBehavior,
    super.directionalTraversalEdgeBehavior,
    super.fullscreenDialog,
  }) : _fullViewportPageBuilder = pageBuilder;

  final RoutePageBuilder _fullViewportPageBuilder;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => Semantics(
    scopesRoute: true,
    explicitChildNodes: true,
    child: _fullViewportPageBuilder(context, animation, secondaryAnimation),
  );
}

class _OrbitDialogRoute extends FoldDialogRoute<void> {
  _OrbitDialogRoute({
    required this.motion,
    this.foldAware = false,
    required super.pageBuilder,
    required super.barrierLabel,
  }) : super(
         barrierDismissible: true,
         barrierColor: Palette.paper.withValues(alpha: .78),
         requestFocus: true,
         traversalEdgeBehavior: TraversalEdgeBehavior.closedLoop,
         transitionDuration: motion.duration ?? Duration.zero,
         transitionBuilder: (context, animation, secondaryAnimation, child) {
           if (motion.duration == Duration.zero ||
               MediaQuery.disableAnimationsOf(context) ||
               MediaQuery.reduceMotionOf(context)) {
             return child;
           }
           final eased = animation.drive(
             CurveTween(curve: Curves.easeOutCubic),
           );
           return FadeTransition(
             opacity: eased,
             child: foldAware
                 ? child
                 : ScaleTransition(
                     scale: eased.drive(Tween(begin: .975, end: 1.0)),
                     child: child,
                   ),
           );
         },
       ) {
    willDisposeAnimationController = false;
  }
  final AnimationController motion;
  final bool foldAware;
  @override
  AnimationController createAnimationController() => motion;
}

/// Shared surface for reference, collection and controls: one quiet frame.
class OrbitSheet extends StatelessWidget {
  const OrbitSheet({
    super.key,
    required this.title,
    required this.child,
    required this.onClose,
    this.fit = false,
    this.floating = false,
  });
  final String title;
  final Widget child;
  final VoidCallback onClose;
  final bool fit, floating;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: floating
          ? BorderRadius.circular(30)
          : const BorderRadius.vertical(top: Radius.circular(30)),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF142330), Palette.board, Palette.paper],
        stops: [0, .32, 1],
      ),
      border: Border.all(
        color: Palette.secondary.withValues(alpha: .18),
        width: .8,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .32),
          blurRadius: 40,
          offset: floating ? const Offset(0, 8) : const Offset(0, -12),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: fit ? MainAxisSize.max : MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 10, 12, 6),
          child: Row(
            children: [
              Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(
                  color: Palette.rust,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 1.8,
                    color: Palette.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('close-sheet'),
                tooltip: 'Close',
                onPressed: onClose,
                icon: const Icon(
                  Icons.close_rounded,
                  size: 20,
                  color: Palette.white,
                ),
              ),
            ],
          ),
        ),
        Flexible(
          child: fit
              ? Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                  child: child,
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                  child: child,
                ),
        ),
      ],
    ),
  );
}
