import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'puzzle.dart';
import 'rewards.dart';
import 'voyage_progression.dart';
import 'voyage_records.dart';
import 'cargo.dart';
import 'challenge_run.dart';

export 'rewards.dart';
export 'voyage_records.dart';
export 'cargo.dart';
export 'challenge_run.dart';

/// One reversible action. Assistance stays sticky when an action is undone.
class GameMove {
  const GameMove({required this.puzzle, required this.moves});

  final Puzzle puzzle;
  final int moves;
}

/// Gameplay and one atomic, versioned local save. UI effects belong to the UI.
class GameController extends ChangeNotifier {
  GameController({
    SharedPreferences? preferences,
    DateTime Function()? now,
    Future<bool> Function(String snapshot)? snapshotWriter,
  }) : this._(preferences, now ?? DateTime.now, snapshotWriter);

  // Preserve the public injection names while initializing private fields.
  GameController._(this._preferences, this._now, this._snapshotWriter) {
    _dailyDate = _date(_now());
    _weeklyDate = _weekDate(_now());
    _startRound(refreshDate: false);
  }

  static const storageKey = 'glowpath.snapshot.v1';
  static const _schemaVersion = 1;
  static const _generatedLayout = 'generated-v2';
  static const _introductionLayout = 'intro-v1';
  static const _voyageLayout = 'voyage-v3';
  static const _planetLayout = 'planet-v4';
  static const _strategicLayout = 'planet-v5';
  static const _bountyLayout = 'bounty-v6';

  SharedPreferences? _preferences;
  final DateTime Function() _now;
  final Future<bool> Function(String snapshot)? _snapshotWriter;
  Future<void>? _loading;
  Future<void> _saveQueue = Future<void>.value();
  bool _disposed = false;
  bool _ready = false;
  bool _saveError = false;
  late Puzzle _puzzle;
  late Puzzle _initialPuzzle;
  int _journeyLevel = 1;
  int _dailyIndex = 0;
  late String _dailyDate;
  late String _weeklyDate;
  int _weeklyIndex = 0;
  Difficulty _difficulty = Difficulty.balanced;
  Difficulty _roundDifficulty = Difficulty.balanced;
  String _roundLayout = _generatedLayout;
  Map<String, dynamic>? _journeySlot;
  Map<String, dynamic>? _dailySlot;
  Map<String, dynamic>? _weeklySlot;
  GameMode _mode = GameMode.voyage;
  bool get _isDaily => _mode == GameMode.daily;
  bool get _isWeekly => _mode == GameMode.weekly;
  int _moves = 0;
  bool _assisted = false;
  bool _recorded = false;
  int _stars = 0;
  int _best = 0;
  bool _reduceMotion = false;
  bool _highContrast = false;
  bool _haptics = true;
  bool _onboardingSeen = false;
  final Set<String> _introducedRules = {};
  int _voyageClears = 0, _skippedVoyage = 0;
  final List<int> _replayActions = [];
  bool _hasVerifiedReplay = true;
  int? _lastChangedTile;
  final List<GameMove> _history = [];
  Puzzle? _traceOrigin;
  TracePlan? _tracePlan;
  final Set<int> _dailyCompleted = {};
  final Set<int> _weeklyCompleted = {};
  final Set<String> _earnedAchievements = {};
  final Map<String, int> _dailyClaims = {}, _weeklyClaims = {};
  final Map<String, ChallengeRunSummary> _challengeRuns = {};
  final Set<String> _dailyMedalDates = {}, _weeklyMedalDates = {};
  String _dailyClaimFloor = '', _weeklyClaimFloor = '';
  int _dailyMedals = 0, _weeklyMedals = 0;
  ShipTrail _equippedTrail = ShipTrail.starlight;
  CompletionReward? _lastReward;
  final Map<int, RouteRecord> _routeRecords = {};
  final Map<PowerUp, int> _powerUps = {};
  final Map<CargoKind, int> _cargoCollection = {};
  final Set<String> _cargoClaims = {};
  int _coins = 0, _hintCredits = 0, _attemptRevision = 0;
  int? _replayLevel;
  Map<String, dynamic>? _frontierSlot;
  Duration _attemptElapsed = Duration.zero,
      _attemptBudget = Duration.zero,
      _attemptExtraTime = Duration.zero;
  bool _timingEligible = true, _timingKnown = false, _timeCellUsed = false;
  bool _timingDirty = false;
  int _retryCount = 0, _lastTimingSaveSecond = -1;
  int? _timeCellRetry;
  bool _challengeCleanEligible = true;
  CargoEncounter? _currentCargo;

  Map<int, RouteRecord> get routeRecords => Map.unmodifiable(_routeRecords);
  RouteRecord? recordForLevel(int level) => _routeRecords[level];
  int get bestTimedScore => _routeRecords.isEmpty
      ? _best
      : _routeRecords.values.map((record) => record.bestScore).reduce(math.max);
  int get coinBalance => _coins;
  int get hintCredits => _hintCredits;
  Map<PowerUp, int> get powerUps => Map.unmodifiable(_powerUps);
  int powerUpCount(PowerUp item) => _powerUps[item] ?? 0;
  Map<CargoKind, int> get cargoCollection => Map.unmodifiable(_cargoCollection);
  CargoEncounter? get currentCargo => _currentCargo;
  bool get currentCargoClaimed =>
      _currentCargo != null && _cargoClaims.contains(_currentCargo!.claimKey);
  bool get isReplaying => _mode == GameMode.voyage && _replayLevel != null;
  Duration get attemptElapsed => _attemptElapsed;
  Duration get attemptBudget => _attemptBudget;
  Duration get attemptExtraTime => _attemptExtraTime;

  /// The visible launch gauge describes this window, not cumulative retries.
  /// Scoring still uses [attemptBudget] and all [attemptElapsed].
  Duration get attemptWindowBudget =>
      _attemptBudget +
      (_timeCellUsed && _timeCellRetry == _retryCount
          ? const Duration(seconds: 8)
          : Duration.zero);
  int get attemptRevision => _attemptRevision;
  int get retryCount => _retryCount;

  /// Honor the budget of an already active saved stage across upgrades.
  Duration get challengeLaunchBudget => _mode == GameMode.voyage
      ? Duration.zero
      : _attemptBudget > Duration.zero
      ? _attemptBudget
      : challengeStageBudget(_mode, _isDaily ? _dailyIndex : _weeklyIndex);

  ChallengeRunSummary? get challengeRunSummary {
    if (_mode == GameMode.voyage) return null;
    final period = _isDaily ? _dailyDate : _weeklyDate;
    final key = '${_mode.name}/$period';
    return _challengeRuns.putIfAbsent(key, () {
      final claims = (_isDaily ? _dailyClaims : _weeklyClaims)[period] ?? 0;
      final completed = _isDaily ? _dailyCompleted : _weeklyCompleted;
      final count = _isDaily ? 3 : 5;
      return ChallengeRunSummary(
        mode: _mode,
        period: period,
        stageRecords: {
          for (var index = 0; index < count; index++)
            if (completed.contains(index) || claims & (1 << index) != 0)
              index: ChallengeStageRecord(index: index),
        },
      );
    });
  }

  void _storeChallengeRun(ChallengeRunSummary run) {
    _challengeRuns['${run.mode.name}/${run.period}'] = run;
    // Keep recent summaries without weakening the existing lifetime claim floors.
    for (final mode in [GameMode.daily, GameMode.weekly]) {
      final keys =
          _challengeRuns.keys
              .where((key) => key.startsWith('${mode.name}/'))
              .toList()
            ..sort();
      final keep = mode == GameMode.daily ? 180 : 104;
      for (final key in keys.take(math.max(0, keys.length - keep))) {
        _challengeRuns.remove(key);
      }
    }
  }

  void _breakChallengeStreak({bool retry = false}) {
    final run = challengeRunSummary;
    if (run == null) return;
    _challengeCleanEligible = false;
    // Practice of an already recorded stage cannot rewrite the period result.
    if (run.stageRecords.containsKey(_isDaily ? _dailyIndex : _weeklyIndex)) {
      return;
    }
    _storeChallengeRun(run.breakStreak(retry: retry));
  }

