import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import 'design.dart';

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
class OrbitPanelFrame extends StatelessWidget {
  const OrbitPanelFrame({
    super.key,
    required this.title,
    required this.child,
    required this.onClose,
    this.fit = false,
    this.preferredDesktopHeight,
  });
  final String title;
  final Widget child;
  final VoidCallback onClose;
  final bool fit;

  /// A tighter presentation for short panels; touch and larger type keep room.
  final double? preferredDesktopHeight;

  @override
  Widget build(BuildContext context) {
    final layout = OrbitPanelLayout.fromSize(
      MediaQuery.sizeOf(context),
      preferredDesktopHeight: _desktopHeight(context, preferredDesktopHeight),
    );
    return SafeArea(
      top: layout.floating,
      child: Align(
        alignment: layout.alignment,
        child: ConstrainedBox(
          constraints: layout.constraints,
          child: OrbitSheet(
            title: title,
            fit: fit,
            floating: layout.floating,
            onClose: onClose,
            child: child,
          ),
        ),
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
}) {
  final layout = OrbitPanelLayout.fromSize(
    MediaQuery.sizeOf(context),
    preferredDesktopHeight: _desktopHeight(context, preferredDesktopHeight),
  );
  if (!layout.floating) {
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
              onClose: () => Navigator.pop(context),
              child: builder(context),
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

class _OrbitDialogRoute extends RawDialogRoute<void> {
  _OrbitDialogRoute({
    required this.motion,
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
             child: ScaleTransition(
               scale: eased.drive(Tween(begin: .975, end: 1.0)),
               child: child,
             ),
           );
         },
       ) {
    willDisposeAnimationController = false;
  }
  final AnimationController motion;
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
