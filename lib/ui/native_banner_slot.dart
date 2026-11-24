import 'package:material_ui/material_ui.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../services/native_ads.dart';

/// Reserves its own space outside the game. No overlay can cover a control.
class NativeBannerSlot extends StatefulWidget {
  const NativeBannerSlot({super.key, required this.ads});
  final NativeAds ads;
  @override
  State<NativeBannerSlot> createState() => _NativeBannerSlotState();
}

class _NativeBannerSlotState extends State<NativeBannerSlot> {
  BannerAd? _banner;
  bool _loaded = false;
  @override
  void initState() {
    super.initState();
    widget.ads.onEvent?.call('ad_request', 'banner');
    final ad = BannerAd(
      adUnitId: widget.ads.unit('banner'),
      size: AdSize.banner,
      request: const AdRequest(nonPersonalizedAds: true),
      listener: BannerAdListener(
        onPaidEvent: (_, micros, precision, currency) =>
            widget.ads.recordRevenue('banner', micros, precision, currency),
        onAdLoaded: (ad) {
          if (!mounted) {
            ad.dispose();
            return;
          }
          setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) {
          ad.dispose();
          widget.ads.onEvent?.call('ad_no_fill', 'banner');
          if (mounted) {
            setState(() {
              _banner = null;
              _loaded = false;
            });
          }
        },
        onAdImpression: (_) =>
            widget.ads.onEvent?.call('ad_impression', 'banner'),
      ),
    );
    _banner = ad;
    ad.load().catchError((Object _) {});
  }

  @override
  void dispose() {
    _banner?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _banner == null
      ? const SizedBox.shrink()
      : SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.only(top: 10, bottom: 4),
            child: SizedBox(
              height: 50,
              child: Center(
                child: SizedBox(
                  width: 320,
                  height: 50,
                  child: _loaded && _banner != null
                      ? AdWidget(ad: _banner!)
                      : null,
                ),
              ),
            ),
          ),
        );
}