  bool get hasTimedAttempt => _timingEligible && _timingKnown;
  int get timedScore {
    final base = _puzzle.scoreForMoves(_moves);
    if (!hasTimedAttempt || _attemptBudget.inMilliseconds <= 0) return base;
    final ratio =
        (_attemptElapsed.inMilliseconds / _attemptBudget.inMilliseconds).clamp(
          0.0,
          1.0,
        );
    return (base + (800 * (1 - ratio)).round()).clamp(0, 1000);
  }

  /// UI passes cumulative active solving time. Briefings/panels/background time
  /// are excluded by its monotonic clock. This never recursively notifies UI.
  void updateAttemptTiming(Duration elapsed, Duration budget) {
    if (!_canPlay ||
        elapsed.isNegative ||
        budget <= Duration.zero ||
        budget > const Duration(minutes: 10) ||
        elapsed > const Duration(days: 1)) {
      return;
    }
    _attemptElapsed = elapsed > _attemptElapsed ? elapsed : _attemptElapsed;
    if (_attemptBudget == Duration.zero) _attemptBudget = budget;
    _timingKnown = true;
    _timingDirty = true;
    if (_mode != GameMode.voyage &&
        _challengeCleanEligible &&
        _attemptElapsed >= _attemptBudget + _attemptExtraTime) {
      // The failure itself ends the streak, even if the player leaves the
      // timeout screen without pressing Retry. UI owns the failure animation.
      _breakChallengeStreak();
    }
    final second = _attemptElapsed.inSeconds;
    if (second != _lastTimingSaveSecond) {
      _lastTimingSaveSecond = second;
      _enqueueSave();
    }
  }

  /// Retry preserves the edited board and all time already spent. A new launch
  /// window cannot create a falsely fast personal best or refresh time bonus.
  bool retryAfterTimeout() {
    if (!_canPlay ||
        !_timingKnown ||
        _attemptBudget == Duration.zero ||
        _attemptElapsed < _attemptBudget + _attemptExtraTime) {
      return false;
    }
    if (_mode != GameMode.voyage) {
      final retries = _retryCount + 1;
      _breakChallengeStreak(retry: true);
      _restartBoard();
      _retryCount = retries;
      _challengeCleanEligible = false;
      _changed();
      return true;
    }
    _attemptExtraTime += _attemptBudget;
    _retryCount++;
    _changed();
    return true;
  }

  bool replayLevel(int level) {
    if (!_ready || _disposed || level < 1 || level >= _journeyLevel) {
      return false;
    }
    cancelTrace();
    if (_mode != GameMode.voyage) setMode(GameMode.voyage);
    if (!isReplaying) {
      // A completed arrival is not an unfinished route to resume. Starting
      // history there should return directly to the actual unlocked frontier.
      _frontierSlot = status.solved ? null : _slotSnapshot();
    }
    _replayLevel = level;
    _startRound(refreshDate: false);
    _changed();
    return true;
  }

  bool returnToFrontier() {
    if (!_ready || _disposed || !isReplaying) return false;
    cancelTrace();
    final parked = _frontierSlot;
    final parkedRound = parked?['round'];
    _frontierSlot = null;
    _replayLevel = null;
    if (parked == null ||
        parkedRound is! Map<String, dynamic> ||
        parkedRound['recorded'] == true ||
        parkedRound['replay'] == true ||
        !_restoreSlot(parked)) {
      _startRound(refreshDate: false);
    }
    _changed();
    return true;
  }

  bool buyHint() {
    if (!_ready || _disposed || _coins < 10) return false;
    _coins -= 10;
    _hintCredits++;
    _changed();
    return true;
  }

  bool consumeHintCredit() {
    if (!_canPlay || _hintCredits <= 0) return false;
    _hintCredits--;
    _assisted = true;
    _changed();
    return true;
  }

  /// One save contains both the consumed credit and the applied legal turn.
  bool useHintCredit() {
    if (!_canPlay || _hintCredits <= 0 || suggestedHintIndex == null) {
      return false;
    }
    _hintCredits--;
    return hint();
  }

  bool buySkip() {
    if (!_canPlay || _mode != GameMode.voyage || isReplaying || _coins < 75) {
      return false;
    }
    _coins -= 75;
    return skipCurrentLevel();
  }

  bool buyPowerUp(PowerUp item) {
    if (!_ready || _disposed || _coins < item.cost) return false;
    _coins -= item.cost;
    _powerUps[item] = powerUpCount(item) + 1;
    _changed();
    return true;
  }

  bool get canUseTimeCell =>
      _canPlay &&
      !_timeCellUsed &&
      powerUpCount(PowerUp.timeCell) > 0 &&
      _attemptBudget > Duration.zero &&
      _attemptElapsed < _attemptBudget + _attemptExtraTime;
  bool useTimeCell() {
    if (!canUseTimeCell) return false;
    _powerUps[PowerUp.timeCell] = powerUpCount(PowerUp.timeCell) - 1;
    _attemptExtraTime += const Duration(seconds: 8);
    _timeCellUsed = true;
    _timeCellRetry = _retryCount;
    _assisted = true;
    _changed();
    return true;
  }

  bool useRouteLens() {
    if (!_canPlay ||
        powerUpCount(PowerUp.routeLens) <= 0 ||
        suggestedHintIndex == null) {
      return false;
    }
    _powerUps[PowerUp.routeLens] = powerUpCount(PowerUp.routeLens) - 1;
    cancelTrace();
    _rememberMove();
    _assisted = true;
    for (var step = 0; step < 3 && !status.solved; step++) {
      final index = suggestedHintIndex;
      if (index == null) break;
      final turns = _puzzle.solutionActions
          .where((action) => action == index)
          .length;
      for (var turn = 0; turn < turns; turn++) {
        _puzzle = _puzzle.rotateAt(index);
        _replayActions.add(index);
      }
      _moves += turns;
      _lastChangedTile = index;
    }
    _checkCompletion();
    _changed();
    return true;
  }

  bool get ready => _ready;
  bool get saveError => _saveError;
  Puzzle get puzzle => _puzzle;
  PuzzleStatus get status => _puzzle.evaluate();
  int get journeyLevel => _journeyLevel;
  int get dailyIndex => _dailyIndex;
  GameMode get mode => _mode;
  bool get isWeekly => _isWeekly;
  int get weeklyIndex => _weeklyIndex;
  String get weeklyDate => _weeklyDate;
  Set<int> get weeklyCompleted => Set.unmodifiable(_weeklyCompleted);

  /// A parked challenge keeps its original period until its next route starts.
  /// The UI can offer the new period without discarding an unfinished board.
  bool get hasNewChallenge => switch (_mode) {
    GameMode.voyage => false,
    GameMode.daily => _date(_now()) != _dailyDate,
    GameMode.weekly => _weekDate(_now()) != _weeklyDate,
  };
  int get nextChallengeIndex => hasNewChallenge
      ? 0
      : switch (_mode) {
          GameMode.voyage => 0,
          GameMode.daily => (_dailyIndex + 1) % 3,
          GameMode.weekly => (_weeklyIndex + 1) % 5,
        };
  int get nextChallengeLevel => switch (_mode) {
    GameMode.voyage => _journeyLevel,
    GameMode.daily => VoyageProgression.dailyLevel(nextChallengeIndex),
    GameMode.weekly => VoyageProgression.weeklyLevel(nextChallengeIndex),
  };
  bool get isProgressionRound => _roundLayout == _voyageLayout || isPlanetRound;
  bool get isPlanetRound =>
      _roundLayout == _planetLayout ||
      _roundLayout == _strategicLayout ||
      _roundLayout == _bountyLayout;
  String get roundLayout => _roundLayout;
  bool get onboardingSeen => _onboardingSeen;
  bool knowsRule(String title) => _introducedRules.contains(title);
  bool introduceRules(Iterable<String> titles) {
    if (!_ready || _disposed) return false;
    final before = _introducedRules.length;
    _introducedRules.addAll(titles.where((title) => title.length <= 80));
    if (before == _introducedRules.length) return false;
    _changed();
    return true;
  }

