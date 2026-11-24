import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/services/ad_pacing.dart';

void main() {
  test('first three clears are ad free and a genuine impression resets pacing', () {
    final pacing = AdPacing();
    for (var i = 1; i <= 3; i++) {
      pacing.recordPlay(const Duration(seconds: 40));
      expect(
        pacing.completeLevel(
          now: Duration(seconds: i * 40),
          engaged: true,
          assisted: false,
          challenge: false,
        ),
        isFalse,
      );
    }
    pacing.recordPlay(const Duration(minutes: 2));
    expect(
      pacing.completeLevel(
        now: const Duration(minutes: 5),
        engaged: true,
        assisted: false,
        challenge: false,
      ),
      isTrue,
    );
    pacing.recordImpression(const Duration(minutes: 5));
    expect(
      pacing.completeLevel(
        now: const Duration(minutes: 6),
        engaged: true,
        assisted: false,
        challenge: false,
      ),
      isFalse,
    );
  });

  test('an unfilled offer does not reset allowance; challenges and assistance are excluded', () {
    final pacing = AdPacing(firstFreeCompletions: 0);
    pacing.recordPlay(const Duration(minutes: 3));
    expect(
      pacing.completeLevel(
        now: const Duration(minutes: 3),
        engaged: false,
        assisted: false,
        challenge: false,
      ),
      isFalse,
    );
    expect(
      pacing.completeLevel(
        now: const Duration(minutes: 4),
        engaged: true,
        assisted: true,
        challenge: false,
      ),
      isFalse,
    );
    expect(
      pacing.completeLevel(
        now: const Duration(minutes: 5),
        engaged: true,
        assisted: false,
        challenge: true,
      ),
      isFalse,
    );
    expect(
      pacing.completeLevel(
        now: const Duration(minutes: 6),
        engaged: true,
        assisted: false,
        challenge: false,
      ),
      isTrue,
    );
    expect(
      pacing.completeLevel(
        now: const Duration(minutes: 7),
        engaged: true,
        assisted: false,
        challenge: false,
      ),
      isTrue,
    );
  });
}
