import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/services/native_ads.dart';

void main() {
  test('owner review cannot request production units before test device registration', () {
    const unknownDevice = NativeAdConfig(enabled: true, reviewMode: true);
    for (final platform in [TargetPlatform.iOS, TargetPlatform.android]) {
      for (final placement in ['banner', 'interstitial', 'hint', 'skip']) {
        expect(
          unknownDevice.unit(platform, placement),
          startsWith('ca-app-pub-3940256099942544/'),
        );
      }
    }
    const registered = NativeAdConfig(
      enabled: true,
      reviewMode: true,
      deviceIds: 'device-1, device-2,device-1, ',
    );
    expect(registered.testDevices, ['device-1', 'device-2']);
    expect(registered.demoUnits, isFalse);
    expect(
      registered.unit(TargetPlatform.iOS, 'hint'),
      isNot(registered.unit(TargetPlatform.iOS, 'skip')),
    );
    expect(
      registered.unit(TargetPlatform.android, 'banner'),
      startsWith('ca-app-pub-3704137344359613/'),
    );
  });

  test('parallel ad formats await one consent request and cannot grant consent early', () async {
    var calls = 0;
    final response = Completer<bool>();
    final gate = AdConsentGate(() {
      calls++;
      return response.future;
    });
    final banner = gate.prepare();
    final rewarded = gate.prepare();
    expect(calls, 1);
    expect(gate.ready, isFalse);
    response.complete(false);
    expect(await banner, isFalse);
    expect(await rewarded, isFalse);
    expect(gate.ready, isFalse);
  });

  test(
    'consent errors fail closed and an explicit retry can recover',
    () async {
      var calls = 0;
      final gate = AdConsentGate(() async {
        if (++calls == 1) throw StateError('network unavailable');
        return true;
      });
      expect(await gate.prepare(), isFalse);
      gate.reset();
      expect(await gate.prepare(), isTrue);
      expect(calls, 2);
    },
  );

  test('disabled ads return without initializing a native plugin', () async {
    final ads = NativeAds(config: const NativeAdConfig(enabled: false));
    addTearDown(ads.dispose);
    expect(await ads.prepare(), isFalse);
    expect(ads.ready, isFalse);
    expect(ads.presenting, isFalse);
    var impressions = 0;
    expect(
      await ads.showLevelBreak(onImpression: () => impressions++),
      isFalse,
    );
    expect(impressions, 0);
  });
  test(
    'revoking privacy invalidates prepare and all pre-change ad loads',
    () async {
      final ads = _ConsentAds();
      addTearDown(ads.dispose);
      expect(await ads.prepare(), isTrue);
      final loadEpoch = ads.consentEpoch;
      expect(ads.hasCurrentConsent(loadEpoch), isTrue);
      ads.nextChoice = false;
      await ads.privacyOptions();
      expect(ads.ready, isFalse);
      expect(ads.hasCurrentConsent(loadEpoch), isFalse);
      expect(await ads.prepare(), isFalse);
      expect(ads.ready, isFalse);
      expect(ads.sdkInitializations, 1);

      // A later grant must not authorize an old in-flight ad callback.
      ads.allowed = true;
      expect(await ads.prepare(), isTrue);
      expect(ads.hasCurrentConsent(loadEpoch), isFalse);
      expect(ads.hasCurrentConsent(ads.consentEpoch), isTrue);
      expect(ads.sdkInitializations, 1);
    },
  );

  test(
    'prepare rechecks current SDK consent instead of caching success',
    () async {
      final ads = _ConsentAds();
      addTearDown(ads.dispose);
      expect(await ads.prepare(), isTrue);
      ads.allowed = false;
      expect(await ads.prepare(), isFalse);
      expect(ads.ready, isFalse);
    },
  );

  test(
    'reset prevents a stale consent response from restoring readiness',
    () async {
      final responses = [Completer<bool>(), Completer<bool>()];
      var calls = 0;
      final gate = AdConsentGate(() => responses[calls++].future);
      final old = gate.prepare();
      gate.reset();
      final current = gate.prepare();
      responses[1].complete(false);
      expect(await current, isFalse);
      responses[0].complete(true);
      expect(await old, isFalse);
      expect(gate.ready, isFalse);
    },
  );
}

class _ConsentAds extends NativeAds {
  _ConsentAds() : super(config: const NativeAdConfig(enabled: true));
  bool allowed = true;
  bool nextChoice = false;
  int sdkInitializations = 0;
  @override
  bool get enabled => true;
  @override
  Future<bool> requestConsent() async => allowed;
  @override
  Future<bool> canRequestAds() async => allowed;
  @override
  Future<bool> requiresPrivacyOptions() async => true;
  @override
  Future<void> initializeSdk() async {
    sdkInitializations++;
  }

  @override
  Future<void> showPrivacyForm() async {
    allowed = nextChoice;
  }

  @override
  Future<void> preloadInterstitial() async {}
}