  int get voyageClears => _voyageClears;
  int get skippedVoyage => _skippedVoyage;
  List<int> get replayActions => List.unmodifiable(_replayActions);
  bool get hasVerifiedReplay => _hasVerifiedReplay;
  bool markOnboardingSeen() {
    if (!_ready || _disposed || _onboardingSeen) return false;
    _onboardingSeen = true;
    _changed();
    return true;
  }

  /// Skips grant no stars, score, medal, achievement or competitive replay.
  bool skipCurrentLevel() {
    if (!_canPlay || _mode != GameMode.voyage || isReplaying) return false;
    _skippedVoyage++;
    _journeyLevel = math.max(_journeyLevel, _puzzle.levelNumber + 1);
    _startRound(refreshDate: false);
    _changed();
    return true;
  }

  int get dailyMedals => _dailyMedals;
  int get weeklyMedals => _weeklyMedals;
  ShipTrail get equippedTrail => _equippedTrail;
  ShipTrail get selectedTrail => _equippedTrail;
  List<ShipTrail> get unlockedTrails => List.unmodifiable(
    ShipTrail.values.where((trail) => _stars >= trail.requiredStars),
  );
  ShipTrail? get nextTrail {
    for (final trail in ShipTrail.values) {
      if (_stars < trail.requiredStars) return trail;
    }
    return null;
  }

  Set<String> get earnedAchievementIds => Set.unmodifiable(_earnedAchievements);
  List<Achievement> get achievements => List.unmodifiable(
    achievementCatalog.where((a) => _earnedAchievements.contains(a.id)),
  );
  CompletionReward? get lastReward => _lastReward;

  bool equipTrail(ShipTrail trail) {
    if (!_ready ||
        _disposed ||
        _stars < trail.requiredStars ||
        trail == _equippedTrail) {
      return false;
    }
    _equippedTrail = trail;
    _changed();
    return true;
  }

  bool setTrail(ShipTrail trail) => equipTrail(trail);

  /// UTC date of the current daily set. An active round keeps this date even
  /// across midnight and app restarts; entering the next round refreshes it.
  String get dailyDate => _dailyDate;
  Difficulty get difficulty => _difficulty;
  Difficulty get roundDifficulty => _roundDifficulty;
  bool get isIntroduction =>
      _roundLayout == _introductionLayout ||
      (_roundLayout == _voyageLayout &&
          _mode == GameMode.voyage &&
          _puzzle.levelNumber <= 5);
  bool get isDaily => _isDaily;
  int get moves => _moves;
  bool get assisted => _assisted;
  int get stars => _stars;
  int get best => _best;
  bool get reduceMotion => _reduceMotion;
  bool get highContrast => _highContrast;
  bool get haptics => _haptics;
  int? get lastChangedTile => _lastChangedTile;
  bool get canUndo => _canPlay && _history.isNotEmpty;
  bool get canRestart =>
      _canPlay && (_moves > 0 || _assisted || _attemptElapsed > Duration.zero);
  int get historyLength => _history.length;
  List<GameMove> get history => List<GameMove>.unmodifiable(_history);
  Set<int> get dailyCompleted => Set<int>.unmodifiable(_dailyCompleted);
  bool get _canPlay => _ready && !_disposed && !status.solved;

  /// Drag previews never enter saves, scoring, completion or competitive logs.
  Puzzle? get tracePreview => _tracePlan?.puzzle;
  bool get isTracing => _traceOrigin != null;

  bool beginTrace() {
    if (!_canPlay) return false;
    _traceOrigin = _puzzle;
    _tracePlan = null;
    notifyListeners();
    return true;
  }

  bool updateTrace(List<int> cells) {
    final origin = _traceOrigin;
    if (origin == null || !identical(origin, _puzzle) || !_canPlay) {
      return false;
    }
    final plan = origin.planTrace(cells);
    if (!plan.accepted) return false;
    _tracePlan = plan;
    notifyListeners();
    return true;
  }

  bool endTrace() {
    final origin = _traceOrigin, plan = _tracePlan;
    _traceOrigin = null;
    _tracePlan = null;
    if (origin == null ||
        !identical(origin, _puzzle) ||
        !_canPlay ||
        plan == null ||
        plan.actions.isEmpty) {
      if (origin != null && !_disposed) notifyListeners();
      return false;
    }
    _rememberMove();
    _puzzle = plan.puzzle;
    _moves += plan.actions.length;
    _replayActions.addAll(plan.actions);
    _lastChangedTile = plan.actions.last;
    _checkCompletion();
    _changed();
    return true;
  }

  void cancelTrace() {
    if (_traceOrigin == null) return;
    _traceOrigin = null;
    _tracePlan = null;
    if (!_disposed) notifyListeners();
  }

  /// Idempotent initialization. Actions remain disabled until it finishes.
  /// Schedule the body after assigning the future, so ready listeners can
  /// safely call load or flush even when preferences were injected.
  Future<void> load() => _loading ??= Future<void>.microtask(_load);

  Future<void> _load() async {
    if (_disposed) return;
    try {
      _preferences ??= await SharedPreferences.getInstance();
      if (_disposed) return;
      final stored = _preferences!.get(storageKey);
      var restored = false;
      if (stored is String) {
        try {
          final decoded = jsonDecode(stored);
          if (decoded is Map<String, dynamic> &&
              decoded['schemaVersion'] == _schemaVersion) {
            _restoreProgress(decoded);
            restored = true;
            if (decoded['generatorVersion'] != puzzleGeneratorVersion) {
              _journeySlot = null;
              _dailySlot = null;
              _weeklySlot = null;
              _startRound(refreshDate: true);
            } else if (!_restoreRound(decoded['round'])) {
              _startRound(refreshDate: true);
            }
            switch (_mode) {
              case GameMode.voyage:
                _journeySlot = null;
              case GameMode.daily:
                _dailySlot = null;
              case GameMode.weekly:
                _weeklySlot = null;
            }
          }
        } on FormatException {
          // A malformed save must not make the game unplayable.
        }
      }
      if (!restored) {
        _migrateLegacy();
        _startRound(refreshDate: true);
      }
    } catch (_) {
      _saveError = true;
    }
    if (_disposed) return;
    _ready = true;
    _enqueueSave();
    notifyListeners();
  }

  bool rotate(int index) {
    cancelTrace();
    if (!_canPlay ||
        index < 0 ||
        index >= _puzzle.tiles.length ||
        _puzzle.tiles[index].isLocked) {
      return false;
    }
    _rememberMove();
    _puzzle = _puzzle.rotateAt(index);
    _replayActions.add(index);
    _lastChangedTile = index;
    _moves++;
    _checkCompletion();
    _changed();
    return true;
  }

  bool undo() {
    cancelTrace();
    if (!canUndo) return false;
    _breakChallengeStreak();
    final previous = _history.removeLast();
    _puzzle = previous.puzzle;
    _moves = previous.moves;
    if (_replayActions.length >= _moves) _replayActions.length = _moves;
    _lastChangedTile = null;
    _changed();
    return true;
  }

  /// Replays the exact original board; it does not refresh an old daily date.
  bool restart() {
    cancelTrace();
    if (!canRestart) return false;
    final retries = _retryCount + 1;
    _breakChallengeStreak(retry: true);
    _restartBoard();
    if (_mode != GameMode.voyage) {
      _retryCount = retries;
      _challengeCleanEligible = false;
    }
    _changed();
    return true;
  }

  void _restartBoard() {
    _traceOrigin = null;
    _tracePlan = null;
    _puzzle = _initialPuzzle;
    _replayActions.clear();
    _hasVerifiedReplay = true;
    _moves = 0;
    _assisted = false;
    _history.clear();
    _lastChangedTile = null;
    _resetAttempt();
  }

