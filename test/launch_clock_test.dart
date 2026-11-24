import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/game/launch_clock.dart';
import 'package:glowpath/game/puzzle.dart';

void main() {
  test('authored lessons never exceed the thirty-second launch window', () {
    for (final pace in Difficulty.values) {
      for (var level = 1; level <= 3; level++) {
        expect(
          launchBudget(difficulty: pace, level: level, introduction: true),
          const Duration(seconds: 30),
        );
      }
    }
  });
  test(
    'legacy generated rounds use thirty seconds or the faster Bright pace',
    () {
      for (final pace in Difficulty.values) {
        for (final level in [-20, 1, 5, 6, 1000]) {
          expect(
            launchBudget(difficulty: pace, level: level).inSeconds,
            pace == Difficulty.bright ? 27 : 30,
          );
        }
      }
    },
  );

  test('clock starts paused and does not spend time before play', () {
    var now = Duration.zero;
    final clock = LaunchClock(
      now: () => now,
      total: const Duration(seconds: 60),
    );
    expect(clock.isRunning, isFalse);
    now += const Duration(days: 1);
    expect(clock.remaining, clock.total);
    expect(clock.expired, isFalse);
  });

  test('exact deadline expires, stops and cannot resume without reset', () {
    var now = Duration.zero;
    final clock = LaunchClock(
      now: () => now,
      total: const Duration(seconds: 40),
    );
    clock.resume();
    now = const Duration(microseconds: 39999999);
    expect(clock.remaining, const Duration(microseconds: 1));
    expect(clock.isRunning, isTrue);
    expect(clock.expired, isFalse);
    now += const Duration(microseconds: 1);
    expect(clock.expired, isTrue);
    expect(clock.remaining, Duration.zero);
    expect(clock.isRunning, isFalse);
    clock.resume();
    now += const Duration(days: 3);
    expect(clock.remaining, Duration.zero);
    expect(clock.isRunning, isFalse);
  });

  test('pause excludes long background intervals and resume is idempotent', () {
    var now = Duration.zero;
    final clock = LaunchClock(
      now: () => now,
      total: const Duration(seconds: 50),
    );
    clock.resume();
    now += const Duration(seconds: 7);
    clock.resume();
    expect(clock.remaining, const Duration(seconds: 43));
    clock.pause();
    now += const Duration(hours: 12);
    clock.pause();
    expect(clock.remaining, const Duration(seconds: 43));
    clock.resume();
    now += const Duration(seconds: 3);
    expect(clock.remaining, const Duration(seconds: 40));
    expect(clock.isRunning, isTrue);
    clock.pause();
    now += const Duration(days: 2);
    expect(clock.remaining, const Duration(seconds: 40));
  });

  test('reset changes total, discards old elapsed time and remains paused', () {
    var now = Duration.zero;
    final clock = LaunchClock(
      now: () => now,
      total: const Duration(seconds: 60),
    );
    clock.resume();
    now += const Duration(seconds: 25);
    clock.reset(const Duration(seconds: 20));
    now += const Duration(hours: 2);
    expect(clock.total, const Duration(seconds: 20));
    expect(clock.remaining, clock.total);
    expect(clock.isRunning, isFalse);
    clock.resume();
    now += const Duration(seconds: 21);
    expect(clock.remaining, Duration.zero);
    expect(clock.isRunning, isFalse);
    clock.reset(const Duration(seconds: 55));
    expect(clock.expired, isFalse);
    expect(clock.remaining, const Duration(seconds: 55));
  });

  test('zero and negative totals cannot create negative remaining time', () {
    final clock = LaunchClock(
      now: () => Duration.zero,
      total: const Duration(seconds: -1),
    );
    expect(clock.total, Duration.zero);
    expect(clock.remaining, Duration.zero);
    clock.resume();
    expect(clock.isRunning, isFalse);
    clock.reset(Duration.zero);
    expect(clock.expired, isTrue);
  });

  test('backward injected time never adds time', () {
    var now = const Duration(seconds: 10);
    final clock = LaunchClock(
      now: () => now,
      total: const Duration(seconds: 20),
    );
    clock.resume();
    now = const Duration(seconds: 14);
    expect(clock.remaining, const Duration(seconds: 16));
    now = const Duration(seconds: 11);
    expect(clock.remaining, const Duration(seconds: 16));
    now = const Duration(seconds: 15);
    expect(clock.remaining, const Duration(seconds: 15));
  });
}
