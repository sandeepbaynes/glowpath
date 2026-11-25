import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:glowpath/services/native_ads.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

void main() {
  for (final reviewMode in [false, true]) {
    test(
      'consent failure diagnostics reviewMode=$reviewMode contain no SDK payload',
      () async {
        final originalConsent = ConsentInformation.instance;
        final originalPrint = debugPrint;
        final lines = <String>[];
        ConsentInformation.instance = _FailedConsent();
        debugPrint = (message, {wrapWidth}) {
          if (message != null) lines.add(message);
        };
        addTearDown(() {
          ConsentInformation.instance = originalConsent;
          debugPrint = originalPrint;
        });
        final ads = _DiagnosticAds(reviewMode);
        addTearDown(ads.dispose);
        expect(await ads.prepare(), isFalse);
        await Future<void>.delayed(Duration.zero);
        expect(ads.ready, isFalse);
        expect(ads.presenting, isFalse);
        expect(ads.initialized, isFalse);
        if (!reviewMode) {
          expect(lines, isEmpty);
        } else {
          final log = lines.join('\n');
          expect(log, contains('consent.update.failed errorCode=77'));
          expect(log, contains('status=unknown'));
          expect(log, contains('formAvailable=false'));
          expect(log, contains('privacyOptions=unknown'));
          expect(log, contains('canRequestAds=false'));
          expect(log, contains('prepare.blocked reason=consent'));
          expect(log, isNot(contains('SDK-SENSITIVE-PAYLOAD')));
          expect(log, isNot(contains('PRIVATE-TEST-DEVICE')));
        }
      },
    );
  }
}

class _DiagnosticAds extends NativeAds {
  _DiagnosticAds(bool reviewMode)
    : super(
        config: NativeAdConfig(
          enabled: true,
          reviewMode: reviewMode,
          deviceIds: 'PRIVATE-TEST-DEVICE',
        ),
      );
  bool initialized = false;
  @override
  bool get enabled => true;
  @override
  Future<void> initializeSdk() async {
    initialized = true;
  }
}

class _FailedConsent extends ConsentInformation {
  @override
  void requestConsentInfoUpdate(
    ConsentRequestParameters params,
    OnConsentInfoUpdateSuccessListener successListener,
    OnConsentInfoUpdateFailureListener failureListener,
  ) => failureListener(
    FormError(errorCode: 77, message: 'SDK-SENSITIVE-PAYLOAD'),
  );
  @override
  Future<bool> canRequestAds() async => false;
  @override
  Future<ConsentStatus> getConsentStatus() async => ConsentStatus.unknown;
  @override
  Future<bool> isConsentFormAvailable() async => false;
  @override
  Future<PrivacyOptionsRequirementStatus>
  getPrivacyOptionsRequirementStatus() async =>
      PrivacyOptionsRequirementStatus.unknown;
  @override
  Future<void> reset() async =>
      throw StateError('Diagnostics must never reset consent');
}