  /// The next reference-route correction, without mutating the round.
  int? get suggestedHintIndex {
    if (!_canPlay) return null;
    final actions = _puzzle.solutionActions;
    if (actions.isEmpty) return null;
    final route = _puzzle.solvedCopy().evaluate().route;
    final blocked = status.blockedAt;
    if (actions.contains(blocked)) return blocked;
    for (final cell in route) {
      if (actions.contains(cell)) return cell;
    }
    return actions.first;
  }

  /// Reveals where to look. The player still makes the turn themselves.
  bool requestHint() {
    cancelTrace();
    if (suggestedHintIndex == null) return false;
    _assisted = true;
    _changed();
    return true;
  }

  /// Explicit second-stage assistance: turn the suggested tile into place.
  bool hint() {
    cancelTrace();
    final index = suggestedHintIndex;
    if (index == null) return false;
    final turns = _puzzle.solutionActions
        .where((action) => action == index)
        .length;
    _rememberMove();
    for (var turn = 0; turn < turns; turn++) {
      _puzzle = _puzzle.rotateAt(index);
      _replayActions.add(index);
    }
    _moves += turns;
    _lastChangedTile = index;
    _assisted = true;
    _checkCompletion();
    _changed();
    return true;
  }

  /// Advances only after completion, so accidental calls cannot skip a round.
  bool nextPuzzle() {
    cancelTrace();
    if (!_ready || _disposed || !status.solved) return false;
    if (isReplaying) return returnToFrontier();
    if (_isDaily) {
      if (!_refreshDate()) _dailyIndex = (_dailyIndex + 1) % 3;
    } else if (_isWeekly) {
      if (!_refreshWeek()) _weeklyIndex = (_weeklyIndex + 1) % 5;
    }
    _startRound(refreshDate: false);
    _changed();
    return true;
  }

  bool setDaily(bool daily) =>
      setMode(daily ? GameMode.daily : GameMode.voyage);
  bool setWeekly(bool weekly) =>
      setMode(weekly ? GameMode.weekly : GameMode.voyage);

  bool setMode(GameMode mode) {
    cancelTrace();
    if (!_ready || _disposed || _mode == mode) return false;
    switch (_mode) {
      case GameMode.voyage:
        _journeySlot = _slotSnapshot();
      case GameMode.daily:
        _dailySlot = _slotSnapshot();
      case GameMode.weekly:
        _weeklySlot = _slotSnapshot();
    }
    _mode = mode;
    _replayLevel = null;
    final slot = switch (mode) {
      GameMode.voyage => _journeySlot,
      GameMode.daily => _dailySlot,
      GameMode.weekly => _weeklySlot,
    };
    final resumed = slot != null && _restoreSlot(slot);
    switch (mode) {
      case GameMode.voyage:
        _journeySlot = null;
      case GameMode.daily:
        _dailySlot = null;
      case GameMode.weekly:
        _weeklySlot = null;
    }
    if (!resumed) {
      if (_isDaily) {
        _refreshDate();
        _dailyIndex = [0, 1, 2].firstWhere(
          (index) => !_dailyCompleted.contains(index),
          orElse: () => 0,
        );
      } else if (_isWeekly) {
        _refreshWeek();
        _weeklyIndex = [0, 1, 2, 3, 4].firstWhere(
          (index) => !_weeklyCompleted.contains(index),
          orElse: () => 0,
        );
      }
      _startRound(refreshDate: false);
    }
    _changed();
    return true;
  }

  bool setDifficulty(Difficulty difficulty) {
    if (!_ready || _disposed || _difficulty == difficulty) return false;
    _difficulty = difficulty;
    // Challenges have a shared fixed difficulty. Changing the Voyage
    // preference does not disturb a challenge already in progress.
    if (_mode == GameMode.voyage) _startRound(refreshDate: true);
    _changed();
    return true;
  }

  bool setReduceMotion(bool value) {
    if (!_ready || _disposed || _reduceMotion == value) return false;
    _reduceMotion = value;
    _changed();
    return true;
  }

  bool setHighContrast(bool value) {
    if (!_ready || _disposed || _highContrast == value) return false;
    _highContrast = value;
    _changed();
    return true;
  }

  bool setHaptics(bool value) {
    if (!_ready || _disposed || _haptics == value) return false;
    _haptics = value;
    _changed();
    return true;
  }

  void _rememberMove() =>
      _history.add(GameMove(puzzle: _puzzle, moves: _moves));

  void _checkCompletion() {
    if (_recorded || !status.solved) return;
    _recorded = true;
    final previousStars = _stars;
    // Capture before claim bits change, so this new clear is not mistaken for
    // an untimed legacy result while seeding a previously unseen summary.
    final challenge = challengeRunSummary;
    final claimed = _claimRoute();
    final score = timedScore;
    final completedTime = hasTimedAttempt && _attemptElapsed > Duration.zero
        ? _attemptElapsed
        : null;
    if (claimed && challenge != null) {
      _storeChallengeRun(
        challenge.record(
          ChallengeStageRecord(
            index: _isDaily ? _dailyIndex : _weeklyIndex,
            score: score,
            elapsed: completedTime,
            assisted: _assisted,
            clean:
                _challengeCleanEligible &&
                !_assisted &&
                _retryCount == 0 &&
                completedTime != null,
            retries: _retryCount,
            earnedStars: 3,
            coinsEarned: 20 + score ~/ 100,
          ),
        ),
      );
    }
    var earnedCoins = claimed ? 20 : 0;
    var personalBest = false;
    if (_mode == GameMode.voyage) {
      final level = _puzzle.levelNumber;
      final previous = _routeRecords[level];
      final previousTier = previous?.rewardedTier ?? 0;
      final tier = math.max(previousTier, score ~/ 100);
      earnedCoins += tier - previousTier;
      final betterScore =
          previous == null ||
          score > previous.bestScore ||
          (score == previous.bestScore &&
              previous.bestScoreAssisted &&
              !_assisted);
      final betterTime =
          completedTime != null &&
          (previous?.bestTime == null ||
              completedTime < previous!.bestTime! ||
              (completedTime == previous.bestTime &&
                  previous.bestTimeAssisted &&
                  !_assisted));
      personalBest = previous != null && (betterScore || betterTime);
      _routeRecords[level] = RouteRecord(
        level: level,
        bestScore: betterScore ? score : previous.bestScore,
        bestTime: betterTime ? completedTime : previous?.bestTime,
        bestScoreAssisted: betterScore ? _assisted : previous.bestScoreAssisted,
        bestTimeAssisted: betterTime
            ? _assisted
            : previous?.bestTimeAssisted ?? false,
        clears: (previous?.clears ?? 0) + 1,
        rewardedTier: tier,
        layout: _roundLayout,
        difficulty: _roundDifficulty,
      );
    } else if (claimed) {
      earnedCoins += score ~/ 100;
    }
    final cargo = _currentCargo;
    String? collectedCargo;
    if (cargo != null &&
        status.route.contains(cargo.cell) &&
        _cargoClaims.add(cargo.claimKey)) {
      collectedCargo = cargo.kind.name;
      _cargoCollection[cargo.kind] = (_cargoCollection[cargo.kind] ?? 0) + 1;
      earnedCoins += cargo.kind.isRare ? 25 : 10;
      final power = switch (cargo.kind.power) {
        CargoPower.time => PowerUp.timeCell,
        CargoPower.lens => PowerUp.routeLens,
        CargoPower.none => null,
      };
      if (power != null) _powerUps[power] = powerUpCount(power) + 1;
    }
    _coins = (_coins + earnedCoins).clamp(0, 1000000000);
    if (claimed) {
      _stars += 3;
      if (_mode == GameMode.voyage) _voyageClears++;
    }
    if (!_assisted) _best = math.max(_best, _puzzle.scoreForMoves(_moves));
    var dailyMedal = false, weeklyMedal = false;
    if (_isDaily) {
      _dailyCompleted.add(_dailyIndex);
      if (_dailyCompleted.length == 3 &&
          _dailyDate.compareTo(_dailyClaimFloor) > 0 &&
          _dailyMedalDates.add(_dailyDate)) {
        _dailyMedals++;
        dailyMedal = true;
      }
    } else if (_isWeekly) {
      _weeklyCompleted.add(_weeklyIndex);
      if (_weeklyCompleted.length == 5 &&
          _weeklyDate.compareTo(_weeklyClaimFloor) > 0 &&
          _weeklyMedalDates.add(_weeklyDate)) {
        _weeklyMedals++;
        weeklyMedal = true;
      }
    } else {
      _journeyLevel = math.max(_journeyLevel, _puzzle.levelNumber + 1);
    }
    final previousAchievements = _earnedAchievements.toSet();
    _syncAchievements();
    final newTrails = ShipTrail.values
        .where(
          (trail) =>
              previousStars < trail.requiredStars &&
              _stars >= trail.requiredStars,
        )
        .toList();
    if (newTrails.isNotEmpty) _equippedTrail = newTrails.last;
    _lastReward = CompletionReward(
      earnedStars: claimed ? 3 : 0,
      newAchievements: List.unmodifiable(
        _earnedAchievements.difference(previousAchievements),
      ),
      newTrails: List.unmodifiable(newTrails),
      dailyMedal: dailyMedal,
      weeklyMedal: weeklyMedal,
      score: score,
      elapsedMilliseconds: completedTime?.inMilliseconds,
      coinsEarned: earnedCoins,
      cargoId: collectedCargo,
      newPersonalBest: personalBest,
    );
  }

