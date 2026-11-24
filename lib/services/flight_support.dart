import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/store_kit_2_wrappers.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'native_ads.dart';

/// All shipped clients remain free. Payments are paused by product policy;
/// build flags cannot enable them. The explicit constructor override preserves
/// isolated adapter tests. MOCK_SERVICES rewards use separate local demo data.
class FlightSupport extends ChangeNotifier {
  FlightSupport({
    bool? ads,
    bool? purchases,
    bool? mock,
    SharedPreferences? preferences,
    Future<bool> Function()? entitlementReader,
    NativeAds? adService,
  }) : this._(
         ads ?? adsEnabled,
         purchases ?? purchasesEnabled,
         mock ?? mockServices,
         preferences,
         entitlementReader,
         adService,
       );

  FlightSupport._(
    this._adsEnabled,
    this._purchasesEnabled,
    this.isMock,
    this._preferences,
    this._entitlementReader,
    NativeAds? adService,
  ) : _ads =
          adService ?? NativeAds(config: NativeAdConfig(enabled: _adsEnabled)),
      _ownsAds = adService == null;

  final NativeAds _ads;
  final bool _ownsAds;

  final bool _adsEnabled, _purchasesEnabled;
  final bool isMock;
  static const mockServices = bool.fromEnvironment('MOCK_SERVICES');
  SharedPreferences? _preferences;
  final Future<bool> Function()? _entitlementReader;
  static const creditStorageKey = 'glowpath.support.credits.v1';
  static const mockCreditStorageKey = 'glowpath.mock.support.v1';
  String get _storageKey => isMock ? mockCreditStorageKey : creditStorageKey;
  Future<void>? _creditLoading;
  Future<void> _creditWrites = Future<void>.value();
  Future<void> _purchaseQueue = Future<void>.value();
  bool _creditsReady = false;
  bool _storeInitialized = false;
  int _entitlementEpoch = 0;
  static const adsEnabled = bool.fromEnvironment('ENABLE_ADS');
  static const purchasesEnabled = false;
  static const productId = 'app.glowpath.remove_ads';
  bool _disposed = false, busy = false, adFree = false;
  String? message;
  ProductDetails? product;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  int _hintCredits = 3, _skipCredits = 1;
  bool get reviewMode => !isMock && !_adsEnabled && !_purchasesEnabled;
  bool get native =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);
  bool get canBuy =>
      _purchasesEnabled && !busy && (isMock ? !adFree : product != null);
  String get price =>
      isMock ? 'Preview' : product?.price ?? 'Not available yet';
  int get hintCredits => _hintCredits;
  int get skipCredits => _skipCredits;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> initialize() async {
    await (_creditLoading ??= _loadCredits());
    if (_disposed || isMock || !native || !_purchasesEnabled) return;
    // Initial iOS product only. Android receipt validation is required before
    // enabling its store; a successful Android callback alone grants nothing.
    if (defaultTargetPlatform != TargetPlatform.iOS || _storeInitialized) {
      return;
    }
    _storeInitialized = true;
    final store = InAppPurchase.instance;
    _purchaseSubscription = store.purchaseStream.listen(
      (values) {
        _purchaseQueue = _purchaseQueue
            .then((_) => _purchases(values))
            .catchError((Object _) {
              busy = false;
              message = 'The store could not finish checking this purchase. Try Restore purchases.';
              _notify();
            });
      },
      onError: (_) {
        message = 'The store is unavailable. Please try again.';
        busy = false;
        _notify();
      },
    );
    try {
      if (await store.isAvailable()) {
        await refreshEntitlements();
        final answer = await store.queryProductDetails({productId});
        if (answer.productDetails.isNotEmpty) {
          product = answer.productDetails.first;
        }
      }
    } catch (_) {
      message = 'The store is unavailable. Please try again.';
    }
    _notify();
  }

  Future<void> _purchases(List<PurchaseDetails> values) async {
    for (final value in values) {
      if (value.productID != productId) continue;
      if (value.status == PurchaseStatus.pending) {
        busy = true;
        message = 'Waiting for the App Store…';
        _notify();
        continue;
      }
      if (value.status == PurchaseStatus.purchased ||
          value.status == PurchaseStatus.restored) {
        // Signed updates can also announce a revoked purchase. Only the
        // current verified entitlement list decides access, never event status.
        if (defaultTargetPlatform == TargetPlatform.iOS &&
            value.verificationData.serverVerificationData.isNotEmpty) {
          final checked = await refreshEntitlements();
          if (!checked) {
            message = 'The App Store could not check this purchase yet. Please try Restore purchases.';
            busy = false;
            _notify();
            continue;
          }
          message = adFree
              ? 'Ad-free flight unlocked. Hints and skips are included.'
              : 'The App Store reports no active ad-free purchase.';
        } else {
          message = 'Purchase verification is unavailable. No entitlement was changed.';
        }
      } else if (value.status == PurchaseStatus.error) {
        message =
            'Purchase could not be completed. You have not lost any progress.';
      } else if (value.status == PurchaseStatus.canceled) {
        message = null;
      }
      if (value.pendingCompletePurchase) {
        await InAppPurchase.instance.completePurchase(value);
      }
      busy = false;
      _notify();
    }
  }

  /// Refresh on launch, every purchase update, restore, and app foregrounding.
  /// A successful empty result revokes access; a transient store failure does
  /// not erase a previously verified entitlement while the device is offline.
  Future<bool> refreshEntitlements() async {
    if (isMock) {
      await (_creditLoading ??= _loadCredits());
      return !_disposed && _creditsReady;
    }
    if (_disposed ||
        !native ||
        !_purchasesEnabled ||
        defaultTargetPlatform != TargetPlatform.iOS) {
      return false;
    }
    final epoch = ++_entitlementEpoch;
    try {
      final active = _entitlementReader != null
          ? await _entitlementReader()
          : (await SK2Transaction.currentEntitlements()).any(
              (transaction) => transaction.productId == productId,
            );
      if (!_disposed && epoch == _entitlementEpoch) {
        adFree = active;
        _notify();
        return true;
      }
    } catch (_) {
      // Keep the last verified state; the next foreground event retries.
    }
    return false;
  }

  Future<void> _loadCredits() async {
    try {
      final prefs = _preferences ??= await SharedPreferences.getInstance();
      final raw = prefs.getString(_storageKey);
      if (raw != null) {
        final data = jsonDecode(raw);
        if (data is Map &&
            data['version'] == 1 &&
            data['hints'] is int &&
            data['skips'] is int &&
            data['hints'] >= 0 &&
            data['hints'] <= 100000 &&
            data['skips'] >= 0 &&
            data['skips'] <= 100000) {
          _hintCredits = data['hints'] as int;
          _skipCredits = data['skips'] as int;
          if (isMock) adFree = data['adFree'] == true;
        } else {
          throw const FormatException('Invalid saved support balance');
        }
      }
      _creditsReady = true;
      _saveCredits();
    } catch (_) {
      // Do not consume a balance that could not be loaded.
      message = 'Flight support could not load its saved balance. Please reopen the app.';
    }
    _notify();
  }

  void _saveCredits() {
    final snapshot = jsonEncode({
      'version': 1,
      'hints': _hintCredits,
      'skips': _skipCredits,
      if (isMock) 'adFree': adFree,
    });
    _creditWrites = _creditWrites
        .then((_) async {
          final prefs = _preferences ??= await SharedPreferences.getInstance();
          if (!await prefs.setString(_storageKey, snapshot)) {
            throw StateError('Support balance was not saved');
          }
        })
        .catchError((Object _) {
          message = 'Could not save the flight-support balance. Keep the app open and try again.';
          _notify();
        });
  }

  Future<void> flushCredits() => _creditWrites;

  Future<void> buy() async {
    if (!canBuy) return;
    if (isMock) {
      await (_creditLoading ??= _loadCredits());
      if (_disposed || !_creditsReady) return;
      adFree = true;
      _saveCredits();
      await flushCredits();
      message = 'Demo only — no payment. Ad-free hints and skips unlocked for this preview.';
      _notify();
      return;
    }
    busy = true;
    message = null;
    _notify();
    try {
      final started = await InAppPurchase.instance.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: product!),
      );
      if (!started) busy = false;
    } catch (_) {
      busy = false;
      message = 'The store is unavailable. Please try again.';
    }
    _notify();
  }

  Future<void> restore() async {
    if (!_purchasesEnabled) {
      message = 'Glowpath is free to play. Purchases are disabled.';
      _notify();
      return;
    }
    if (isMock) {
      await (_creditLoading ??= _loadCredits());
      message = adFree
          ? 'Demo purchase restored on this device. No payment.'
          : 'No demo purchase saved on this device.';
      _notify();
      return;
    }
    if (!native ||
        !_purchasesEnabled ||
        defaultTargetPlatform != TargetPlatform.iOS) {
      message = 'Purchases are not active in this review build.';
      _notify();
      return;
    }
    try {
      await InAppPurchase.instance.restorePurchases();
      final checked = await refreshEntitlements();
      message = !checked
          ? 'The App Store could not check purchases yet. Please try again.'
          : adFree
          ? 'Ad-free flight restored.'
          : 'No active ad-free purchase was found.';
    } catch (_) {
      message = 'Could not restore purchases. Try again.';
    }
    _notify();
  }

  bool consumeHint() {
    if (reviewMode || adFree) return true;
    if (!_creditsReady || _hintCredits == 0) return false;
    _hintCredits--;
    _saveCredits();
    _notify();
    return true;
  }

  bool consumeSkip() {
    if (reviewMode || adFree) return true;
    if (!_creditsReady || _skipCredits == 0) return false;
    _skipCredits--;
    _saveCredits();
    _notify();
    return true;
  }

  Future<bool> earnReward({required bool skip}) async {
    if (isMock) {
      await (_creditLoading ??= _loadCredits());
      if (_disposed || busy || adFree || !_creditsReady) return false;
      busy = true;
      _notify();
      if (skip) {
        _skipCredits++;
      } else {
        _hintCredits += 3;
      }
      _saveCredits();
      await flushCredits();
      busy = false;
      message = skip
          ? 'Demo reward: one skip. No ad was shown.'
          : 'Demo reward: three hints. No ad was shown.';
      _notify();
      return true;
    }
    if (!native || !_adsEnabled || busy || adFree || !_creditsReady) {
      return false;
    }
    busy = true;
    message = null;
    _notify();
    try {
      if (!await _ads.prepare()) {
        message = 'An ad is not available. Your route stays saved.';
        return false;
      }
      final consentEpoch = _ads.consentEpoch;
      final placement = skip ? 'skip' : 'hint';
      _ads.onEvent?.call('ad_request', placement);
      final loaded = Completer<RewardedAd?>();
      bool timedOut = false;
      await RewardedAd.load(
        adUnitId: _ads.unit(skip ? 'skip' : 'hint'),
        request: const AdRequest(nonPersonalizedAds: true),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            if (timedOut || !_ads.hasCurrentConsent(consentEpoch)) {
              ad.dispose();
              if (!loaded.isCompleted) loaded.complete(null);
            } else if (!loaded.isCompleted) {
              loaded.complete(ad);
            }
          },
          onAdFailedToLoad: (_) {
            if (!loaded.isCompleted) loaded.complete(null);
          },
        ),
      );
      final ad = await loaded.future.timeout(
        const Duration(seconds: 15),
        onTimeout: () {
          timedOut = true;
          return null;
        },
      );
      if (ad == null || !_ads.hasCurrentConsent(consentEpoch)) {
        ad?.dispose();
        _ads.onEvent?.call('ad_no_fill', placement);
        message = 'No ad available right now. Try again later.';
        return false;
      }
      ad.onPaidEvent = (_, micros, precision, currency) =>
          _ads.recordRevenue(placement, micros, precision, currency);
      bool earned = false;
      final dismissed = Completer<bool>();
      ad.fullScreenContentCallback = FullScreenContentCallback(
        onAdShowedFullScreenContent: (_) =>
            _ads.onEvent?.call('ad_impression', placement),
        onAdDismissedFullScreenContent: (ad) {
          _ads.onEvent?.call('ad_closed', placement);
          ad.dispose();
          if (!dismissed.isCompleted) dismissed.complete(earned);
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          _ads.onEvent?.call('ad_no_fill', placement);
          ad.dispose();
          if (!dismissed.isCompleted) dismissed.complete(false);
        },
      );
      await ad.show(
        onUserEarnedReward: (_, reward) {
          if (!earned) {
            earned = true;
            _ads.onEvent?.call('ad_reward', placement);
            if (skip) {
              _skipCredits++;
            } else {
              _hintCredits += 3;
            }
            _saveCredits();
            _notify();
          }
        },
      );
      final result = await dismissed.future;
      await flushCredits();
      message = result
          ? (skip ? 'One skip earned.' : 'Three hints earned.')
          : 'Ad closed. No reward was claimed.';
      return result;
    } catch (_) {
      message = 'Ad unavailable. Your route stays saved.';
      return false;
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> privacyOptions() async {
    if (isMock) {
      message = 'Demo mode does not contact ad networks.';
      _notify();
      return;
    }
    if (!native || !_adsEnabled) return;
    await _ads.privacyOptions();
  }

  @override
  void dispose() {
    _disposed = true;
    _purchaseSubscription?.cancel();
    if (_ownsAds) _ads.dispose();
    super.dispose();
  }
}
