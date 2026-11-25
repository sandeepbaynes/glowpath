import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// Account IDs are public identifiers. Requests remain off unless ENABLE_ADS is
/// set explicitly. A review build with no registered devices uses demo units.
class NativeAdConfig {
  const NativeAdConfig({
    this.enabled = const bool.fromEnvironment('ENABLE_ADS'),
    this.reviewMode = const bool.fromEnvironment('ADMOB_REVIEW_MODE'),
    this.deviceIds = const String.fromEnvironment('ADMOB_TEST_DEVICE_IDS'),
  });

  final bool enabled, reviewMode;
  final String deviceIds;
  List<String> get testDevices => deviceIds
      .split(',')
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList();
  bool get demoUnits => reviewMode && testDevices.isEmpty;

  String unit(TargetPlatform platform, String placement) {
    final ios = platform == TargetPlatform.iOS;
    if (demoUnits) {
      return 'ca-app-pub-3940256099942544/${switch (placement) {
        'banner' => ios ? '2435281174' : '9214589741',
        'interstitial' => ios ? '4411468910' : '1033173712',
        _ => ios ? '1712485313' : '5224354917',
      }}';
    }
    return 'ca-app-pub-3704137344359613/${switch (placement) {
      'banner' => ios ? '4093674041' : '6263581357',
      'interstitial' => ios ? '1248018851' : '6200962639',
      'skip' => ios ? '5079452654' : '7884298139',
      _ => ios ? '6392534329' : '1917655581',
    }}';
  }
}

/// One consent decision is shared by every ad format in a session.
class AdConsentGate {
  AdConsentGate(this.request);
  final Future<bool> Function() request;
  Future<bool>? _pending;
  bool ready = false;
  int _epoch = 0;
  Future<bool> prepare() => _pending ??= _prepare();
  Future<bool> _prepare() async {
    final epoch = _epoch;
    try {
      final allowed = await request();
      if (epoch != _epoch) return false;
      ready = allowed;
    } catch (_) {
      if (epoch != _epoch) return false;
      ready = false;
    }
    return ready;
  }

  void reset() {
    _epoch++;
    _pending = null;
    ready = false;
  }
}

class NativeAds extends ChangeNotifier {
  NativeAds({this.config = const NativeAdConfig()}) {
    _consent = AdConsentGate(() async {
      try {
        return await requestConsent();
      } catch (error) {
        _reviewLog('consent.flow.failed', {'type': error.runtimeType});
        rethrow;
      }
    });
  }
  final NativeAdConfig config;
  late final AdConsentGate _consent;
  bool _disposed = false, ready = false, presenting = false;
  bool privacyOptionsRequired = false;
  bool _loadingInterstitial = false;
  InterstitialAd? _interstitial;
  DateTime? _loadedAt, _lastLoad;
  Future<bool>? _preparing;
  int _consentEpoch = 0;
  bool _sdkInitialized = false;
  int get consentEpoch => _consentEpoch;
  bool hasCurrentConsent(int epoch) =>
      ready && !_disposed && epoch == _consentEpoch;
  void Function(String name, String placement)? onEvent;
  void Function(
    String placement,
    int micros,
    String currency,
    String precision,
  )?
  onRevenue;
  void recordRevenue(
    String placement,
    double micros,
    PrecisionType precision,
    String currency,
  ) {
    if (!micros.isFinite ||
        micros < 0 ||
        !RegExp(r"^[A-Z]{3}$").hasMatch(currency)) {
      return;
    }
    onRevenue?.call(placement, micros.round(), currency, precision.name);
  }