  bool _claimRoute() {
    if (_mode == GameMode.voyage) return _puzzle.levelNumber >= _journeyLevel;
    final claims = _isDaily ? _dailyClaims : _weeklyClaims;
    final date = _isDaily ? _dailyDate : _weeklyDate;
    final index = _isDaily ? _dailyIndex : _weeklyIndex;
    final floor = _isDaily ? _dailyClaimFloor : _weeklyClaimFloor;
    if (date.compareTo(floor) <= 0) return false;
    final bit = 1 << index;
    if (((claims[date] ?? 0) & bit) != 0) return false;
    claims[date] = (claims[date] ?? 0) | bit;
    _trimClaims();
    return true;
  }

  void _trimClaims() {
    void trim(
      Map<String, int> claims,
      Set<String> medalDates,
      int limit,
      bool daily,
    ) {
      final dates = {...claims.keys, ...medalDates}.toList()..sort();
      for (final date in dates.take(math.max(0, dates.length - limit))) {
        claims.remove(date);
        medalDates.remove(date);
        if (daily) {
          if (date.compareTo(_dailyClaimFloor) > 0) _dailyClaimFloor = date;
        } else {
          if (date.compareTo(_weeklyClaimFloor) > 0) _weeklyClaimFloor = date;
        }
      }
      final floor = daily ? _dailyClaimFloor : _weeklyClaimFloor;
      claims.removeWhere((date, _) => date.compareTo(floor) <= 0);
      medalDates.removeWhere((date) => date.compareTo(floor) <= 0);
    }

    // Retired periods retain a floor, so pruning cannot make their stars or
    // medals available again. Lifetime counters and achievements remain.
    trim(_dailyClaims, _dailyMedalDates, 180, true);
    trim(_weeklyClaims, _weeklyMedalDates, 104, false);
  }

  void _syncAchievements() {
    final cargoTotal = _cargoCollection.values.fold<int>(0, (a, b) => a + b);
    if (cargoTotal > 0) _earnedAchievements.add('first_cargo');
    if (cargoTotal >= 5) _earnedAchievements.add('cargo_5');
    if (_cargoCollection.entries.any(
      (entry) => entry.key.isRare && entry.value > 0,
    )) {
      _earnedAchievements.add('rare_cargo');
    }
    if (_stars >= 3 || _voyageClears > 0) {
      _earnedAchievements.add('first_signal');
    }
    for (final milestone in [5, 25, 100]) {
      if (_voyageClears >= milestone) {
        _earnedAchievements.add('navigator_$milestone');
      }
    }
    if (_best >= 200) _earnedAchievements.add('efficient_200');
    if (_dailyMedals >= 1) _earnedAchievements.add('daily_trio');
    if (_dailyMedals >= 7) _earnedAchievements.add('daily_7');
    if (_weeklyMedals >= 1) _earnedAchievements.add('weekly_expedition');
    if (_weeklyMedals >= 4) _earnedAchievements.add('weekly_4');
  }

  bool _refreshDate() {
    final today = _date(_now());
    if (today == _dailyDate) return false;
    _dailyDate = today;
    _dailyCompleted.clear();
    _dailyIndex = 0;
    return true;
  }

  bool _refreshWeek() {
    final week = _weekDate(_now());
    if (week == _weeklyDate) return false;
    _weeklyDate = week;
    _weeklyCompleted.clear();
    _weeklyIndex = 0;
    return true;
  }

  int _levelForMode(String layout) => switch (_mode) {
    GameMode.voyage => _replayLevel ?? _journeyLevel,
    GameMode.daily =>
      layout == _strategicLayout
          ? VoyageProgression.dailyLevel(_dailyIndex)
          : layout == _planetLayout
          ? PlanetV4Progression.dailyLevel(_dailyIndex)
          : layout == _voyageLayout
          ? 8 + _dailyIndex * 6
          : 8 + _dailyIndex * 3,
    GameMode.weekly =>
      layout == _strategicLayout
          ? VoyageProgression.weeklyLevel(_weeklyIndex)
          : layout == _planetLayout
          ? PlanetV4Progression.weeklyLevel(_weeklyIndex)
          : 12 + _weeklyIndex * 6,
  };

  void _startRound({required bool refreshDate}) {
    _traceOrigin = null;
    _tracePlan = null;
    // Parked challenges retain their own period while other modes are played.
    if (refreshDate && (_isDaily || _dailySlot == null)) _refreshDate();
    if (refreshDate && (_isWeekly || _weeklySlot == null)) _refreshWeek();
    final record = isReplaying ? _routeRecords[_replayLevel] : null;
    _roundDifficulty =
        record?.difficulty ??
        (_mode == GameMode.voyage ? _difficulty : Difficulty.balanced);
    _roundLayout =
        record?.layout ??
        (_mode == GameMode.voyage ? _bountyLayout : _strategicLayout);
    final level = _levelForMode(_roundLayout);
    _initialPuzzle = _generate(
      level,
      layout: _roundLayout,
      difficulty: _roundDifficulty,
    );
    _puzzle = _initialPuzzle;
    _replayActions.clear();
    _hasVerifiedReplay = true;
    _moves = 0;
    _assisted = false;
    _recorded = false;
    _lastReward = null;
    _history.clear();
    _lastChangedTile = null;
    _resetAttempt();
    _currentCargo = switch (_puzzle.cargoCell) {
      final cell? => CargoEncounter.forRound(
        level: level,
        cell: cell,
        now: _now(),
      ),
      _ => null,
    };
  }

  void _resetAttempt() {
    _attemptElapsed = Duration.zero;
    _attemptBudget = Duration.zero;
    _attemptExtraTime = Duration.zero;
    _timingEligible = true;
    _timingKnown = false;
    _timeCellUsed = false;
    _timeCellRetry = null;
    _challengeCleanEligible = true;
    _retryCount = 0;
    _lastTimingSaveSecond = -1;
    _timingDirty = false;
    _attemptRevision++;
  }

