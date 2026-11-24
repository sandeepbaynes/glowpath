/// Decides whether a level-complete break may offer an interstitial.
///
/// This class never loads an ad. The caller records an impression only after
/// the provider actually opens an ad, so no-fill and cancellation do not
/// consume the pacing allowance.
class AdPacing {
  AdPacing({
    this.firstFreeCompletions = 3,
    this.levelInterval = 3,
    this.playInterval = const Duration(minutes: 3),
    this.minimumBetweenAds = const Duration(minutes: 2),
  }) : _completedAtLastAd = firstFreeCompletions;

  final int firstFreeCompletions;
  final int levelInterval;
  final Duration playInterval;
  final Duration minimumBetweenAds;

  int _completed = 0;
  int _completedAtLastAd;
  Duration _activePlay = Duration.zero;
  Duration _playAtLastAd = Duration.zero;
  Duration? _lastAdAt;

  int get completed => _completed;
  Duration get activePlay => _activePlay;

  /// Pass only foreground gameplay time, never wall time spent in menus/ads.
  void recordPlay(Duration elapsed) {
    if (elapsed > Duration.zero) _activePlay += elapsed;
  }

  /// Returns true only at a genuine successful level boundary.
  bool completeLevel({
    required Duration now,
    required bool engaged,
    required bool assisted,
    required bool challenge,
  }) {
    _completed++;
    if (challenge || assisted || !engaged || _completed <= firstFreeCompletions) {
      return false;
    }
    if (_lastAdAt != null && now - _lastAdAt! < minimumBetweenAds) {
      return false;
    }
    return _completed - _completedAtLastAd >= levelInterval ||
        _activePlay - _playAtLastAd >= playInterval;
  }

  void recordImpression(Duration now) {
    _lastAdAt = now;
    _completedAtLastAd = _completed;
    _playAtLastAd = _activePlay;
  }
}
