import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'game/game_controller.dart';
import 'game/launch_clock.dart';
import 'game/puzzle.dart';
import 'game/voyage_progression.dart';
import 'ui/cargo_art.dart';
import 'ui/challenge_instruments.dart';
import 'ui/challenge_result.dart';
import 'ui/cutout_beacon.dart';
import 'services/flight_league.dart';
import 'services/flight_support.dart';
import 'services/ad_pacing.dart';
import 'services/game_analytics.dart';
import 'services/fold_posture.dart';
import 'ui/flight_league_panel.dart';
import 'ui/flight_manual.dart';
import 'ui/flight_support_panel.dart';
import 'ui/earned_supply_panel.dart';
import 'ui/flight_settings.dart';
import 'ui/orbit_sheet.dart';
import 'ui/mission_briefing.dart';
import 'ui/planet_flight.dart';
import 'ui/reward_progress.dart';
import 'ui/rewards_panel.dart';
import 'ui/design.dart';
import 'ui/daily_reset.dart';
import 'ui/flight_failure.dart';
import 'ui/fold_layout.dart';
import 'ui/launch_countdown.dart';
import 'ui/launch_pressure.dart';
import 'ui/launch_splash.dart';
import 'ui/puzzle_board.dart';
import 'ui/space_controls.dart';
import 'ui/space_scenery.dart';
import 'ui/scene_transition.dart';
import 'ui/voyage_receipt.dart';
import 'ui/voyage_route_log.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    for (final family in ['Manrope', 'Atkinson', 'Lora']) {
      yield LicenseEntryWithLineBreaks([
        family,
      ], await rootBundle.loadString('assets/fonts/$family-OFL.txt'));
    }
  });
  runApp(const GlowpathApp());
}

class GlowpathApp extends StatelessWidget {
  const GlowpathApp({
    super.key,
    this.controller,
    this.ambientMotion = true,
    this.showBriefings = true,
    this.clockNow,
    this.startOnVoyage = false,
    this.foldGeometry,
  });
  final GameController? controller;
  final bool ambientMotion;
  final bool showBriefings;
  final Duration Function()? clockNow;
  final bool startOnVoyage;
  final ValueListenable<FoldGeometry>? foldGeometry;
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Glowpath',
    debugShowCheckedModeBanner: false,
    theme: gameTheme(),
    builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Palette.paper,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: child!,
    ),
    home: GameScreen(
      controller: controller,
      ambientMotion: ambientMotion,
      showBriefings: showBriefings,
      clockNow: clockNow,
      startOnVoyage: startOnVoyage,
      foldGeometry: foldGeometry,
    ),
  );
}