  Puzzle _generate(
    int level, {
    required String layout,
    required Difficulty difficulty,
  }) {
    final day =
        DateTime.parse('${_dailyDate}T00:00:00Z').millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
    final week =
        DateTime.parse('${_weeklyDate}T00:00:00Z').millisecondsSinceEpoch ~/
        Duration.millisecondsPerDay;
    final seed = switch (_mode) {
      GameMode.daily => day * 100 + _dailyIndex,
      GameMode.weekly => week * 100 + 50 + _weeklyIndex,
      GameMode.voyage => 731 + level * 97 + difficulty.index * 1907,
    };
    if (layout == _bountyLayout) {
      return Puzzle.bountyPlanet(
        seed: seed,
        levelNumber: level,
        difficulty: difficulty,
      );
    }
    if (layout == _strategicLayout) {
      return Puzzle.strategicPlanet(
        seed: seed,
        levelNumber: level,
        difficulty: difficulty,
      );
    }
    if (layout == _planetLayout) {
      return Puzzle.planet(
        seed: seed,
        levelNumber: level,
        difficulty: difficulty,
      );
    }
    if (layout == _voyageLayout) {
      return Puzzle.voyage(
        seed: seed,
        levelNumber: level,
        difficulty: difficulty,
      );
    }
    if (layout == _introductionLayout) {
      return Puzzle.introduction(levelNumber: level, seed: seed);
    }
    return Puzzle.generate(
      seed: seed,
      levelNumber: level,
      difficulty: difficulty,
    );
  }

  void _restoreProgress(Map<String, dynamic> data) {
    _journeyLevel = _integer(data['journeyLevel'], fallback: 1, minimum: 1);
    _stars = _integer(data['stars']);
    _best = _integer(data['best'], maximum: 200);
    _mode = GameMode.values.firstWhere(
      (mode) => mode.name == data['mode'],
      orElse: () => data['isDaily'] == true ? GameMode.daily : GameMode.voyage,
    );
    _weeklyDate = _validDate(data['weeklyDate']) ?? _weekDate(_now());
    if (_weekDate(DateTime.parse('${_weeklyDate}T00:00:00Z')) != _weeklyDate) {
      _weeklyDate = _weekDate(_now());
    }
    _weeklyIndex = _integer(data['weeklyIndex'], maximum: 4);
    _weeklyCompleted
      ..clear()
      ..addAll(_completed(data['weeklyCompleted'], count: 5));
    _dailyDate = _validDate(data['dailyDate']) ?? _date(_now());
    _dailyIndex = _integer(data['dailyIndex'], maximum: 2);
    _dailyCompleted
      ..clear()
      ..addAll(_completed(data['dailyCompleted']));
    _difficulty = Difficulty.values.firstWhere(
      (difficulty) => difficulty.name == data['difficulty'],
      orElse: () => Difficulty.balanced,
    );
    final slots = data['modeSlots'];
    if (slots is Map<String, dynamic>) {
      final journey = slots['journey'];
      final daily = slots['daily'];
      final weekly = slots['weekly'];
      final frontier = slots['frontier'];
      _journeySlot = journey is Map<String, dynamic> ? journey : null;
      _dailySlot = daily is Map<String, dynamic> ? daily : null;
      _weeklySlot = weekly is Map<String, dynamic> ? weekly : null;
      _frontierSlot = frontier is Map<String, dynamic> ? frontier : null;
    }
    _restoreEconomy(data['economy']);
    _restoreRewards(data['rewards']);
    _challengeRuns.clear();
    final challengeRuns = data['challengeRuns'];
    if (challengeRuns is List) {
      for (final entry in challengeRuns.take(284)) {
        final run = ChallengeRunSummary.fromJson(entry);
        if (run != null) _storeChallengeRun(run);
      }
    }
    final settings = data['settings'];
    if (settings is Map<String, dynamic>) {
      _reduceMotion = settings['reduceMotion'] == true;
      _highContrast = settings['highContrast'] == true;
      _haptics = settings['haptics'] != false;
      _onboardingSeen = settings['onboardingSeen'] == true;
      final rules = settings['introducedRules'];
      if (rules is List) {
        _introducedRules.addAll(
          rules.whereType<String>().where((rule) => rule.length <= 80).take(40),
        );
      }
    }
  }

  void _restoreEconomy(Object? value) {
    final data = value is Map<String, dynamic>
        ? value
        : const <String, dynamic>{};
    _coins = _integer(data['coins'], maximum: 1000000000);
    _hintCredits = _integer(data['hintCredits']);
    _routeRecords.clear();
    final records = data['records'];
    if (records is List) {
      for (final entry in records.take(100000)) {
        final record = RouteRecord.fromJson(entry);
        if (record != null && record.level < _journeyLevel) {
          _routeRecords[record.level] = record;
        }
      }
    }
    _powerUps.clear();
    final powers = data['powerUps'];
    if (powers is Map<String, dynamic>) {
      for (final item in PowerUp.values) {
        _powerUps[item] = _integer(powers[item.name]);
      }
    }
    _cargoCollection.clear();
    final cargo = data['cargoCollection'];
    if (cargo is Map<String, dynamic>) {
      for (final kind in CargoKind.values) {
        final count = _integer(cargo[kind.name]);
        if (count > 0) _cargoCollection[kind] = count;
      }
    }
    _cargoClaims.clear();
    final claims = data['cargoClaims'];
    if (claims is List) {
      _cargoClaims.addAll(
        claims.whereType<String>().where(
          (key) => key.isNotEmpty && key.length <= 160,
        ),
      );
    }
  }

  void _restoreRewards(Object? value) {
    final data = value is Map<String, dynamic>
        ? value
        : const <String, dynamic>{};
    _voyageClears = _integer(
      data['voyageClears'],
      fallback: math.max(0, _journeyLevel - 1),
    );
    _skippedVoyage = _integer(data['skippedVoyage']);
    _dailyClaimFloor = _validDate(data['dailyClaimFloor']) ?? '';
    _weeklyClaimFloor = _validDate(data['weeklyClaimFloor']) ?? '';
    void claims(Object? input, Map<String, int> target, int mask) {
      target.clear();
      if (input is! Map<String, dynamic>) return;
      for (final entry in input.entries) {
        if (_validDate(entry.key) != null &&
            entry.value is int &&
            entry.value > 0 &&
            entry.value <= mask) {
          target[entry.key] = entry.value as int;
        }
      }
    }

    claims(data['dailyClaims'], _dailyClaims, 7);
    claims(data['weeklyClaims'], _weeklyClaims, 31);
    Set<String> dates(Object? input) => input is List
        ? {
            for (final item in input)
              if (_validDate(item) != null) item as String,
          }
        : {};
    _dailyMedalDates
      ..clear()
      ..addAll(dates(data['dailyMedalDates']));
    _weeklyMedalDates
      ..clear()
      ..addAll(dates(data['weeklyMedalDates']));
    _dailyMedals = math.max(
      _integer(data['dailyMedals']),
      _dailyMedalDates.length,
    );
    _weeklyMedals = math.max(
      _integer(data['weeklyMedals']),
      _weeklyMedalDates.length,
    );
    final ids = data['achievements'];
    _earnedAchievements
      ..clear()
      ..addAll(
        achievementCatalog
            .where((a) => ids is List && ids.contains(a.id))
            .map((a) => a.id),
      );

    // Older saves contain enough information to honor their current earned
    // routes and completed sets, without inventing historical daily totals.
    void seed(String date, Set<int> completed, bool daily) {
      final floor = daily ? _dailyClaimFloor : _weeklyClaimFloor;
      if (date.compareTo(floor) <= 0 || completed.isEmpty) return;
      final target = daily ? _dailyClaims : _weeklyClaims;
      final bits = completed.fold<int>(0, (mask, index) => mask | (1 << index));
      target[date] = (target[date] ?? 0) | bits;
      if (completed.length != (daily ? 3 : 5)) return;
      if (daily && _dailyMedalDates.add(date)) _dailyMedals++;
      if (!daily && _weeklyMedalDates.add(date)) _weeklyMedals++;
    }

    seed(_dailyDate, _dailyCompleted, true);
    seed(_weeklyDate, _weeklyCompleted, false);
    for (final (slot, daily) in [(_dailySlot, true), (_weeklySlot, false)]) {
      if (slot == null) continue;
      final prefix = daily ? 'daily' : 'weekly';
      final date = _validDate(slot['${prefix}Date']);
      if (date != null) {
        seed(
          date,
          _completed(slot['${prefix}Completed'], count: daily ? 3 : 5),
          daily,
        );
      }
    }
    _trimClaims();
    _syncAchievements();
    _equippedTrail = ShipTrail.values.firstWhere(
      (trail) =>
          trail.name == data['equippedTrail'] && _stars >= trail.requiredStars,
      orElse: () => unlockedTrails.last,
    );
  }