  bool get enabled =>
      config.enabled &&
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);
  String unit(String placement) =>
      config.unit(defaultTargetPlatform, placement);
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _event(String name, String placement) => onEvent?.call(name, placement);

  // Review console diagnostics deliberately exclude SDK messages, identifiers,
  // consent strings and response payloads. Public builds remain silent.
  void _reviewLog(String event, [Map<String, Object?> fields = const {}]) {
    if (!config.reviewMode) return;
    debugPrint(
      '[GlowpathAds] $event ${fields.entries.map((e) => '${e.key}=${e.value}').join(' ')}',
    );
  }

  Future<void> _reviewConsentState(String stage) async {
    if (!config.reviewMode) return;
    try {
      final info = ConsentInformation.instance;
      final status = await info.getConsentStatus();
      final available = await info.isConsentFormAvailable();
      final privacy = await info.getPrivacyOptionsRequirementStatus();
      final allowed = await info.canRequestAds();
      _reviewLog('consent.state', {
        'stage': stage,
        'status': status.name,
        'formAvailable': available,
        'privacyOptions': privacy.name,
        'canRequestAds': allowed,
      });
    } catch (error) {
      _reviewLog('consent.state.failed', {
        'stage': stage,
        'type': error.runtimeType,
      });
    }
  }

  Future<bool> prepare() {
    _reviewLog('prepare', {
      'enabled': enabled,
      'demoUnits': config.demoUnits,
      'registeredTestDevices': config.testDevices.length,
      'ready': ready,
      'presenting': presenting,
    });
    if (!enabled || _disposed || (presenting && _preparing == null)) {
      return Future.value(false);
    }
    return _preparing ??= _prepare(_consentEpoch);
  }

  Future<bool> _prepare(int epoch) async {
    presenting = true;
    _notify();
    try {
      final allowed = ready ? await canRequestAds() : await _consent.prepare();
      if (epoch != _consentEpoch || _disposed) return false;
      if (!allowed || !await canRequestAds()) {
        _reviewLog('prepare.blocked', {'reason': 'consent'});
        _invalidateConsent();
        return false;
      }
      if (!_sdkInitialized) {
        await initializeSdk();
        _sdkInitialized = true;
      }
      if (_disposed || epoch != _consentEpoch) return false;
      ready = true;
      _reviewLog('prepare.ready');
      unawaited(preloadInterstitial());
      return ready;
    } catch (error) {
      _reviewLog('prepare.failed', {'type': error.runtimeType});
      if (epoch == _consentEpoch) _invalidateConsent();
      return false;
    } finally {
      _preparing = null;
      presenting = false;
      _notify();
    }
  }

  void _invalidateConsent() {
    _consentEpoch++;
    ready = false;
    _preparing = null;
    _consent.reset();
    _loadingInterstitial = false;
    _interstitial?.dispose();
    _interstitial = null;
    _loadedAt = null;
    _lastLoad = null;
  }

  @protected
  Future<bool> canRequestAds() => ConsentInformation.instance.canRequestAds();

  @protected
  Future<bool> requiresPrivacyOptions() async =>
      await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
      PrivacyOptionsRequirementStatus.required;

  @protected
  Future<void> initializeSdk() async {
    _reviewLog('sdk.initialize.start');
    await MobileAds.instance.updateRequestConfiguration(
      RequestConfiguration(
        testDeviceIds: config.testDevices,
        maxAdContentRating: MaxAdContentRating.g,
      ),
    );
    await MobileAds.instance.initialize();
    _reviewLog('sdk.initialize.done');
  }

  @protected
  Future<void> showPrivacyForm() async {
    final done = Completer<void>();
    _reviewLog('privacy.form.start');
    await ConsentForm.showPrivacyOptionsForm((error) {
      _reviewLog('privacy.form.dismissed', {'errorCode': error?.errorCode});
      if (!done.isCompleted) done.complete();
    });
    await done.future;
  }

  @protected
  Future<bool> requestConsent() async {
    _reviewLog('consent.update.start');
    unawaited(_reviewConsentState('before-update'));
    final updated = Completer<bool>();
    var timedOut = false;
    final watch = Stopwatch()..start();
    ConsentInformation.instance.requestConsentInfoUpdate(
      ConsentRequestParameters(),
      () {
        _reviewLog('consent.update.success', {
          'elapsedMs': watch.elapsedMilliseconds,
          'late': timedOut,
        });
        if (timedOut) unawaited(_reviewConsentState('late-update'));
        if (!updated.isCompleted) updated.complete(true);
      },
      (error) {
        _reviewLog('consent.update.failed', {
          'errorCode': error.errorCode,
          'elapsedMs': watch.elapsedMilliseconds,
          'late': timedOut,
        });
        if (!updated.isCompleted) updated.complete(false);
      },
    );
    final gotUpdate = await updated.future.timeout(
      const Duration(seconds: 15),
      onTimeout: () {
        timedOut = true;
        _reviewLog('consent.update.timeout');
        return false;
      },
    );
    unawaited(_reviewConsentState('after-update'));
    if (gotUpdate) {
      final dismissed = Completer<void>();
      _reviewLog('consent.form.start');
      await ConsentForm.loadAndShowConsentFormIfRequired((error) {
        _reviewLog('consent.form.dismissed', {'errorCode': error?.errorCode});
        if (!dismissed.isCompleted) dismissed.complete();
      });
      // The player's consent form is never treated as answered by a timeout.
      await dismissed.future;
      unawaited(_reviewConsentState('after-form'));
    }
    privacyOptionsRequired = await requiresPrivacyOptions();
    final allowed = await canRequestAds();
    _reviewLog('consent.result', {
      'canRequestAds': allowed,
      'privacyOptionsRequired': privacyOptionsRequired,
    });
    return allowed;
  }

  Future<void> privacyOptions() async {
    if (!enabled || _disposed || presenting) return;
    presenting = true;
    _invalidateConsent();
    _notify();
    try {
      await showPrivacyForm();
      final allowed = await canRequestAds();
      privacyOptionsRequired = await requiresPrivacyOptions();
      if (_disposed) return;
      ready = allowed && _sdkInitialized;
      if (ready) unawaited(preloadInterstitial());
    } catch (_) {
      // An unavailable form never grants permission to request ads.
    } finally {
      presenting = false;
      _notify();
    }
  }

  Future<void> preloadInterstitial() async {
    if (!ready || _disposed || _loadingInterstitial || _interstitial != null) {
      return;
    }
    final now = DateTime.now();
    if (_lastLoad != null &&
        now.difference(_lastLoad!) < const Duration(minutes: 1)) {
      return;
    }
    final epoch = _consentEpoch;
    _loadingInterstitial = true;
    _lastLoad = now;
    _event('ad_request', 'voyage_result');
    _reviewLog('interstitial.load.start');
    try {
      await InterstitialAd.load(
        adUnitId: unit('interstitial'),
        request: const AdRequest(nonPersonalizedAds: true),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _reviewLog('interstitial.load.success', {
              'currentConsent': hasCurrentConsent(epoch),
            });
            if (epoch == _consentEpoch) _loadingInterstitial = false;
            if (!hasCurrentConsent(epoch)) {
              ad.dispose();
              return;
            }
            ad.onPaidEvent = (_, micros, precision, currency) =>
                recordRevenue('voyage_result', micros, precision, currency);
            _interstitial = ad;
            _loadedAt = DateTime.now();
          },
          onAdFailedToLoad: (error) {
            _reviewLog('interstitial.load.failed', {'errorCode': error.code});
            if (epoch == _consentEpoch) _loadingInterstitial = false;
          },
        ),
      );
    } catch (error) {
      _reviewLog('interstitial.load.exception', {'type': error.runtimeType});
      if (epoch == _consentEpoch) _loadingInterstitial = false;
    }
  }

  /// Never waits for a network load at a level boundary. A missing ad yields
  /// immediately; only an actual show callback consumes the pacing allowance.
  Future<bool> showLevelBreak({required VoidCallback onImpression}) async {
    if (!ready || presenting || _disposed) return false;
    final ad = _interstitial;
    _interstitial = null;
    if (ad == null ||
        _loadedAt == null ||
        DateTime.now().difference(_loadedAt!) > const Duration(minutes: 50)) {
      ad?.dispose();
      _event('ad_no_fill', 'voyage_result');
      unawaited(preloadInterstitial());
      return false;
    }
    final closed = Completer<bool>();
    var shown = false;
    presenting = true;
    _notify();
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (_) {
        shown = true;
        onImpression();
        _event('ad_impression', 'voyage_result');
      },
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _event('ad_closed', 'voyage_result');
        if (!closed.isCompleted) closed.complete(shown);
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _event('ad_no_fill', 'voyage_result');
        if (!closed.isCompleted) closed.complete(false);
      },
    );
    try {
      await ad.show();
      return await closed.future;
    } catch (_) {
      ad.dispose();
      return false;
    } finally {
      presenting = false;
      _lastLoad = null;
      _notify();
      unawaited(preloadInterstitial());
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _interstitial?.dispose();
    super.dispose();
  }
}