class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    this.controller,
    this.ambientMotion = true,
    this.showBriefings = true,
    this.clockNow,
    this.startOnVoyage = false,
    this.foldGeometry,
  });
  final GameController? controller;
  final bool ambientMotion;
  final bool showBriefings;
  final Duration Function()? clockNow;
  final bool startOnVoyage;
  final ValueListenable<FoldGeometry>? foldGeometry;
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late final GameController _game;
  late ValueListenable<FoldGeometry> _foldGeometry;
  FoldPosture? _nativeFoldPosture;
  late final AnimationController _arrival;
  AnimationController? _sheetMotion;
  final FlightLeague _league = FlightLeague();
  final FlightSupport _support = FlightSupport();
  final GameAnalytics _analytics = GameAnalytics();
  final AdPacing _adPacing = AdPacing();
  final _briefingKey = GlobalKey(debugLabel: 'mission-briefing');
  bool _welcome = false;
  bool _stageBriefing = false;
  bool _planetFlight = false;
  bool get _briefingOpen => _welcome || _stageBriefing || _planetFlight;
  List<MissionRule> get _newRules =>
      missionRulesFor(_game.puzzle)
          .where((rule) => !_game.knowsRule(rule.title))
          .toList();
  bool _wasSolved = false;
  late GameMode _observedMode;
  late bool _observedChallengeRefresh;
  late bool _hasLoaded;
  bool _animateOnward = false;
  final Stopwatch _monotonic = Stopwatch();
  late final LaunchClock _clock;
  late final ValueNotifier<Duration> _remaining;
  Timer? _clockTick;
  Timer? _challengeAdvance;
  bool _challengeAdvancePending = false;
  String? _clockRound;
  int? _lastPressureSecond;
  bool _foreground = true;
  int _panelDepth = 0;
  bool get _panelOpen => _panelDepth > 0;
  bool _flightFailed = false;
  void _track(String name, [Map<String, Object?> fields = const {}]) {
    unawaited(_analytics.record(name, fields).catchError((Object _) {}));
  }

  Map<String, Object?> get _levelFields => {
    'mode': _game.mode.name,
    'level': _game.puzzle.levelNumber,
  };
  bool _showNextStop = false;
  bool _voyageHome = false;
  bool get _showPlanets => !_isChallenge && (_voyageHome || _showNextStop);
  int? _hintIndex;
  bool get _systemReduced =>
      MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.reduceMotionOf(context);
  bool get _reduced => _game.reduceMotion || _systemReduced;
  bool get _contrast =>
      _game.highContrast || MediaQuery.highContrastOf(context);
  VoyageWorld get _world => VoyageWorld.forLevel(_game.puzzle.levelNumber);
  Duration get _budget => _isChallenge
      ? _game.challengeLaunchBudget
      : launchBudget(
          difficulty: _game.roundDifficulty,
          level: _game.puzzle.levelNumber,
          introduction: _game.isIntroduction,
          progressive: _game.isProgressionRound,
        );
  bool get _isChallenge => _game.mode != GameMode.voyage;
  Duration get _launchWindow => _game.attemptWindowBudget > Duration.zero
      ? _game.attemptWindowBudget
      : _budget;
  int get _challengeCount => _game.isWeekly ? 5 : 3;
  int get _challengeCompleted => _game.isWeekly
      ? _game.weeklyCompleted.length
      : _game.dailyCompleted.length;
  bool get _challengeComplete =>
      _isChallenge && _challengeCompleted == _challengeCount;
  String get _challengeTitle =>
      _game.isWeekly ? 'Weekly gauntlet' : 'Daily sprint';
  int get _challengeStage =>
      (_game.isWeekly ? _game.weeklyIndex : _game.dailyIndex) + 1;
  VoyageWorld get _atlasWorld => VoyageWorld.forLevel(_game.journeyLevel);
  Color get _trailColor => Color(_game.equippedTrail.colorValue);
  CargoKind? get _boardCargo {
    final id = _game.lastReward?.cargoId;
    if (_game.status.solved && id != null) {
      return CargoKind.values.where((kind) => kind.name == id).firstOrNull;
    }
    return _game.currentCargoClaimed ? null : _game.currentCargo?.kind;
  }

  bool get _canPlan =>
      _game.ready && !_game.status.solved && !_flightFailed && !_voyageHome;
  Puzzle get _displayPuzzle => _game.tracePreview ?? _game.puzzle;
  PuzzleStatus get _displayStatus => _displayPuzzle.evaluate();
  Duration? _lastTraceRejection;
  bool get _canTrace =>
      _canPlan && _foreground && !_panelOpen && !_briefingOpen;

  bool _beginTrace() {
    _tickClock();
    return _canTrace && _game.beginTrace();
  }

  bool _updateTrace(List<int> cells) {
    _tickClock();
    if (!_canTrace) {
      _game.cancelTrace();
      return false;
    }
    final accepted = _game.updateTrace(cells);
    if (accepted) {
      _hintIndex = null;
      if (_game.haptics && cells.length > 1) {
        unawaited(HapticFeedback.selectionClick());
      }
    }
    return accepted;
  }

  void _finishTrace() {
    _tickClock();
    if (!_canTrace) {
      _game.cancelTrace();
      return;
    }
    _act(_game.endTrace);
  }

  void _rejectTrace() {
    if (!_canTrace || !_game.haptics) return;
    final now = _monotonic.elapsed;
    if (_lastTraceRejection != null &&
        now - _lastTraceRejection! < const Duration(milliseconds: 140)) {
      return;
    }
    _lastTraceRejection = now;
    unawaited(HapticFeedback.mediumImpact());
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _game = widget.controller ?? GameController();
    _track('session_start');
    _foldGeometry = widget.foldGeometry ?? (_nativeFoldPosture = FoldPosture());
    _foldGeometry.addListener(_foldChanged);
    _voyageHome = widget.startOnVoyage && !_isChallenge;
    _welcome = widget.showBriefings && !_game.onboardingSeen;
    unawaited(_league.load());
    unawaited(_support.initialize());
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _monotonic.start();
    _clock = LaunchClock(
      now: widget.clockNow ?? () => _monotonic.elapsed,
      total: _budget,
    );
    _remaining = ValueNotifier(_budget);
    _wasSolved = _game.ready && _game.status.solved;
    _observedMode = _game.mode;
    _observedChallengeRefresh = _game.hasNewChallenge;
    _hasLoaded = _game.ready;
    _arrival = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1350),
      value: _wasSolved ? 1 : 0,
    );
    _showNextStop = _wasSolved;
    _arrival.addStatusListener((status) {
      if (status == AnimationStatus.completed &&
          mounted &&
          _game.status.solved) {
        _finishArrival();
      }
    });
    if (widget.showBriefings &&
        _game.ready &&
        !_voyageHome &&
        !_welcome &&
        _newRules.isNotEmpty) {
      _stageBriefing = true;
    }
    _syncClock();
    _clockTick = Timer.periodic(
      const Duration(milliseconds: 200),
      (_) => _tickClock(),
    );
    _game.addListener(_changed);
    unawaited(_game.load());
    if (_wasSolved && _isChallenge && !_challengeComplete) {
      _showNextStop = false;
      _challengeAdvancePending = true;
      _scheduleChallengeAdvance();
    }
  }

  void _finishArrival() {
    if (_isChallenge && !_challengeComplete) {
      setState(() {
        _showNextStop = false;
        _challengeAdvancePending = true;
      });
      _scheduleChallengeAdvance();
    } else {
      setState(() => _showNextStop = true);
    }
  }

  void _scheduleChallengeAdvance() {
    if (!mounted ||
        !_isChallenge ||
        !_challengeAdvancePending ||
        !_game.status.solved ||
        _challengeComplete ||
        !_foreground ||
        _panelOpen ||
        _briefingOpen ||
        _challengeAdvance != null) {
      return;
    }
    final round = _roundClockId;
    _challengeAdvance = Timer(const Duration(milliseconds: 320), () {
      _challengeAdvance = null;
      if (!mounted ||
          _roundClockId != round ||
          !_isChallenge ||
          !_challengeAdvancePending ||
          !_foreground ||
          _panelOpen ||
          _briefingOpen) {
        return;
      }
      _challengeAdvancePending = false;
      _act(_game.nextPuzzle);
    });
  }

  void _changed() {
    if (!mounted) return;
    if (_isChallenge) _voyageHome = false;
    final solved = _game.status.solved;
    if (_game.ready && _game.onboardingSeen) _welcome = false;
    final restoring =
        !_hasLoaded ||
        _observedMode != _game.mode ||
        (solved && _clockRound != _roundClockId);
    if (restoring || !solved) {
      _challengeAdvance?.cancel();
      _challengeAdvance = null;
      _challengeAdvancePending = false;
    }
    _hasLoaded = _game.ready;
    _observedMode = _game.mode;
    _observedChallengeRefresh = _game.hasNewChallenge;
    if (widget.showBriefings &&
        _game.ready &&
        !solved &&
        !_voyageHome &&
        !_welcome &&
        !_planetFlight &&
        _newRules.isNotEmpty) {
      _stageBriefing = true;
    }
    _syncClock();
    if (restoring) {
      if (_game.ready && !solved) _track('level_start', _levelFields);
      // A tab restores its saved screen directly. Only a new solve earns the
      // board payoff and onward journey; returning to a mode never replays it.
      _animateOnward = false;
      _showNextStop = solved && (!_isChallenge || _challengeComplete);
      _arrival.value = solved ? 1 : 0;
      if (solved && _isChallenge && !_challengeComplete) {
        _challengeAdvancePending = true;
        _scheduleChallengeAdvance();
      }
    } else if (solved && !_wasSolved) {
      final fields = {
        ..._levelFields,
        'assisted': _game.assisted,
        'timeBucket': _clock.elapsed.inSeconds ~/ 15,
      };
      _track('level_complete', fields);
      _adPacing.recordPlay(_clock.elapsed);
      if (_adPacing.completeLevel(
        now: _monotonic.elapsed,
        engaged: _game.puzzle.levelNumber > 3,
        assisted: _game.assisted,
        challenge: _isChallenge,
      )) {
        _track('ad_eligible', {'placement': 'voyage_result'});
      }
      _submitLeagueResult();
      _animateOnward = true;
      _arrival.duration = Duration(
        milliseconds: _isChallenge
            ? 900
            : _game.lastReward?.cargoId != null
            ? 3800
            : 1350,
      );
      if (_reduced) {
        _arrival.value = 1;
      } else {
        _arrival.forward(from: 0);
      }
    }
    if (!solved) {
      _showNextStop = false;
      _arrival.value = 0;
    }
    _wasSolved = solved;
    if (_reduced && _sheetMotion != null) {
      _sheetMotion!.duration = Duration.zero;
      _sheetMotion!.reverseDuration = Duration.zero;
    }
    setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground) _game.cancelTrace();
    if (_foreground) {
      unawaited(_support.refreshEntitlements());
    } else {
      unawaited(_support.flushCredits());
    }
    _syncClock();
    if (state != AppLifecycleState.resumed) unawaited(_game.flush());
    if (mounted) setState(() {});
  }

  void _syncClock() {
    final id = _roundClockId;
    if (_game.ready && _clockRound != id) {
      _clockRound = id;
      _flightFailed = false;
      _clock.reset(
        _budget + _game.attemptExtraTime,
        elapsed: _game.attemptElapsed,
      );
      _lastPressureSecond = null;
    } else if (_game.ready) {
      final total = _budget + _game.attemptExtraTime;
      if (total > _clock.total) _clock.extend(total - _clock.total);
    }
    if (!_foreground || _panelOpen || _briefingOpen || _flightFailed) {
      _game.cancelTrace();
      _challengeAdvance?.cancel();
      _challengeAdvance = null;
    }
    if (_canPlan && _foreground && !_panelOpen && !_briefingOpen) {
      _clock.resume();
    } else {
      _clock.pause();
    }
    _remaining.value = _clock.remaining;
    _sampleTiming();
    _scheduleChallengeAdvance();
  }

  String get _roundClockId =>
      '${_game.puzzle.seed}-${_game.puzzle.levelNumber}-'
      '${_game.roundDifficulty.name}-${_game.mode.name}-${_game.isIntroduction}-'
      '${_game.attemptRevision}';

  void _sampleTiming() {
    if (_game.ready && _clockRound == _roundClockId && !_game.status.solved) {
      _game.updateAttemptTiming(_clock.elapsed, _budget);
    }
  }

  void _tickClock() {
    if (!mounted) return;
    _remaining.value = _clock.remaining;
    _sampleTiming();
    _countdownHaptic();
    if (_observedChallengeRefresh != _game.hasNewChallenge) {
      setState(() => _observedChallengeRefresh = _game.hasNewChallenge);
    }
    if (_clock.expired && _canPlan && !_briefingOpen) {
      setState(() => _flightFailed = true);
      _track('level_fail', {
        ..._levelFields,
        'timeBucket': _clock.elapsed.inSeconds ~/ 15,
      });
      _game.cancelTrace();
    }
  }

  void _countdownHaptic() {
    final seconds = (_remaining.value.inMilliseconds / 1000).ceil();
    if (seconds == _lastPressureSecond) return;
    _lastPressureSecond = seconds;
    if (!_canPlan ||
        !_foreground ||
        _panelOpen ||
        !_game.haptics ||
        seconds <= 0 ||
        seconds > 10) {
      return;
    }
    if (seconds <= 2) {
      unawaited(HapticFeedback.heavyImpact());
    } else if (seconds <= 5) {
      unawaited(HapticFeedback.mediumImpact());
    } else if (seconds.isEven) {
      unawaited(HapticFeedback.lightImpact());
    }
  }

  void _retryFlight() {
    _sampleTiming();
    if (!_game.retryAfterTimeout()) return;
    _track('level_retry', _levelFields);
    setState(() {
      _flightFailed = false;
      _hintIndex = null;
      _lastPressureSecond = null;
      _syncClock();
    });
  }

  void _plan(bool Function() action) {
    _tickClock();
    if (_canPlan) _act(action);
  }

  void _foldChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _foldGeometry.removeListener(_foldChanged);
    _nativeFoldPosture?.dispose();
    _clock.pause();
    _sampleTiming();
    WidgetsBinding.instance.removeObserver(this);
    _game.removeListener(_changed);
    _game.cancelTrace();
    _clockTick?.cancel();
    _challengeAdvance?.cancel();
    _remaining.dispose();
    _league.dispose();
    _support.dispose();
    _monotonic.stop();
    if (widget.controller == null) _game.dispose();
    _arrival.dispose();
    super.dispose();
  }

  bool _act(bool Function() action, {bool keepHint = false}) {
    _sampleTiming();
    final wasSolved = _game.status.solved;
    if (!action()) return false;
    if (_game.haptics) {
      unawaited(
        !wasSolved && _game.status.solved
            ? HapticFeedback.lightImpact()
            : HapticFeedback.selectionClick(),
      );
    }
    setState(() {
      if (!keepHint) _hintIndex = null;
    });
    return true;
  }

  void _hint() {
    _tickClock();
    if (!_canPlan) return;
    if (_hintIndex != null) {
      if (_game.hintCredits > 0) {
        if (_act(_game.useHintCredit)) _track('hint_used', _levelFields);
        return;
      }
      if (!_support.consumeHint()) {
        _flightSupport(initialPage: 0);
        return;
      }
      if (_act(_game.hint)) _track('hint_used', _levelFields);
    } else {
      final candidate = _game.suggestedHintIndex;
      if (candidate == null) return;
      _act(_game.requestHint, keepHint: true);
      setState(() => _hintIndex = candidate);
    }
  }

  bool get _wideViewport {
    final size = MediaQuery.sizeOf(context);
    return size.width >= 650 && size.width > size.height * 1.1;
  }

  double get _contentWidth => _wideViewport ? 1400 : 1000;
  double get _sideInset => MediaQuery.sizeOf(context).width >= 600 ? 28 : 12;

  bool get _desktopLayout {
    final size = MediaQuery.sizeOf(context);
    final desktop = switch (defaultTargetPlatform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux => true,
      _ => false,
    };
    return desktop && size.width >= 650 && size.height >= 600;
  }

  Widget _foregroundFrame(Widget child) {
    if (!_desktopLayout || _showPlanets) return child;
    final size = MediaQuery.sizeOf(context);
    return Center(
      child: ConstrainedBox(
        key: const ValueKey('desktop-play-frame'),
        constraints: BoxConstraints(
          maxWidth: size.width >= 1100 ? 1100 : 600,
          maxHeight: 840,
        ),
        child: child,
      ),
    );
  }

  FoldPaneLayout? get _activeFoldPanes =>
      FoldPaneLayout.resolve(MediaQuery.of(context), _foldGeometry.value);

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SceneTransition(
      reduceMotion: _reduced,
      child: !_game.ready
          ? LaunchSplash(
              key: const ValueKey('launch-splash'),
              panes: _activeFoldPanes,
            )
          : Stack(
              key: const ValueKey('loaded-game'),
              fit: StackFit.expand,
              children: [
                ExcludeSemantics(
                  excluding: _flightFailed || _briefingOpen,
                  child: ExcludeFocus(
                    excluding: _flightFailed || _briefingOpen,
                    child: IgnorePointer(
                      ignoring: _flightFailed || _briefingOpen,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          SceneTransition(
                            reduceMotion: _reduced,
                            child: _showPlanets && _activeFoldPanes == null
                                ? KeyedSubtree(
                                    key: ValueKey(
                                      'voyage-sky-${_game.mode.name}',
                                    ),
                                    child: _voyageScene(),
                                  )
                                : SpaceBackdrop(
                                    key: const ValueKey('puzzle-sky'),
                                    level: _isChallenge
                                        ? _game.journeyLevel
                                        : _game.puzzle.levelNumber,
                                    reduceMotion: _reduced,
                                    ambientMotion: widget.ambientMotion,
                                    child: const SizedBox.expand(),
                                  ),
                          ),
                          if (!_showNextStop && !_voyageHome)
                            LaunchPressure(
                              remaining: _remaining,
                              total: _launchWindow,
                              active:
                                  _canPlan &&
                                  _foreground &&
                                  !_panelOpen &&
                                  !_briefingOpen,
                              reduceMotion: _reduced || !widget.ambientMotion,
                            ),
                          _flightForeground(),
                        ],
                      ),
                    ),
                  ),
                ),
                if (_planetFlight)
                  PlanetFlight(
                    key: const ValueKey('planet-flight'),
                    panes: _activeFoldPanes,
                    world: _world,
                    beats: _transitBriefing,
                    reduceMotion: _reduced,
                    onComplete: () {
                      if (!mounted) return;
                      _game.introduceRules(_newRules.map((rule) => rule.title));
                      setState(() {
                        _planetFlight = false;
                        _stageBriefing = false;
                      });
                      _syncClock();
                    },
                  ),
                if (_welcome || _stageBriefing) _briefingOverlay(),
                IgnorePointer(
                  ignoring: !_flightFailed,
                  child: SceneTransition(
                    reduceMotion: _reduced,
                    duration: const Duration(milliseconds: 260),
                    child: _flightFailed
                        ? (_isChallenge
                              ? ChallengeRetryOverlay(
                                  key: const ValueKey('failed-flight'),
                                  panes: _activeFoldPanes,
                                  stage: _challengeStage,
                                  stageCount: _challengeCount,
                                  onRetry: _retryFlight,
                                  reduceMotion: _reduced,
                                )
                              : FlightFailureOverlay(
                                  key: const ValueKey('failed-flight'),
                                  panes: _activeFoldPanes,
                                  trailColor: _trailColor,
                                  onRetry: _retryFlight,
                                  reduceMotion: _reduced,
                                ))
                        : const SizedBox.expand(key: ValueKey('clear-flight')),
                  ),
                ),
              ],
            ),
    ),
  );

  Widget _flightForeground() {
    final size = MediaQuery.sizeOf(context);
    final geometry = _foldGeometry.value;
    final outer = _closedFoldRegions(size, geometry);
    if (!_showPlanets && !_challengeComplete && outer != null) {
      return _closedFoldFlight(camera: outer.camera, statusArea: outer.status);
    }
    final activePanes = _activeFoldPanes;
    if (activePanes != null && _showPlanets) {
      return _foldHome(activePanes);
    }
    if (activePanes != null && _challengeComplete) {
      return _challengeResult(panes: activePanes);
    }
    final anchoredPanes = FoldPaneLayout.resolve(
      MediaQuery.of(context),
      geometry,
      includeInactive: true,
    );
    if (!_showPlanets && !_challengeComplete && anchoredPanes != null) {
      return _foldFlight(anchoredPanes);
    }
    return SafeArea(
      child: _foregroundFrame(
        Column(
          children: [
            Expanded(
              child: SceneTransition(
                reduceMotion: _reduced,
                child: KeyedSubtree(
                  key: ValueKey(
                    'hud-${_showNextStop || _voyageHome}-${_game.mode.name}',
                  ),
                  child: _showNextStop || _voyageHome
                      ? (_isChallenge ? _challengeResult() : _nextStopHud())
                      : _gameHud(),
                ),
              ),
            ),
            Padding(
              key: const ValueKey('shared-navigation'),
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: _navigationDock(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  ({Rect camera, Rect status})? _closedFoldRegions(
    Size size,
    FoldGeometry geometry,
  ) {
    // Identify the outer display from actual camera + status exclusion bounds.
    // Status only guards against a stale outer-display event during unfolding.
    if (!geometry.supported ||
        geometry.status != HingePosture.closed ||
        !geometry.matchesViewport(size) ||
        size.width >= size.height ||
        size.height < 520) {
      return null;
    }
    for (final camera in geometry.occlusions) {
      if (camera.shortestSide < 20 ||
          camera.longestSide > 64 ||
          (camera.width - camera.height).abs() > 4 ||
          camera.center.dx < size.width * .75 ||
          camera.bottom > size.height * .3) {
        continue;
      }
      for (final status in geometry.occlusions) {
        if (status == camera ||
            !status.contains(camera.center) ||
            status.right < size.width - 1 ||
            status.left < size.width * .72 ||
            status.height <= camera.height ||
            size.height - status.bottom < 300) {
          continue;
        }
        return (camera: camera, status: status);
      }
    }
    return null;
  }

  Widget _closedFoldFlight({required Rect camera, required Rect statusArea}) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(
        textScaler: media.textScaler.clamp(maxScaleFactor: 1.1),
      ),
      child: Stack(
        key: const ValueKey('closed-fold-flight'),
        children: [
          Positioned(
            left: media.padding.left,
            top: media.padding.top + 8,
            width: statusArea.left - media.padding.left,
            bottom: media.padding.bottom + 8,
            child: Padding(
              key: const ValueKey('closed-fold-main'),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(right: 28),
                    child: _compactDestination(),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, bounds) => Center(
                        child: SizedBox(
                          width: math.min(
                            bounds.maxWidth,
                            bounds.maxHeight - 28,
                          ),
                          child: _board(compact: true),
                        ),
                      ),
                    ),
                  ),
                  _playPanel(compact: true),
                  const SizedBox(height: 8),
                  _foldNavigation(),
                ],
              ),
            ),
          ),
          Positioned(
            left: statusArea.left + 2,
            top: statusArea.bottom + 10,
            right: 6,
            bottom: media.padding.bottom + 16,
            child: SizedBox(
              key: const ValueKey('closed-fold-launch-rail'),
              child: _launchInstrument(vertical: true),
            ),
          ),
          Positioned.fill(
            child: ValueListenableBuilder<Duration>(
              valueListenable: _remaining,
              builder: (context, remaining, _) => CutoutBeacon(
                camera: camera,
                systemOcclusions: _foldGeometry.value.occlusions,
                remaining: remaining,
                total: _launchWindow,
                reducedMotion: _reduced,
                paused: !_foreground || _panelOpen || _briefingOpen,
                complete: _game.status.solved,
                trailColor: _trailColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _foldFlight(FoldPaneLayout panes) {
    final media = MediaQuery.of(context);
    final horizontal = panes.horizontal;
    final expanded = panes.expanded;
    final mission = panes.missionRect;
    final play = panes.actionRect;
    final gap = panes.gap;
    final toolsAbove = horizontal && play.width < 620 && play.height < 420;
    return MediaQuery(
      data: media.copyWith(
        textScaler: media.textScaler.clamp(maxScaleFactor: 1.1),
      ),
      child: Stack(
        children: [
          Positioned.fromRect(
            rect: mission,
            child: ClipRect(
              key: ValueKey(
                horizontal ? 'fold-mission-top' : 'fold-mission-side',
              ),
              child: _foldMissionPane(
                horizontal: horizontal,
                includeTools: toolsAbove,
                expanded: expanded,
              ),
            ),
          ),
          Positioned.fromRect(
            rect: gap,
            child: const IgnorePointer(
              child: SizedBox(key: ValueKey('fold-hinge-gap')),
            ),
          ),
          Positioned.fromRect(
            rect: play,
            child: ClipRect(
              key: ValueKey(horizontal ? 'fold-play-bottom' : 'fold-play-side'),
              child: _foldPlayPane(includeTools: !toolsAbove),
            ),
          ),
        ],
      ),
    );
  }

  Widget _foldMissionPane({
    required bool horizontal,
    required bool includeTools,
    required bool expanded,
  }) => LayoutBuilder(
    builder: (context, bounds) {
      final wide = bounds.maxWidth >= 620 && horizontal;
      if (horizontal && includeTools) {
        // A clamshell becomes a small mission desk: the upright half carries
        // its own unobscured map and timer; every routing tile stays below.
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _compactDestination(),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: ClipRect(
                        child: _foldMap(expanded: expanded, verticalFocus: .30),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 6,
                      child: _launchInstrument(prominent: true, dense: true),
                    ),
                  ],
                ),
              ),
              PuzzleLegend(status: _displayStatus, compact: true),
              const SizedBox(height: 6),
              SizedBox(height: 48, child: _controls(compact: true)),
              const SizedBox(height: 8),
              _foldNavigation(),
            ],
          ),
        );
      }
      final instruments = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _compactDestination(),
          _launchInstrument(prominent: true, dense: bounds.maxHeight < 400),
          PuzzleLegend(status: _displayStatus, compact: true),
          if (includeTools) ...[
            const SizedBox(height: 6),
            SizedBox(height: 48, child: _controls(compact: true)),
            const SizedBox(height: 8),
            _foldNavigation(),
          ] else if (bounds.maxHeight >= 280) ...[
            const SizedBox(height: 8),
            SizedBox(height: 56, child: _instructions(alignStart: true)),
          ],
        ],
      );
      return Stack(
        fit: StackFit.expand,
        children: [
          _foldMap(expanded: expanded, verticalFocus: horizontal ? .36 : .25),
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: wide ? Alignment.centerLeft : Alignment.topCenter,
                  end: wide ? Alignment.centerRight : Alignment.bottomCenter,
                  colors: const [Color(0x00060B14), Color(0xF2060B14)],
                  stops: const [.15, .65],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Align(
              alignment: wide ? Alignment.centerRight : Alignment.bottomCenter,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: wide ? bounds.maxWidth * .42 : 560,
                ),
                child: instruments,
              ),
            ),
          ),
        ],
      );
    },
  );

  Widget _foldMap({required bool expanded, required double verticalFocus}) =>
      IgnorePointer(
        child: ExcludeSemantics(
          child: AnimatedOpacity(
            key: const ValueKey('fold-map-reveal'),
            opacity: expanded ? 1 : .76,
            duration: _reduced
                ? Duration.zero
                : const Duration(milliseconds: 650),
            curve: Curves.easeInOutCubic,
            child: AnimatedScale(
              scale: expanded ? 1.025 : 1,
              duration: _reduced
                  ? Duration.zero
                  : const Duration(milliseconds: 850),
              curve: Curves.easeInOutCubic,
              child: VoyageExplorer(
                sceneKey: const ValueKey('fold-live-map'),
                current: _world,
                routesAtDestination: (_game.puzzle.levelNumber - 1) % 15,
                showCourier: true,
                animateArrival: false,
                ambientMotion: widget.ambientMotion,
                reduceMotion: _reduced,
                trailColor: _trailColor,
                verticalFocus: verticalFocus,
                paintBackground: false,
              ),
            ),
          ),
        ),
      );

  Widget _foldNavigation() => KeyedSubtree(
    key: const ValueKey('shared-navigation'),
    child: _navigationDock(),
  );

  Widget _foldPlayPane({required bool includeTools}) => LayoutBuilder(
    builder: (context, bounds) {
      final wide = includeTools && bounds.maxWidth >= 620;
      final sideWidth = (bounds.maxWidth * .42).clamp(300.0, 420.0);
      final extent = math
          .min(
            bounds.maxWidth - 24 - (wide ? sideWidth + 24 : 0),
            bounds.maxHeight - 24 - (includeTools && !wide ? 168 : 0),
          )
          .clamp(0.0, 760.0);
      final board = SizedBox(
        width: extent,
        child: _board(compact: true, showLabels: false),
      );
      final controls = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _playPanel(compact: true),
          const SizedBox(height: 12),
          _foldNavigation(),
        ],
      );
      return Padding(
        padding: const EdgeInsets.all(12),
        child: wide
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  board,
                  const SizedBox(width: 24),
                  SizedBox(width: sideWidth, child: controls),
                ],
              )
            : Column(
                children: [
                  Expanded(child: Center(child: board)),
                  if (includeTools) controls,
                ],
              ),
      );
    },
  );

  Widget _gameHud() => LayoutBuilder(
    builder: (context, viewport) {
      final wide =
          viewport.maxWidth >= 650 &&
          viewport.maxWidth > viewport.maxHeight * 1.1;
      // Game instruments have bounded typography, like the board itself.
      // Full preferred text sizes remain available in help and settings.
      final type = MediaQuery.textScalerOf(context)
          .clamp(maxScaleFactor: viewport.maxHeight < 650 ? 1.1 : 1.5);
      return MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: type),
        child: Padding(
          key: const ValueKey('game-viewport'),
          padding: EdgeInsets.symmetric(
            horizontal: viewport.maxWidth >= 600 ? 24 : 12,
            vertical: wide && viewport.maxHeight < 350 ? 0 : 4,
          ),
          child: LayoutBuilder(
            builder: (context, bounds) =>
                wide ? _wideGame(bounds) : _portraitGame(bounds),
          ),
        ),
      );
    },
  );

  Widget _navigationDock() => LayoutBuilder(
    builder: (context, constraints) => MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.1),
      ),
      child: OrbitDock(
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _mode('Voyage', GameMode.voyage)),
              const SizedBox(width: 4),
              Expanded(child: _mode('Daily', GameMode.daily)),
              const SizedBox(width: 4),
              Expanded(child: _mode('Weekly', GameMode.weekly)),
              const SizedBox(width: 8),
              OrbitUtility(
                key: const ValueKey('open-help'),
                width: constraints.maxWidth < 360 ? 48 : 56,
                label: 'How to play',
                onPressed: _help,
                icon: Icons.help_outline_rounded,
                reduceMotion: _reduced,
              ),
              OrbitUtility(
                key: const ValueKey('open-settings'),
                width: constraints.maxWidth < 360 ? 48 : 56,
                label: 'Settings and restart',
                onPressed: _settings,
                icon: Icons.tune_rounded,
                reduceMotion: _reduced,
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _portraitGame(BoxConstraints viewport) {
    final roomy = viewport.maxHeight >= 620;
    final tight = viewport.maxHeight < 550;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (tight)
          Row(
            children: [
              _compactMapBeacon(),
              const SizedBox(width: 8),
              Expanded(child: _launchInstrument(prominent: true, dense: true)),
            ],
          )
        else ...[
          _compactDestination(),
          if (roomy) ...[
            const SizedBox(height: 4),
            SizedBox(height: 60, child: _instructions()),
          ],
          const SizedBox(height: 4),
        ],
        Expanded(
          child: LayoutBuilder(
            builder: (context, slot) {
              // Keep the launch clock attached directly to the board legend.
              // On the shortest screens the clock shares the top line with
              // the map beacon so five-by-five tiles remain full touch size.
              final clockHeight = tight ? 0.0 : 80.0;
              final extent = math.min(
                math.min(viewport.maxWidth, _desktopLayout ? 520.0 : 920.0),
                slot.maxHeight - 24 - clockHeight,
              );
              return Center(
                child: SizedBox(
                  width: extent,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!tight) ...[
                        _launchInstrument(prominent: true),
                        const SizedBox(height: 4),
                      ],
                      _board(compact: true),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        if (!tight) const SizedBox(height: 4),
        Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: _desktopLayout ? 520 : 720),
            child: _playPanel(compact: true),
          ),
        ),
      ],
    );
  }

  Widget _compactMapBeacon() => Semantics(
    button: true,
    label:
        '${_isChallenge ? _challengeTitle : _world.name}, route ${_game.puzzle.levelNumber}. Open voyage map',
    child: InkWell(
      key: const ValueKey('open-atlas'),
      onTap: _map,
      borderRadius: BorderRadius.circular(24),
      child: SizedBox.square(
        dimension: 48,
        child: ExcludeSemantics(
          child: Stack(
            alignment: Alignment.center,
            children: [
              PlanetMedallion(world: _atlasWorld, size: 34),
              const Positioned(
                right: 0,
                bottom: 2,
                child: Icon(
                  Icons.north_east_rounded,
                  color: Palette.rust,
                  size: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _wideGame(BoxConstraints viewport) {
    final short = viewport.maxHeight < 550;
    final gap = short ? 20.0 : 36.0;
    final panelWidth = math.min(
      _desktopLayout
          ? 340.0
          : short
          ? 400.0
          : 460.0,
      viewport.maxWidth * .37,
    );
    final boardWidth = math.min(
      math.min(
        viewport.maxHeight - (short ? 0 : 24),
        _desktopLayout ? 540.0 : double.infinity,
      ),
      viewport.maxWidth - panelWidth - gap,
    );
    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: boardWidth,
            child: _board(compact: true, showLabels: !short),
          ),
          SizedBox(width: gap),
          SizedBox(
            key: const ValueKey('wide-flight-panel'),
            width: panelWidth,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _compactDestination(),
                SizedBox(height: short ? 4 : 16),
                _launchInstrument(prominent: true, dense: short),
                if (short) PuzzleLegend(status: _displayStatus, compact: true),
                if (!short) ...[
                  const SizedBox(height: 16),
                  SizedBox(height: 64, child: _instructions(alignStart: true)),
                ],
                SizedBox(height: short ? 4 : 20),
                _playPanel(compact: true, sidebar: !short),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _compactDestination() => MediaQuery(
    data: MediaQuery.of(context).copyWith(
      textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.1),
    ),
    child: Semantics(
      button: true,
      label: _isChallenge
          ? '$_challengeTitle. Open voyage map'
          : '${_world.galaxyName}. Destination ${_world.name}. Open voyage map',
      value: _isChallenge
          ? '$_challengeCompleted of $_challengeCount routes charted'
          : 'Route ${_world.routeWithin(_game.puzzle.levelNumber)} of 15',
      child: InkWell(
        key: const ValueKey('open-atlas'),
        onTap: _map,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 64,
          child: ExcludeSemantics(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _isChallenge
                            ? 'RAPID FIRE · $_challengeCount SIGNALS'
                            : 'PLANET ${VoyageProgression.forLevel(_game.puzzle.levelNumber).planetIndex.toString().padLeft(2, '0')}',
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.7,
                          color: Palette.secondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              _isChallenge ? _challengeTitle : _world.name,
                              maxLines: 1,
                              style: bookTitle(22),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            _isChallenge
                                ? '${_challengeStage.toString().padLeft(2, '0')}/${_challengeCount.toString().padLeft(2, '0')}'
                                : '${_world.routeWithin(_game.puzzle.levelNumber).toString().padLeft(2, '0')}/15',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Palette.secondary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                PlanetMedallion(world: _atlasWorld, size: 44),
                const SizedBox(width: 8),
                const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.north_east_rounded,
                      size: 18,
                      color: Palette.rust,
                    ),
                    SizedBox(height: 3),
                    Text(
                      'Map',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Palette.rust,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _mode(String label, GameMode mode) => OrbitMode(
    key: ValueKey(
      mode == GameMode.voyage ? 'mode-journey' : 'mode-${mode.name}',
    ),
    selected: _game.mode == mode,
    label: label,
    reduceMotion: _reduced,
    onPressed: !_game.ready
        ? null
        : mode == GameMode.voyage
        ? _map
        : () {
            _voyageHome = false;
            _act(() => _game.setMode(mode));
          },
  );

  Widget _board({
    bool compact = false,
    bool showLabels = true,
  }) => AnimatedSwitcher(
    duration: _reduced ? Duration.zero : const Duration(milliseconds: 300),
    switchInCurve: Curves.easeOut,
    layoutBuilder: (current, previous) => Stack(
      alignment: Alignment.center,
      children: [
        ...previous.map(
          (child) => IgnorePointer(child: ExcludeSemantics(child: child)),
        ),
        ?current,
      ],
    ),
    child: AnimatedBuilder(
      key: ValueKey(
        '${_game.puzzle.seed}-${_game.puzzle.levelNumber}-${_game.roundDifficulty.name}-${_game.mode.name}-${_game.isIntroduction}',
      ),
      animation: _arrival,
      builder: (context, _) => PuzzleBoard(
        compact: compact,
        showLabels: showLabels,
        puzzle: _displayPuzzle,
        trailColor: _trailColor,
        cargoKind: _boardCargo,
        collectCargo: _game.lastReward?.cargoId != null,
        status: _displayStatus,
        enabled: _canTrace,
        reduceMotion: _reduced,
        highContrast: _contrast,
        hintedIndex: _hintIndex,
        completionProgress: _game.status.solved
            ? (_reduced ? 1 : _arrival.value)
            : 0,
        teachEntrance: false,
        onTurn: (index) => _plan(() => _game.rotate(index)),
        onTraceStart: _beginTrace,
        onTraceUpdate: _updateTrace,
        onTraceEnd: _finishTrace,
        onTraceCancel: _game.cancelTrace,
        onTraceRejected: _rejectTrace,
      ),
    ),
  );

  Widget _playPanel({bool compact = false, bool sidebar = false}) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      SizedBox(
        height: sidebar ? 104 : 48,
        child: SceneTransition(
          reduceMotion: _reduced,
          duration: const Duration(milliseconds: 220),
          child: _game.status.solved
              ? (_isChallenge
                    ? Semantics(
                        liveRegion: true,
                        label: _challengeComplete
                            ? 'Challenge complete'
                            : 'Signal locked. Next signal loads automatically.',
                        child: Center(
                          child: Text(
                            _challengeComplete
                                ? 'Challenge complete'
                                : 'Signal locked · next signal incoming',
                            style: const TextStyle(
                              color: Palette.rust,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      )
                    : SpaceAction(
                        key: const ValueKey('next-puzzle'),
                        label: 'Play',
                        onPressed: _playNext,
                        compact: true,
                        reduceMotion: _reduced,
                      ))
              : KeyedSubtree(
                  key: const ValueKey('route-tools'),
                  child: _controls(compact: true, stacked: sidebar),
                ),
        ),
      ),
      SizedBox(height: sidebar ? 12 : 4),
      if (sidebar)
        SizedBox(
          height: 64,
          child: Align(alignment: Alignment.topLeft, child: _sidebarStats()),
        )
      else
        SizedBox(
          height: 20,
          child: FittedBox(fit: BoxFit.scaleDown, child: _stats()),
        ),
      if (_game.saveError)
        Semantics(
          liveRegion: true,
          child: const Text(
            'Could not save. Keep the game open.',
            style: TextStyle(fontSize: 12),
          ),
        ),
    ],
  );

  Widget _launchInstrument({
    bool compact = false,
    bool prominent = false,
    bool dense = false,
    bool vertical = false,
  }) => ValueListenableBuilder<Duration>(
    valueListenable: _remaining,
    builder: (context, remaining, _) => LaunchCountdown(
      compact: compact,
      prominent: prominent,
      dense: dense,
      vertical: vertical,
      trailColor: _trailColor,
      remaining: remaining,
      total: _launchWindow,
      reducedMotion: _reduced,
      expired: _flightFailed,
      complete: _game.status.solved,
      paused: !_foreground || _panelOpen || _briefingOpen,
    ),
  );

  void _playNext() {
    if (_voyageHome && !_game.status.solved) {
      setState(() {
        _voyageHome = false;
        _stageBriefing = widget.showBriefings && _newRules.isNotEmpty;
      });
      _syncClock();
      return;
    }
    _voyageHome = false;
    final crossing =
        !_isChallenge &&
        VoyageProgression.forLevel(_nextLevel).planetIndex !=
            VoyageProgression.forLevel(_game.puzzle.levelNumber).planetIndex;
    if (crossing && widget.showBriefings) _planetFlight = true;
    _act(
      _challengeComplete
          ? () => _game.setMode(GameMode.voyage)
          : _game.nextPuzzle,
    );
  }

  int get _nextLevel => !_isChallenge && !_game.status.solved
      ? _game.puzzle.levelNumber
      : _game.isReplaying || _challengeComplete
      ? _game.journeyLevel
      : _isChallenge
      ? _game.nextChallengeLevel
      : _game.puzzle.levelNumber + 1;

  Widget _voyageScene({double? verticalFocus}) => Stack(
    fit: StackFit.expand,
    children: [
      VoyageExplorer(
        key: ValueKey('next-universe-${_game.mode.name}-$_nextLevel'),
        sceneKey: const ValueKey('next-stop-flight'),
        current: VoyageWorld.forLevel(_nextLevel),
        routesAtDestination:
            (_nextLevel - 1) % VoyageProgression.levelsPerPlanet,
        showCourier: true,
        trailColor: _trailColor,
        ambientMotion: widget.ambientMotion,
        verticalFocus:
            verticalFocus ??
            (MediaQuery.sizeOf(context).width >
                    MediaQuery.sizeOf(context).height
                ? .22
                : .38),
        reduceMotion: _reduced,
        arrivalDuration: const Duration(milliseconds: 2600),
        arrivalCurve: Curves.easeInOutCubic,
        animateArrival: _animateOnward,
      ),
      const IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xE6080F20),
                Color(0x00080F20),
                Color(0x00080F20),
                Color(0x66080F20),
              ],
              stops: [0, .3, .65, 1],
            ),
          ),
        ),
      ),
    ],
  );

  Widget _pane(Rect rect, String key, Widget child) => Positioned.fromRect(
    rect: rect,
    child: ClipRect(
      key: ValueKey(key),
      child: MediaQuery(
        data: FoldPaneLayout.paneMediaQuery(MediaQuery.of(context), rect),
        child: child,
      ),
    ),
  );

  Widget _foldHome(FoldPaneLayout panes) => Stack(
    children: [
      _pane(
        panes.missionRect,
        'fold-home-map',
        Stack(
          fit: StackFit.expand,
          children: [
            _voyageScene(verticalFocus: .47),
            Positioned(
              left: 20,
              top: 14,
              right: 20,
              child: IgnorePointer(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _game.status.solved ? 'SIGNAL DELIVERED' : 'YOUR VOYAGE',
                      style: const TextStyle(
                        color: Palette.secondary,
                        fontSize: 11,
                        letterSpacing: 1.8,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _game.status.solved
                          ? '+${_game.lastReward?.score ?? _game.puzzle.scoreForMoves(_game.moves)} points'
                          : VoyageWorld.forLevel(_nextLevel).galaxyName,
                      style: bookTitle(22),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      _pane(
        panes.actionRect,
        'fold-home-actions',
        Column(
          children: [
            Expanded(child: _nextStopHud(pane: true)),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: _navigationDock(),
            ),
          ],
        ),
      ),
      Positioned.fromRect(
        rect: panes.gap,
        child: const IgnorePointer(
          child: SizedBox(key: ValueKey('fold-home-gap')),
        ),
      ),
    ],
  );

  Widget _panelCompanion(String title) => IgnorePointer(
    child: ExcludeSemantics(
      child: Material(
        color: Palette.paper,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _foldMap(expanded: false, verticalFocus: .48),
            Positioned(
              left: 20,
              right: 20,
              top: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'VOYAGE PAUSED',
                    style: const TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.8,
                      color: Palette.secondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(_world.name, style: bookTitle(24)),
                  const SizedBox(height: 4),
                  Text(
                    'Route ${_game.puzzle.levelNumber}',
                    style: const TextStyle(
                      color: Palette.secondary,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _nextStopHud({bool pane = false}) {
    final nextWorld = VoyageWorld.forLevel(_nextLevel);
    final challengeName = _game.isWeekly ? 'Weekly' : 'Daily';
    final destination = _isChallenge && !_challengeComplete
        ? '$challengeName route ${_game.nextChallengeIndex + 1} of $_challengeCount'
        : 'Planet ${VoyageProgression.forLevel(_nextLevel).planetIndex} · ${nextWorld.name}\nRoute ${VoyageProgression.forLevel(_nextLevel).levelInPlanet} / 15';
    final spokenDestination = _isChallenge && !_challengeComplete
        ? '${challengeName.toLowerCase()} route ${_game.nextChallengeIndex + 1} of $_challengeCount'
        : 'route $_nextLevel, ${nextWorld.name}';
    return LayoutBuilder(
      builder: (context, bounds) {
        final compact = bounds.maxHeight < 430;
        final shortPortrait = bounds.maxWidth < 600 && bounds.maxHeight < 550;
        final conciseDestination =
            bounds.maxWidth < 600 &&
            MediaQuery.textScalerOf(context).scale(1) > 1.3;
        final destinationLabel =
            conciseDestination && !(_isChallenge && !_challengeComplete)
            ? '${nextWorld.name}\nRoute ${VoyageProgression.forLevel(_nextLevel).levelInPlanet} / 15'
            : destination;
        final receipt = Semantics(
          key: const ValueKey('next-stop-summary'),
          liveRegion: true,
          excludeSemantics: true,
          label:
              'Signal delivered. Next: $spokenDestination. Press Play when ready.',
          child: VoyageReceipt(
            points:
                _game.lastReward?.score ??
                _game.puzzle.scoreForMoves(_game.moves),
            turns: _game.moves,
            assisted: _game.assisted,
            elapsed: _game.lastReward?.elapsedMilliseconds == null
                ? null
                : Duration(
                    milliseconds: _game.lastReward!.elapsedMilliseconds!,
                  ),
            personalBest: _game.lastReward?.newPersonalBest ?? false,
          ),
        );
        final rewards = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_game.status.solved)
              receipt
            else
              Padding(
                key: const ValueKey('voyage-home-heading'),
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'YOUR VOYAGE',
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 1.8,
                        color: Palette.secondary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(nextWorld.galaxyName, style: bookTitle(25)),
                  ],
                ),
              ),
            if (_game.status.solved && _game.lastReward != null)
              CompletionRewardBadge(reward: _game.lastReward!),
            if (_challengeComplete)
              DailyReset(
                dailyDate: _game.isWeekly ? _game.weeklyDate : _game.dailyDate,
                weekly: _game.isWeekly,
                compact: true,
              ),
          ],
        );
        final onward = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 48,
              child: Row(
                children: [
                  Expanded(
                    child: RewardProgress(
                      key: const ValueKey('open-rewards'),
                      stars: _game.stars,
                      equippedTrail: _game.equippedTrail,
                      nextTrail: _game.nextTrail,
                      onOpen: _rewards,
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 80,
                    child: OrbitMode(
                      key: const ValueKey('voyage-route-log'),
                      label: 'Routes',
                      selected: false,
                      onPressed: _routeLog,
                      reduceMotion: _reduced,
                    ),
                  ),
                  if (_game.isReplaying)
                    OrbitUtility(
                      key: const ValueKey('voyage-resume-frontier'),
                      label: 'Current route',
                      icon: Icons.my_location_rounded,
                      width: 48,
                      onPressed: () => _act(_game.returnToFrontier),
                      reduceMotion: _reduced,
                    ),
                ],
              ),
            ),
            SizedBox(height: compact || shortPortrait ? 8 : 16),
            Semantics(
              header: true,
              label: destination,
              excludeSemantics: true,
              child: Text(
                destinationLabel,
                style: bookTitle(compact || shortPortrait ? 21 : 25),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 12),
            SpaceAction(
              key: const ValueKey('next-puzzle'),
              label: 'Play',
              onPressed: _playNext,
              reduceMotion: _reduced,
            ),
          ],
        );
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: MediaQuery.textScalerOf(context)
                .clamp(maxScaleFactor: compact ? 1.25 : 1.6),
          ),
          child: Padding(
            padding: EdgeInsets.fromLTRB(_sideInset, 8, _sideInset, 16),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: _contentWidth),
                child: pane
                    ? Center(child: onward)
                    : compact
                    ? Row(
                        key: const ValueKey('completion'),
                        children: [
                          Expanded(child: rewards),
                          const SizedBox(width: 28),
                          Expanded(child: onward),
                        ],
                      )
                    : Column(
                        key: const ValueKey('completion'),
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 470),
                              child: rewards,
                            ),
                          ),
                          const Spacer(),
                          Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 470),
                              child: onward,
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                      ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _challengeResult({FoldPaneLayout? panes}) {
    final run = _game.challengeRunSummary!;
    return ChallengeResult(
      key: const ValueKey('challenge-complete'),
      panes: panes,
      weekly: _game.isWeekly,
      stageCount: _challengeCount,
      points: run.totalScore,
      activeElapsed: run.elapsedTotal,
      cleanStreak: run.bestStreak,
      medalEarned:
          (_game.lastReward?.dailyMedal ?? false) ||
          (_game.lastReward?.weeklyMedal ?? false),
      starsEarned: run.earnedStars,
      coinsEarned: run.coinsEarned,
      periodDate: run.period,
      hasCompleteTiming: run.stageRecords.values.every(
        (stage) => stage.elapsed != null,
      ),
      hasCompleteScore: run.stageRecords.values.every(
        (stage) => stage.score != null,
      ),
      hasNewChallenge: _game.hasNewChallenge,
      onNewChallenge: () => _act(_game.nextPuzzle),
      onVoyage: _map,
      onCollection: _rewards,
      reduceMotion: _reduced,
    );
  }

  Widget _instructions({bool alignStart = false}) {
    final exitIndex =
        _game.puzzle.endRow * _game.puzzle.size + _game.puzzle.size - 1;
    String guide;
    if (_flightFailed) {
      guide = 'Launch window closed. Repair the route on your next try.';
    } else if (_game.status.solved) {
      guide = 'All three stars are lit. Portal open.';
    } else if (_hintIndex != null) {
      guide = 'Turn the outlined relay, or let the hint do it.';
    } else if (_game.status.litCells.contains(exitIndex) &&
        (_game.puzzle.tiles[exitIndex].connections & east) != 0 &&
        _game.status.collectedStars.length < 3) {
      final remaining = 3 - _game.status.collectedStars.length;
      guide =
          'Portal reached. Light $remaining more ${remaining == 1 ? 'star' : 'stars'} to open it.';
    } else if (_game.currentCargo case final cargo?) {
      guide = _game.currentCargoClaimed
          ? 'Cargo secured. Find your fastest route through three stars.'
          : 'Optional ${cargo.kind.label.toLowerCase()}: detour to collect, or fly direct.';
    } else if (_game.isIntroduction && _game.puzzle.levelNumber == 1) {
      guide = 'Drag a route from START. Lift to set. Or tap to turn.';
    } else if (_game.status.collectedStars.length == 3) {
      guide = 'All three stars are lit. Connect to the portal.';
    } else if (_game.isPlanetRound) {
      final rules = missionRulesFor(_game.puzzle);
      guide = rules.isEmpty
          ? 'Drag from START through 3 stars to FINISH.'
          : rules.last.compactText;
    } else if (_game.isProgressionRound &&
        _game.puzzle.tiles.any((tile) => tile.isOneWay)) {
      guide = 'Follow the arrows. Light three stars. Reach the portal.';
    } else if (_game.isProgressionRound &&
        _game.puzzle.tiles.any((tile) => tile.isLocked)) {
      guide = 'Fixed relays stay put. Light three stars. Reach the portal.';
    } else {
      guide = 'Light all three stars. Reach the portal.';
    }
    if (_isChallenge) {
      final run = _game.challengeRunSummary!;
      return ChallengeStageRail(
        stageCount: _challengeCount,
        activeStage: _challengeStage,
        completedStages:
            (_game.isWeekly ? _game.weeklyCompleted : _game.dailyCompleted)
                .map((index) => index + 1)
                .toSet(),
        cleanStreak: run.cleanStreak,
        points: run.totalScore,
        instruction: _game.status.solved
            ? 'Next signal launches automatically.'
            : guide,
        reduceMotion: _reduced,
      );
    }
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(
        textScaler: MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.2),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Align(
          alignment: alignStart ? Alignment.centerLeft : Alignment.center,
          child: Semantics(
            liveRegion: true,
            child: SceneTransition(
              fill: false,
              reduceMotion: _reduced,
              duration: const Duration(milliseconds: 180),
              child: Text(
                guide,
                key: ValueKey(guide),
                textAlign: alignStart ? TextAlign.start : TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  height: 1.35,
                  color: Palette.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stats() => _isChallenge
      ? Text(
          '${_game.challengeRunSummary!.totalScore} pts · $_challengeCompleted/$_challengeCount signals · Clean streak ${_game.challengeRunSummary!.cleanStreak}',
          key: const ValueKey('challenge-live-stats'),
          style: const TextStyle(fontSize: 13, color: Palette.secondary),
        )
      : Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 6,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CoinMark(size: 14),
                const SizedBox(width: 3),
                Text(
                  '${_game.coinBalance} coins · ${_game.stars} stars',
                  key: const ValueKey('star-bank'),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Palette.white,
                  ),
                ),
              ],
            ),
            Text(
              '${_game.moves} ${_game.moves == 1 ? 'turn' : 'turns'}',
              key: const ValueKey('move-count'),
              style: const TextStyle(fontSize: 13, color: Palette.secondary),
            ),
            Text(
              'Target ${_game.puzzle.parMoves}',
              style: const TextStyle(fontSize: 13, color: Palette.secondary),
            ),
            if (_game.assisted)
              const Text(
                'Assisted',
                style: TextStyle(fontSize: 13, color: Palette.rust),
              ),
          ],
        );

  Widget _sidebarStats() => _isChallenge
      ? _stats()
      : Column(
          key: const ValueKey('wide-route-stats'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${_game.moves} ${_game.moves == 1 ? 'turn' : 'turns'}',
                  key: const ValueKey('move-count'),
                  style: const TextStyle(
                    fontSize: 13,
                    color: Palette.secondary,
                  ),
                ),
                Text(
                  'Target ${_game.puzzle.parMoves}',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Palette.secondary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const CoinMark(size: 14),
                const SizedBox(width: 5),
                Expanded(
                  child: Text(
                    '${_game.coinBalance} coins · ${_game.stars} stars',
                    key: const ValueKey('star-bank'),
                    style: const TextStyle(
                      fontSize: 13,
                      color: Palette.secondary,
                    ),
                  ),
                ),
                if (_game.assisted)
                  const Text(
                    'Assisted',
                    style: TextStyle(fontSize: 12, color: Palette.rust),
                  ),
              ],
            ),
          ],
        );

  Widget _controls({bool compact = false, bool stacked = false}) {
    final undo = SpaceAction(
      key: const ValueKey('undo'),
      compact: compact,
      onPressed: _canPlan && _game.canUndo ? () => _plan(_game.undo) : null,
      icon: Icons.undo_rounded,
      quiet: true,
      reduceMotion: _reduced,
      label: 'Undo',
    );
    final hint = SpaceAction(
      key: const ValueKey('hint'),
      compact: compact,
      accent: Palette.rust,
      reduceMotion: _reduced,
      onPressed: _canPlan ? _hint : null,
      icon: _hintIndex == null
          ? Icons.lightbulb_outline_rounded
          : Icons.rotate_right_rounded,
      label: _hintIndex == null ? 'Show a hint' : 'Turn this relay',
    );
    if (stacked) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 48, child: hint),
          const SizedBox(height: 8),
          SizedBox(
            height: 48,
            child: Row(
              children: [
                Expanded(child: undo),
                if (!_isChallenge) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: SpaceAction(
                      key: const ValueKey('support-shortcut'),
                      label: 'Skip',
                      icon: Icons.skip_next_rounded,
                      onPressed: _flightSupport,
                      quiet: true,
                      compact: true,
                      reduceMotion: _reduced,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      );
    }
    if (!compact && MediaQuery.textScalerOf(context).scale(1) > 1.7) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [hint, const SizedBox(height: 10), undo],
      );
    }
    return Row(
      children: [
        Expanded(flex: 2, child: undo),
        SizedBox(width: compact ? 8 : 12),
        Expanded(flex: 3, child: hint),
        if (!_isChallenge) ...[
          const SizedBox(width: 4),
          OrbitUtility(
            key: const ValueKey('support-shortcut'),
            label: 'Skip or get flight support',
            icon: Icons.skip_next_rounded,
            onPressed: _flightSupport,
            width: 48,
            reduceMotion: _reduced,
          ),
        ],
      ],
    );
  }

  List<MissionBriefingBeat> get _transitBriefing {
    final rules = _newRules;
    return [
      MissionBriefingBeat(
        text:
            'Approaching ${_world.name}. ${rules.isEmpty ? 'A new set of routes is waiting.' : rules.first.text}',
        compactText: 'Approaching ${_world.name}.',
        icon: Icons.radar_rounded,
      ),
      for (final rule in rules.skip(1))
        MissionBriefingBeat(
          text: rule.text,
          compactText: rule.compactText,
          icon: rule.icon,
          routeKind: rule.routeKind,
        ),
      const MissionBriefingBeat(
        text: 'Connect START through all three stars to FINISH.',
        compactText: 'Three stars. Then FINISH.',
        icon: Icons.route_rounded,
      ),
    ];
  }

  Widget _briefingOverlay() {
    final panes = _activeFoldPanes;
    final briefing = MissionBriefing(
      key: _briefingKey,
      panes: panes,
      destination: _welcome
          ? 'Your first flight'
          : _isChallenge
          ? '$_challengeTitle briefing'
          : _world.name,
      planet: VoyageProgression.forLevel(_game.puzzle.levelNumber).planetIndex,
      beats: _welcome
          ? firstFlightBriefing
          : _newRules.isEmpty
          ? mechanicBriefingFor(_game.puzzle)
          : [
              for (final rule in _newRules.take(3))
                MissionBriefingBeat(
                  text: '${rule.title}. ${rule.text}',
                  compactText: rule.compactText,
                  icon: rule.icon,
                  routeKind: rule.routeKind,
                ),
            ],
      actionLabel: !_welcome && _newRules.length > 3
          ? 'Next briefing'
          : "Let's fly",
      reduceMotion: _reduced,
      onStart: () {
        final welcome = _welcome;
        final explained = _newRules.take(3).map((rule) => rule.title).toList();
        setState(() {
          _welcome = false;
          _stageBriefing = false;
        });
        if (welcome) {
          _game.markOnboardingSeen();
        } else {
          _game.introduceRules(explained);
        }
        _syncClock();
      },
    );
    return ColoredBox(
      color: Palette.paper.withValues(alpha: .97),
      child: panes != null
          ? briefing
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 560,
                      maxHeight: 600,
                    ),
                    child: briefing,
                  ),
                ),
              ),
            ),
    );
  }

  void _submitLeagueResult() {
    if (!_league.joined ||
        !_isChallenge ||
        _game.assisted ||
        !_game.isPlanetRound ||
        !_game.hasVerifiedReplay) {
      return;
    }
    unawaited(
      _league
          .submit(
            mode: _game.isWeekly ? 'weekly' : 'daily',
            period: _game.isWeekly ? _game.weeklyDate : _game.dailyDate,
            index: _game.isWeekly ? _game.weeklyIndex : _game.dailyIndex,
            layout: _game.roundLayout,
            actions: _game.replayActions,
          )
          .catchError((Object error) {
            if (!mounted) return;
            ScaffoldMessenger.of(context)
                .showSnackBar(SnackBar(content: Text(error.toString())));
          }),
    );
  }

  void _leaderboard() => _sheet(
    'FLIGHT LEAGUE',
    (_) => FlightLeaguePanel(league: _league, reduceMotion: _reduced),
    fit: true,
  );

  void _flightSupport({int initialPage = 1}) => _sheet(
    'FLIGHT SUPPLIES',
    (sheetContext) => EarnedSupplyPanel(
      game: _game,
      initialPage: initialPage,
      canUse: _canPlan,
      canSkip: !_isChallenge && !_game.isReplaying && _canPlan,
      reduceMotion: _reduced,
      onHint: () {
        var used = false;
        _act(() => used = _game.useHintCredit());
        if (used) Navigator.pop(sheetContext);
      },
      onUsePower: (item) {
        var used = false;
        _act(
          () => used = item == PowerUp.timeCell
              ? _game.useTimeCell()
              : _game.useRouteLens(),
        );
        if (used) Navigator.pop(sheetContext);
      },
      onSkip: () {
        final crossing =
            widget.showBriefings &&
            VoyageProgression.forLevel(_game.journeyLevel + 1).planetIndex !=
                VoyageProgression.forLevel(_game.puzzle.levelNumber)
                    .planetIndex;
        var used = false;
        _act(() => used = _game.buySkip());
        if (!used) return;
        if (crossing) {
          _stageBriefing = false;
          _planetFlight = true;
          _syncClock();
        }
        Navigator.pop(sheetContext);
      },
      onLegacyStore: () => _legacyFlightSupport(initialPage: initialPage),
    ),
    fit: true,
  );

  void _legacyFlightSupport({int initialPage = 1}) => _sheet(
    'MISSION RESOURCES',
    (sheetContext) => FlightSupportPanel(
      support: _support,
      initialPage: initialPage,
      canSkip: !_isChallenge && !_game.isReplaying && !_game.status.solved,
      reduceMotion: _reduced,
      onSkip: () {
        final skippedLevel = _levelFields;
        Navigator.pop(sheetContext);
        final planet = VoyageProgression.forLevel(_game.puzzle.levelNumber)
            .planetIndex;
        final crossesPlanet =
            widget.showBriefings &&
            VoyageProgression.forLevel(_game.journeyLevel + 1).planetIndex !=
                planet;
        if (crossesPlanet) {
          _stageBriefing = false;
          _planetFlight = true;
        }
        if (_act(_game.skipCurrentLevel)) _track('level_skip', skippedLevel);
        if (crossesPlanet) _syncClock();
      },
    ),
    fit: true,
  );

  Future<void> _sheet(
    String title,
    Widget Function(BuildContext) content, {
    bool fit = false,
    double? preferredDesktopHeight,
  }) async {
    _panelDepth++;
    _syncClock();
    setState(() {});
    final motion = AnimationController(
      vsync: this,
      duration: _reduced ? Duration.zero : const Duration(milliseconds: 340),
      reverseDuration: _reduced
          ? Duration.zero
          : const Duration(milliseconds: 280),
    );
    final previousMotion = _sheetMotion;
    _sheetMotion = motion;
    await showOrbitPanel(
      context: context,
      title: title,
      builder: content,
      motion: motion,
      fit: fit,
      preferredDesktopHeight: preferredDesktopHeight,
      foldGeometry: _foldGeometry,
      foldCompanionBuilder: (context) => _panelCompanion(title),
    );
    if (motion.status != AnimationStatus.dismissed) {
      final dismissed = Completer<void>();
      void watch(AnimationStatus status) {
        if (status == AnimationStatus.dismissed && !dismissed.isCompleted) {
          dismissed.complete();
        }
      }

      motion.addStatusListener(watch);
      await dismissed.future;
      motion.removeStatusListener(watch);
    }
    if (identical(_sheetMotion, motion)) {
      _sheetMotion = previousMotion?.status != AnimationStatus.dismissed
          ? previousMotion
          : null;
      if (_reduced && _sheetMotion != null) {
        _sheetMotion!.duration = Duration.zero;
        _sheetMotion!.reverseDuration = Duration.zero;
      }
    }
    motion.dispose();
    _panelDepth--;
    if (mounted) {
      _syncClock();
      setState(() {});
    }
  }

  void _map() {
    if (!_game.ready || _panelOpen || _briefingOpen || _flightFailed) return;
    _sampleTiming();
    _clock.pause();
    _game.cancelTrace();
    _voyageHome = true;
    _animateOnward = false;
    _hintIndex = null;
    _act(() => _game.setMode(GameMode.voyage));
    _syncClock();
    setState(() {});
  }

  void _routeLog() => _sheet(
    'FLIGHT LOG',
    (sheetContext) => VoyageRouteLog(
      frontierLevel: _game.journeyLevel,
      currentLevel: _game.puzzle.levelNumber,
      records: _game.routeRecords,
      reduceMotion: _reduced,
      onReplay: (level) {
        _voyageHome = false;
        _act(() => _game.replayLevel(level));
        Navigator.pop(sheetContext);
      },
    ),
    fit: true,
  );

  void _rewards() => _sheet(
    'YOUR COLLECTION',
    (context) => ListenableBuilder(
      listenable: _game,
      builder: (context, _) => RewardsPanel(
        stars: _game.stars,
        equippedTrail: _game.equippedTrail,
        earnedAchievementIds: _game.earnedAchievementIds,
        dailyMedals: _game.dailyMedals,
        weeklyMedals: _game.weeklyMedals,
        coinBalance: _game.coinBalance,
        cargoCollection: _game.cargoCollection,
        powerUps: _game.powerUps,
        initialCargo: _game.lastReward?.cargoId != null,
        initialCargoKind: CargoKind.values
            .where((kind) => kind.name == _game.lastReward?.cargoId)
            .firstOrNull,
        onEquip: (trail) => _act(() => _game.equipTrail(trail)),
        reduceMotion: _reduced,
      ),
    ),
    fit: true,
  );

  void _help() => _sheet(
    'FLIGHT NOTES',
    (context) => FlightManual(
      puzzle: _game.puzzle,
      onClose: () => Navigator.pop(context),
      reduceMotion: _reduced,
    ),
    fit: true,
  );

  Future<void> _restartPrompt() async {
    _panelDepth++;
    _syncClock();
    setState(() {});
    final restart = await Navigator.of(context).push(
      FoldDialogRoute<bool>(
        barrierDismissible: true,
        barrierLabel: 'Keep playing',
        barrierColor: Colors.black54,
        transitionDuration: _reduced
            ? Duration.zero
            : const Duration(milliseconds: 260),
        transitionBuilder: (context, animation, secondary, child) {
          final eased = animation.drive(
            CurveTween(curve: Curves.easeInOutCubic),
          );
          return FadeTransition(
            opacity: eased,
            child: ScaleTransition(
              scale: eased.drive(Tween(begin: .97, end: 1.0)),
              child: child,
            ),
          );
        },
        pageBuilder: (context, animation, secondary) =>
            ValueListenableBuilder<FoldGeometry>(
              valueListenable: _foldGeometry,
              builder: (context, geometry, _) {
                final media = MediaQuery.of(context);
                final panes = FoldPaneLayout.resolve(media, geometry);
                if (panes == null) return _restartDialog(context);
                Widget pane(Rect rect, String key, WidgetBuilder builder) =>
                    Positioned.fromRect(
                      rect: rect,
                      child: ClipRect(
                        key: ValueKey(key),
                        child: MediaQuery(
                          data: FoldPaneLayout.paneMediaQuery(media, rect),
                          child: Builder(builder: builder),
                        ),
                      ),
                    );
                return Stack(
                  children: [
                    pane(
                      panes.missionRect,
                      'fold-restart-companion',
                      (_) => _panelCompanion('RESTART ROUTE'),
                    ),
                    pane(
                      panes.actionRect,
                      'fold-restart-actions',
                      _restartDialog,
                    ),
                  ],
                );
              },
            ),
      ),
    );
    _panelDepth--;
    if (!mounted) return;
    if (restart == true) {
      _lastPressureSecond = null;
      _flightFailed = false;
      _act(_game.restart);
    }
    _syncClock();
  }

  Widget _restartDialog(BuildContext context) {
    final compact = MediaQuery.textScalerOf(context).scale(1) > 1.5;
    final viewport = MediaQuery.sizeOf(context);
    final sideBySide = viewport.width >= 640 && viewport.height < 500;
    final summary = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          compact ? 'Restart?' : 'Restart route?',
          style: bookTitle(compact ? (sideBySide ? 14 : 18) : 26),
        ),
        const SizedBox(height: 12),
        Text(
          compact
              ? 'Turns & hints reset. Voyage saved.'
              : 'Turns and hints reset. Your voyage stays saved.',
          style: TextStyle(
            color: Palette.secondary,
            fontSize: compact ? (sideBySide ? 11 : 12) : 15,
            height: 1.4,
          ),
        ),
      ],
    );
    final actions = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SpaceAction(
          key: const ValueKey('confirm-restart'),
          onPressed: () => Navigator.pop(context, true),
          icon: Icons.refresh_rounded,
          label: 'Restart',
          compact: compact,
          reduceMotion: _reduced,
        ),
        const SizedBox(height: 8),
        SpaceAction(
          key: const ValueKey('cancel-restart'),
          onPressed: () => Navigator.pop(context, false),
          label: compact ? 'Cancel' : 'Keep playing',
          quiet: true,
          compact: true,
          reduceMotion: _reduced,
        ),
      ],
    );
    return Dialog(
      key: const ValueKey('restart-dialog'),
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: sideBySide ? 720 : 440),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Palette.board,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Palette.line, width: .8),
          ),
          child: Padding(
            padding: EdgeInsets.all(sideBySide ? 20 : 24),
            child: sideBySide
                ? Row(
                    children: [
                      Expanded(child: summary),
                      const SizedBox(width: 24),
                      Expanded(child: actions),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [summary, const SizedBox(height: 24), actions],
                  ),
          ),
        ),
      ),
    );
  }

  void _settings() => _sheet(
    'FLIGHT CONTROLS',
    (sheetContext) => FlightSettings(
      game: _game,
      demo: _league.isMock,
      onRestart: () {
        Navigator.pop(sheetContext);
        _restartPrompt();
      },
      onSupport: () {
        Navigator.pop(sheetContext);
        _flightSupport();
      },
      onLeague: () {
        Navigator.pop(sheetContext);
        _leaderboard();
      },
      onRewards: () {
        Navigator.pop(sheetContext);
        _rewards();
      },
      onLicenses: () => _sheet(
        'CREDITS & LICENSES',
        (context) => Navigator(
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (_) => const LicensePage(
              applicationName: 'Glowpath',
              applicationVersion: '0.11.3',
            ),
          ),
        ),
        fit: true,
      ),
    ),
    fit: true,
    preferredDesktopHeight: 620,
  );
}