  bool _restoreRound(Object? value) {
    if (value is! Map<String, dynamic>) return false;
    final level = value['level'];
    final moves = value['moves'];
    final recorded = value['recorded'];
    final assisted = value['assisted'];
    if (level is! int ||
        level < 1 ||
        level > 1000000 ||
        moves is! int ||
        moves < 0 ||
        moves > 1000000 ||
        recorded is! bool ||
        assisted is! bool) {
      return false;
    }
    final layout = value['layout'] ?? _generatedLayout;
    if (layout is! String ||
        ![
          _generatedLayout,
          _introductionLayout,
          _voyageLayout,
          _planetLayout,
          _strategicLayout,
          _bountyLayout,
        ].contains(layout)) {
      return false;
    }
    if (layout == _introductionLayout &&
        (_mode != GameMode.voyage || level > 3)) {
      return false;
    }
    if (layout == _bountyLayout && _mode != GameMode.voyage) return false;
    if (_isWeekly &&
        layout != _voyageLayout &&
        layout != _planetLayout &&
        layout != _strategicLayout) {
      return false;
    }
    final replay = value['replay'] == true;
    if (replay && (_mode != GameMode.voyage || level >= _journeyLevel)) {
      return false;
    }
    final expectedLevel = _mode == GameMode.voyage
        ? (replay ? level : _journeyLevel - (recorded ? 1 : 0))
        : _levelForMode(layout);
    if (level != expectedLevel) return false;
    final difficultyValue = value['difficulty'];
    final difficulty = difficultyValue == null
        ? (_mode == GameMode.voyage ? _difficulty : Difficulty.balanced)
        : _parseDifficulty(difficultyValue);
    if (difficulty == null ||
        (_mode != GameMode.voyage && difficulty != Difficulty.balanced)) {
      return false;
    }
    final initial = _generate(level, layout: layout, difficulty: difficulty);
    if (value['seed'] != initial.seed) return false;
    final restored = _withRotations(initial, value['rotations']);
    if (restored == null || restored.evaluate().solved != recorded) {
      return false;
    }
    if (_isDaily && recorded && !_dailyCompleted.contains(_dailyIndex)) {
      return false;
    }
    if (_isWeekly && recorded && !_weeklyCompleted.contains(_weeklyIndex)) {
      return false;
    }
    _initialPuzzle = initial;
    _roundLayout = layout;
    _roundDifficulty = difficulty;
    _puzzle = restored;
    _replayLevel = replay ? level : null;
    _moves = moves;
    _replayActions.clear();
    _hasVerifiedReplay = false;
    final actions = value['replayActions'];
    if (actions is List &&
        actions.length == moves &&
        actions.length <= 10000 &&
        actions.every((i) => i is int && i >= 0 && i < initial.tiles.length)) {
      var replayed = initial;
      var valid = true;
      for (final action in actions.cast<int>()) {
        if (replayed.evaluate().solved || replayed.tiles[action].isLocked) {
          valid = false;
          break;
        }
        replayed = replayed.rotateAt(action);
      }
      if (valid && listEquals(_rotations(replayed), _rotations(restored))) {
        _replayActions.addAll(actions.cast<int>());
        _hasVerifiedReplay = true;
      }
    }
    _assisted = assisted;
    _recorded = recorded;
    _lastReward = recorded ? CompletionReward.fromJson(value['reward']) : null;
    _resetAttempt();
    _challengeCleanEligible = value['challengeCleanEligible'] != false;
    final timing = value['timing'];
    if (timing is Map<String, dynamic>) {
      _attemptElapsed = Duration(
        milliseconds: _integer(timing['elapsedMs'], maximum: 86400000),
      );
      _attemptBudget = Duration(
        milliseconds: _integer(timing['budgetMs'], maximum: 600000),
      );
      _attemptExtraTime = Duration(
        milliseconds: _integer(timing['extraMs'], maximum: 86400000),
      );
      _timingKnown = timing['known'] == true && _attemptBudget > Duration.zero;
      _timingEligible = timing['eligible'] == true;
      _timeCellUsed = timing['timeCellUsed'] == true;
      _retryCount = _integer(timing['retries']);
      final timeCellRetry = timing['timeCellRetry'];
      _timeCellRetry = !_timeCellUsed
          ? null
          : timeCellRetry is int &&
                timeCellRetry >= 0 &&
                timeCellRetry <= _retryCount
          ? timeCellRetry
          : _retryCount;
      _lastTimingSaveSecond = _attemptElapsed.inSeconds;
    } else {
      // An already-edited legacy board has no trustworthy active-time history.
      _timingEligible = moves == 0 && !recorded;
    }
    final cargo = CargoEncounter.fromJson(value['cargo']);
    _currentCargo =
        cargo != null &&
            cargo.levelNumber == level &&
            cargo.cell == initial.cargoCell
        ? cargo
        : null;
    _lastChangedTile = null;
    _history.clear();
    final history = value['history'];
    if (history is List) {
      var previousCount = -1;
      for (final entry in history) {
        if (entry is! Map<String, dynamic>) {
          _history.clear();
          break;
        }
        final count = entry['moves'];
        final puzzle = _withRotations(initial, entry['rotations']);
        if (count is! int ||
            count <= previousCount ||
            count >= moves ||
            puzzle == null ||
            puzzle.evaluate().solved) {
          _history.clear();
          break;
        }
        _history.add(GameMove(puzzle: puzzle, moves: count));
        previousCount = count;
      }
    }
    return true;
  }

  bool _restoreSlot(Map<String, dynamic> slot) {
    final previousDate = _dailyDate, previousWeek = _weeklyDate;
    final previousIndex = _dailyIndex, previousWeeklyIndex = _weeklyIndex;
    final previousCompleted = _dailyCompleted.toSet(),
        previousWeeklyCompleted = _weeklyCompleted.toSet();
    if (_isDaily || _isWeekly) {
      final prefix = _isDaily ? 'daily' : 'weekly';
      final date = _validDate(slot['${prefix}Date']);
      final index = slot['${prefix}Index'];
      final count = _isDaily ? 3 : 5;
      if (date == null || index is! int || index < 0 || index >= count) {
        return false;
      }
      if (_isWeekly && _weekDate(DateTime.parse('${date}T00:00:00Z')) != date) {
        return false;
      }
      if (_isDaily) {
        _dailyDate = date;
        _dailyIndex = index;
        _dailyCompleted
          ..clear()
          ..addAll(_completed(slot['dailyCompleted']));
      } else {
        _weeklyDate = date;
        _weeklyIndex = index;
        _weeklyCompleted
          ..clear()
          ..addAll(_completed(slot['weeklyCompleted'], count: 5));
      }
    }
    if (_restoreRound(slot['round'])) return true;
    _dailyDate = previousDate;
    _dailyIndex = previousIndex;
    _weeklyDate = previousWeek;
    _weeklyIndex = previousWeeklyIndex;
    _dailyCompleted
      ..clear()
      ..addAll(previousCompleted);
    _weeklyCompleted
      ..clear()
      ..addAll(previousWeeklyCompleted);
    return false;
  }

  static Difficulty? _parseDifficulty(Object? value) {
    for (final difficulty in Difficulty.values) {
      if (difficulty.name == value) return difficulty;
    }
    return null;
  }

  static Puzzle? _withRotations(Puzzle initial, Object? rotations) {
    if (rotations is! List || rotations.length != initial.tiles.length) {
      return null;
    }
    final tiles = <Tile>[];
    for (var index = 0; index < rotations.length; index++) {
      final rotation = rotations[index];
      if (rotation is! int || rotation < 0 || rotation > 3) return null;
      final tile = initial.tiles[index];
      if (tile.isLocked && rotation != tile.rotation) return null;
      tiles.add(tile.withRotation(rotation));
    }
    final groups = <int, int>{};
    for (var index = 0; index < tiles.length; index++) {
      final group = tiles[index].couplingGroup;
      if (group == 0) continue;
      final delta = (tiles[index].rotation - initial.tiles[index].rotation) % 4;
      if (groups.containsKey(group) && groups[group] != delta) return null;
      groups[group] = delta;
    }
    return initial.copyWithTiles(tiles);
  }

