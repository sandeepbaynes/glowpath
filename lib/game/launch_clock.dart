import 'puzzle.dart';
import 'voyage_progression.dart';

/// Thirty seconds at arrival; later legs tighten the deadline. Gentle pace
/// preserves the thirty-second ceiling, while Bright removes three seconds.
Duration launchBudget({
  required Difficulty difficulty,
  required int level,
  bool introduction = false,
  bool progressive = false,
}) {
  if (introduction) return const Duration(seconds: 30);
  final base = progressive
      ? VoyageProgression.forLevel(level).launchSeconds
      : 30;
  final adjustment = difficulty == Difficulty.bright ? -3 : 0;
  return Duration(seconds: (base + adjustment).clamp(18, 30));
}

/// A clock for active play only, driven by an injected monotonic time source.
///
/// No timer is created here. The UI reads [remaining] when painting and owns
/// lifecycle/modal pauses. The clock starts paused; reset also leaves it
/// paused. An expired clock can only run again after reset.
class LaunchClock {
  LaunchClock({required this.now, required Duration total})
    : _total = _nonNegative(total),
      _remaining = _nonNegative(total);

  final Duration Function() now;
  Duration _total;
  Duration _remaining;
  Duration _elapsed = Duration.zero;
  Duration? _startedAt;

  Duration get total => _total;
  Duration get elapsed {
    _reconcile();
    return _elapsed;
  }

  Duration get remaining {
    _reconcile();
    return _remaining;
  }

  bool get isRunning {
    _reconcile();
    return _startedAt != null;
  }

  bool get expired => remaining == Duration.zero;

  void reset(Duration total, {Duration elapsed = Duration.zero}) {
    _total = _nonNegative(total);
    _elapsed = _nonNegative(elapsed);
    _remaining = _nonNegative(_total - _elapsed);
    _startedAt = null;
  }

  /// Extra launch fuel changes the deadline, never the measured solving time.
  void extend(Duration extra) {
    _reconcile();
    final added = _nonNegative(extra);
    _total += added;
    _remaining += added;
  }

  void resume() {
    _reconcile();
    if (_remaining > Duration.zero && _startedAt == null) {
      _startedAt = now();
    }
  }

  void pause() {
    _reconcile();
    _startedAt = null;
  }

  void _reconcile() {
    final start = _startedAt;
    if (start == null) return;
    final current = now();
    final elapsed = current - start;
    // A misbehaving injected source must never add time. Production uses a
    // Stopwatch, which cannot move backwards when the wall clock changes.
    if (elapsed <= Duration.zero) return;
    if (elapsed >= _remaining) {
      _elapsed += _remaining;
      _remaining = Duration.zero;
      _startedAt = null;
    } else {
      _elapsed += elapsed;
      _remaining -= elapsed;
      _startedAt = current;
    }
  }

  static Duration _nonNegative(Duration value) =>
      value.isNegative ? Duration.zero : value;
}