  void _migrateLegacy() {
    final preferences = _preferences!;
    _journeyLevel = _integer(
      preferences.get('journeyLevel'),
      fallback: 1,
      minimum: 1,
    );
    _stars = _integer(preferences.get('stars'));
    _best = _integer(preferences.get('best'), maximum: 200);
    _dailyDate = _validDate(preferences.get('dailyDate')) ?? _date(_now());
    _dailyCompleted
      ..clear()
      ..addAll(_completed(preferences.get('dailyCompleted')));
    _restoreRewards(null);
  }

  static int _integer(
    Object? value, {
    int fallback = 0,
    int minimum = 0,
    int maximum = 1000000,
  }) => value is int && value >= minimum && value <= maximum ? value : fallback;

  static Set<int> _completed(Object? value, {int count = 3}) {
    if (value is! List) return {};
    return {
      for (final entry in value)
        if (entry is int && entry >= 0 && entry < count)
          entry
        else if (entry is String &&
            List.generate(count, (i) => '$i').contains(entry))
          int.parse(entry),
    };
  }

  static String _date(DateTime time) =>
      time.toUtc().toIso8601String().split('T').first;

  static String _weekDate(DateTime time) {
    final utc = time.toUtc();
    return _date(
      DateTime.utc(
        utc.year,
        utc.month,
        utc.day,
      ).subtract(Duration(days: utc.weekday - 1)),
    );
  }

  static String? _validDate(Object? value) {
    if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
      return null;
    }
    final parsed = DateTime.tryParse('${value}T00:00:00Z');
    return parsed != null && _date(parsed) == value ? value : null;
  }

  String _snapshot() => jsonEncode({
    'schemaVersion': _schemaVersion,
    'generatorVersion': puzzleGeneratorVersion,
    'journeyLevel': _journeyLevel,
    'stars': _stars,
    'best': _best,
    'economy': {
      'coins': _coins,
      'hintCredits': _hintCredits,
      'records': _routeRecords.values.map((record) => record.toJson()).toList(),
      'powerUps': {
        for (final entry in _powerUps.entries) entry.key.name: entry.value,
      },
      'cargoCollection': {
        for (final entry in _cargoCollection.entries)
          entry.key.name: entry.value,
      },
      'cargoClaims': _cargoClaims.toList(),
    },
    'isDaily': _isDaily,
    'mode': _mode.name,
    'weeklyDate': _weeklyDate,
    'weeklyIndex': _weeklyIndex,
    'weeklyCompleted': _weeklyCompleted.toList()..sort(),
    'challengeRuns': _challengeRuns.values.map((run) => run.toJson()).toList(),
    'rewards': {
      'voyageClears': _voyageClears,
      'skippedVoyage': _skippedVoyage,
      'equippedTrail': _equippedTrail.name,
      'achievements': _earnedAchievements.toList()..sort(),
      'dailyMedals': _dailyMedals,
      'weeklyMedals': _weeklyMedals,
      'dailyClaims': _dailyClaims,
      'weeklyClaims': _weeklyClaims,
      'dailyMedalDates': _dailyMedalDates.toList()..sort(),
      'weeklyMedalDates': _weeklyMedalDates.toList()..sort(),
      'dailyClaimFloor': _dailyClaimFloor,
      'weeklyClaimFloor': _weeklyClaimFloor,
    },
    'difficulty': _difficulty.name,
    'dailyDate': _dailyDate,
    'dailyIndex': _dailyIndex,
    'dailyCompleted': _dailyCompleted.toList()..sort(),
    'settings': {
      'reduceMotion': _reduceMotion,
      'highContrast': _highContrast,
      'haptics': _haptics,
      'onboardingSeen': _onboardingSeen,
      'introducedRules': _introducedRules.toList(),
    },
    'round': _roundSnapshot(),
    'modeSlots': {
      if (_journeySlot != null) 'journey': _journeySlot,
      if (_dailySlot != null) 'daily': _dailySlot,
      if (_weeklySlot != null) 'weekly': _weeklySlot,
      if (_frontierSlot != null) 'frontier': _frontierSlot,
    },
  });

  Map<String, dynamic> _slotSnapshot() => {
    'round': _roundSnapshot(),
    if (_isDaily) ...{
      'dailyDate': _dailyDate,
      'dailyIndex': _dailyIndex,
      'dailyCompleted': _dailyCompleted.toList()..sort(),
    },
    if (_isWeekly) ...{
      'weeklyDate': _weeklyDate,
      'weeklyIndex': _weeklyIndex,
      'weeklyCompleted': _weeklyCompleted.toList()..sort(),
    },
  };

  Map<String, dynamic> _roundSnapshot() => {
    'layout': _roundLayout,
    'difficulty': _roundDifficulty.name,
    'seed': _puzzle.seed,
    'level': _puzzle.levelNumber,
    'rotations': _rotations(_puzzle),
    'moves': _moves,
    'replay': isReplaying,
    'challengeCleanEligible': _challengeCleanEligible,
    'timing': {
      'elapsedMs': _attemptElapsed.inMilliseconds,
      'budgetMs': _attemptBudget.inMilliseconds,
      'extraMs': _attemptExtraTime.inMilliseconds,
      'known': _timingKnown,
      'eligible': _timingEligible,
      'timeCellUsed': _timeCellUsed,
      if (_timeCellRetry != null) 'timeCellRetry': _timeCellRetry,
      'retries': _retryCount,
    },
    if (_currentCargo != null) 'cargo': _currentCargo!.toJson(),
    if (_hasVerifiedReplay) 'replayActions': _replayActions,
    'assisted': _assisted,
    'recorded': _recorded,
    if (_lastReward != null) 'reward': _lastReward!.toJson(),
    'history': [
      for (final move in _history)
        {'rotations': _rotations(move.puzzle), 'moves': move.moves},
    ],
  };

  static List<int> _rotations(Puzzle puzzle) =>
      puzzle.tiles.map((tile) => tile.rotation).toList();

  void _changed() {
    _enqueueSave();
    if (!_disposed) notifyListeners();
  }

  void _setSaveError(bool value) {
    if (_saveError == value) return;
    _saveError = value;
    if (!_disposed) notifyListeners();
  }

  void _enqueueSave() {
    final preferences = _preferences;
    if (preferences == null) {
      _setSaveError(true);
      return;
    }
    final snapshot = _snapshot();
    _timingDirty = false;
    _saveQueue = _saveQueue.then((_) async {
      try {
        final saved =
            await (_snapshotWriter?.call(snapshot) ??
                preferences.setString(storageKey, snapshot));
        _setSaveError(!saved);
      } catch (_) {
        _setSaveError(true);
      }
    });
  }

  /// Waits for every queued write, including writes added while waiting.
  /// A failed latest write gets one retry; failures are reported via saveError.
  Future<void> flush() async {
    await load();
    if (_timingDirty && !_disposed && _preferences != null) _enqueueSave();
    await _drainWrites();
    if (_saveError && !_disposed && _preferences != null) {
      _enqueueSave();
      await _drainWrites();
    }
  }

  Future<void> _drainWrites() async {
    while (true) {
      final pending = _saveQueue;
      await pending;
      if (identical(pending, _saveQueue)) return;
    }
  }

  @override
  void dispose() {
    // The screen samples its clock immediately before disposal. Preserve that
    // final fraction of a second even if no lifecycle pause preceded removal.
    if (_timingDirty && !_disposed && _preferences != null) _enqueueSave();
    _traceOrigin = null;
    _tracePlan = null;
    _disposed = true;
    super.dispose();
  }
}
