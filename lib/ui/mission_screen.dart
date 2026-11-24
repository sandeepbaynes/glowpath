import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/mission.dart';
import '../game/mission_controller.dart';
import 'cockpit_flight.dart';
import 'design.dart';
import 'flight_controls.dart';
import 'mission_board.dart';
import 'reactive_sky.dart';
import 'rocket_effects.dart';

enum FlightPhase { briefing, planning, ignition, flight, debrief, map, travel }

class MissionScreen extends StatefulWidget {
  const MissionScreen({
    super.key,
    this.controller,
    this.now,
    this.motionEnabled = true,
  });
  final MissionController? controller;
  final DateTime Function()? now;

  /// A test host can turn off the physical sensor without changing saved options.
  final bool motionEnabled;
  @override
  State<MissionScreen> createState() => _MissionScreenState();
}

class _MissionScreenState extends State<MissionScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final MissionController _game;
  late final AnimationController _cinema;
  late final Timer _ticker;
  FlightPhase _phase = FlightPhase.briefing;
  int? _lastTick;
  final Stopwatch _elapsed = Stopwatch()..start();
  bool _optionsReady = false;
  FlightPhase _mapReturnPhase = FlightPhase.briefing;
  int get _clockMicros =>
      widget.now?.call().microsecondsSinceEpoch ?? _elapsed.elapsedMicroseconds;
  double _remaining = 0;
  bool _foreground = true, _paused = false, _modal = false;
  bool _untimed = false,
      _motionSky = true,
      _reduceMotion = false,
      _haptics = true;
  int? _hintIndex;
  FlightResult? _flight;
  SharedPreferences? _preferences;
  bool _licenseExpanded = false;
  bool _manualExpanded = false;
  Future<List<LicenseEntry>>? _licenseEntries;
  final ScrollController _scroll = ScrollController();
  DateTime get _now => (widget.now ?? DateTime.now)().toUtc();
  bool get _reduced =>
      _reduceMotion ||
      MediaQuery.disableAnimationsOf(context) ||
      MediaQuery.reduceMotionOf(context);
  bool get _running => _foreground && !_paused && !_modal;
  bool get _timed => !_untimed && _game.mission.timeLimitSeconds > 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _game = widget.controller ?? MissionController();
    _game.addListener(_changed);
    // Motion preferences change the imagery, never the countdown's real duration.
    _cinema = AnimationController(
      vsync: this,
      animationBehavior: AnimationBehavior.preserve,
    )..addStatusListener(_animationStatus);
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) => _tick());
    unawaited(_load());
  }

  Future<void> _load() async {
    await _game.load();
    SharedPreferences? prefs;
    try {
      prefs = await SharedPreferences.getInstance();
    } catch (_) {
      // Defaults remain playable if the preferences service is unavailable.
    }
    if (!mounted) return;
    _preferences = prefs;
    setState(() {
      _untimed = prefs?.getBool('glowpath.flight.untimed') ?? false;
      _motionSky = prefs?.getBool('glowpath.flight.motionSky') ?? true;
      _reduceMotion = prefs?.getBool('glowpath.flight.reduceMotion') ?? false;
      _haptics = prefs?.getBool('glowpath.flight.haptics') ?? true;
      _optionsReady = true;
      _flight = _game.flightResult;
      if (_flight != null) _phase = FlightPhase.debrief;
    });
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  void _tick() {
    if (!mounted) return;
    final now = _clockMicros;
    final elapsed = _lastTick == null ? 0.0 : (now - _lastTick!) / 1000000;
    _lastTick = now;
    if (_phase == FlightPhase.planning && _timed && _running) {
      _remaining = math.max(0, _remaining - math.max(0, elapsed));
      if (_remaining <= 0) {
        _launch();
        return;
      }
    }
    // Graphic clocks update at 5 Hz; the sky itself only reacts to input.
    if (_foreground && (_game.isDaily || _phase == FlightPhase.planning)) {
      setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _lastTick = _clockMicros;
    if (!_foreground) {
      _cinema.stop();
      unawaited(_game.flush());
    } else if (_running && _cinematic) {
      _cinema.forward();
    }
    if (mounted) setState(() {});
  }

  bool get _cinematic =>
      _phase == FlightPhase.ignition ||
      _phase == FlightPhase.flight ||
      _phase == FlightPhase.travel;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker.cancel();
    _cinema.dispose();
    _scroll.dispose();
    _game.removeListener(_changed);
    unawaited(_game.flush());
    if (widget.controller == null) _game.dispose();
    super.dispose();
  }

  void _buzz([bool arrival = false]) {
    if (_haptics) {
      unawaited(
        arrival
            ? HapticFeedback.lightImpact()
            : HapticFeedback.selectionClick(),
      );
    }
  }

  void _arm() {
    if (!_game.ready || !_optionsReady) return;
    setState(() {
      _phase = FlightPhase.planning;
      _paused = false;
      _remaining = _game.mission.timeLimitSeconds.toDouble();
      _lastTick = _clockMicros;
    });
    _buzz();
  }

  void _launch() {
    if (_phase != FlightPhase.planning || !_running) return;
    final result = _game.launch();
    setState(() {
      _flight = result;
      _phase = FlightPhase.ignition;
      _hintIndex = null;
    });
    _buzz(true);
    _cinema.duration = const Duration(seconds: 5);
    _cinema.forward(from: 0);
  }

  void _animationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    if (_phase == FlightPhase.ignition) {
      setState(() => _phase = FlightPhase.flight);
      _cinema.duration = Duration(
        milliseconds: _reduced
            ? 2200
            : (4500 + (_flight?.steps.length ?? 0) * 650).clamp(6500, 18000),
      );
      _cinema.forward(from: 0);
    } else if (_phase == FlightPhase.flight) {
      setState(() => _phase = FlightPhase.debrief);
      _buzz(true);
    } else if (_phase == FlightPhase.travel) {
      setState(() => _phase = FlightPhase.briefing);
    }
  }

  void _retry() {
    _game.retry();
    _flight = null;
    _hintIndex = null;
    _arm();
  }

  void _openMap() {
    setState(() {
      _mapReturnPhase = _phase;
      _phase = FlightPhase.map;
    });
    _cinema.stop();
  }

  void _travel(int level) {
    if (_game.isDaily) _game.setDaily(false);
    if (level == _game.currentLevel) {
      setState(() {
        _flight = _game.flightResult;
        _phase = _flight != null
            ? FlightPhase.debrief
            : _mapReturnPhase == FlightPhase.planning
            ? FlightPhase.planning
            : FlightPhase.briefing;
        _lastTick = _clockMicros;
      });
      return;
    }
    if (!_game.selectUnlocked(level)) return;
    setState(() {
      _phase = FlightPhase.travel;
      _flight = null;
      _hintIndex = null;
      _paused = false;
    });
    _cinema.duration = Duration(milliseconds: _reduced ? 1 : 1600);
    _cinema.forward(from: 0);
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  void _daily() {
    _game.setDaily(true);
    setState(() {
      _flight = _game.flightResult;
      _phase = _flight == null ? FlightPhase.briefing : FlightPhase.debrief;
      _hintIndex = null;
      _paused = false;
    });
  }

  void _hint() {
    if (_hintIndex != null) {
      _game.hint();
      setState(() => _hintIndex = null);
    } else {
      // The controller records assistance on the explicit reveal.
      _game.requestHint();
      setState(() => _hintIndex = _game.suggestedHintIndex);
    }
    _buzz();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ReactiveSky(
      enabled: widget.motionEnabled && _motionSky && _running && !_cinematic,
      reduceMotion: _reduced,
      sector: _game.currentLevel,
      excitement: _phase == FlightPhase.planning && _remaining < 15 ? .8 : .1,
      child: SafeArea(
        child: !_game.ready || !_optionsReady
            ? const Center(
                child: OrbitClock(
                  progress: .25,
                  readout: 'LINK',
                  label: 'connecting',
                  size: 110,
                ),
              )
            : _cinematic
            ? _cinematicView()
            : _phase == FlightPhase.map
            ? _mapView()
            : _console(),
      ),
    ),
  );

  Widget _console() => LayoutBuilder(
    builder: (context, constraints) {
      final wide = constraints.maxWidth >= 840;
      final preview = _game.mission.launch(
        attempt: _game.attempt,
        ignoreRisk: true,
      );
      final planning = _phase == FlightPhase.planning;
      final board = MissionBoard(
        mission: _game.mission,
        reduceMotion: _reduced,
        preview: _phase == FlightPhase.planning ? preview : null,
        enabled: planning && _running,
        hintIndex: _hintIndex,
        teachingIndex:
            _game.currentLevel == 1 &&
                _game.moves == 0 &&
                _phase != FlightPhase.debrief
            ? _game.mission.startRow * 5
            : null,
        result: _phase == FlightPhase.debrief ? _flight : null,
        flightProgress: _phase == FlightPhase.debrief ? 1 : 0,
        showFailure: _phase == FlightPhase.debrief && _flight?.success == false,
        onInspect: _inspect,
        onTurn: (index) {
          if (_game.turn(index)) {
            setState(() => _hintIndex = null);
            _buzz();
          }
        },
      );
      return SingleChildScrollView(
        controller: _scroll,
        key: const ValueKey('mission-scroll'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: wide ? 1050 : 470),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _header(),
                const SizedBox(height: 16),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: board),
                      const SizedBox(width: 34),
                      Expanded(
                        child: Column(
                          children: [
                            _missionBrief(),
                            const SizedBox(height: 16),
                            _instrumentPanel(preview),
                            const SizedBox(height: 20),
                            _actions(),
                          ],
                        ),
                      ),
                    ],
                  )
                else ...[
                  _missionBrief(),
                  const SizedBox(height: 14),
                  board,
                  const SizedBox(height: 18),
                  _instrumentPanel(preview),
                  const SizedBox(height: 18),
                  _actions(),
                ],
                if (_game.isDaily) ...[
                  const SizedBox(height: 22),
                  _dailyClock(),
                ],
                if (_game.saveError)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Semantics(
                      liveRegion: true,
                      child: const Text(
                        'Flight recorder unavailable. Keep the app open to preserve this plan.',
                        style: TextStyle(color: hazardRed),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    },
  );

  Widget _header() => Row(
    children: [
      CustomPaint(
        painter: _MissionNumberPainter(),
        child: SizedBox(
          width: 58,
          height: 58,
          child: Center(
            child: Text(
              '${_game.currentLevel}'.padLeft(2, '0'),
              style: const TextStyle(
                fontSize: 24,
                color: Palette.rust,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _game.isDaily ? 'DAILY TRANSMISSION' : 'MISSION CONTROL',
              style: const TextStyle(
                fontSize: 10,
                letterSpacing: 1.8,
                color: Palette.secondary,
              ),
            ),
            const SizedBox(height: 3),
            Text(_game.mission.title, style: bookTitle(25)),
          ],
        ),
      ),
      const SizedBox(width: 6),
      SizedBox(
        width: 58,
        child: FlightControl(
          key: const ValueKey('flight-map'),
          label: 'Atlas',
          icon: Icons.public,
          onTap: _openMap,
          compact: true,
        ),
      ),
      const SizedBox(width: 5),
      SizedBox(
        width: 58,
        child: FlightControl(
          key: const ValueKey('flight-settings'),
          label: 'Comms',
          icon: Icons.tune_rounded,
          onTap: _settings,
          compact: true,
        ),
      ),
    ],
  );

  Widget _missionBrief() {
    final failed = _phase == FlightPhase.debrief && _flight?.success == false;
    final success = _phase == FlightPhase.debrief && _flight?.success == true;
    final line = failed
        ? _flight!.message
        : success
        ? _game.isDaily
              ? 'Daily signal delivered. Return to the expedition or await the next transmission.'
              : _game.currentLevel == Mission.campaignCount
              ? 'Expedition complete. Revisit the atlas to refine any flight.'
              : 'Docking confirmed. Your flight has opened the next coordinate.'
        : _hintIndex != null
        ? 'Guidance linked. Inspect the illuminated sector, or request its turn.'
        : _game.mission.briefing;
    return Container(
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(color: failed ? hazardRed : Palette.rust, width: 2),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 4, 0, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            failed
                ? Icons.satellite_alt_rounded
                : success
                ? Icons.verified_rounded
                : Icons.graphic_eq_rounded,
            color: failed ? hazardRed : Palette.rust,
            size: 24,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    failed
                        ? 'SIGNAL LOST'
                        : success
                        ? 'MISSION COMPLETE'
                        : _paused
                        ? 'MISSION PAUSED'
                        : 'INCOMING · FLIGHT DIRECTOR',
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1.2,
                      color: failed ? hazardRed : Palette.rust,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(line, style: const TextStyle(fontSize: 14, height: 1.3)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _instrumentPanel(FlightResult preview) {
    final timed = _timed;
    final finished = _phase == FlightPhase.debrief;
    final seconds = _phase == FlightPhase.briefing
        ? _game.mission.timeLimitSeconds.toDouble()
        : _remaining;
    final payload = _phase == FlightPhase.debrief
        ? (_flight?.collectedStars.length ?? 0)
        : preview.collectedStars.length;
    return Row(
      children: [
        OrbitClock(
          key: const ValueKey('launch-clock'),
          progress: finished
              ? payload / math.max(1, _game.mission.starIndices.length)
              : timed
              ? seconds / math.max(1, _game.mission.timeLimitSeconds)
              : 1,
          readout: finished
              ? (_flight!.success ? 'OK' : 'LOST')
              : timed
              ? '${seconds.ceil()}'
              : '∞',
          label: finished
              ? 'Flight log'
              : timed
              ? 'T minus'
              : 'Free flight',
          size: 86,
          urgent: !finished && timed && seconds <= 15,
          accent: finished
              ? (_flight!.success ? Palette.light : hazardRed)
              : timed && seconds <= 15
              ? hazardRed
              : Palette.rust,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            children: [
              FlightMeter(
                label: 'Star beacons',
                value: '$payload / ${_game.mission.starIndices.length}',
                fraction:
                    payload / math.max(1, _game.mission.starIndices.length),
                accent: Palette.light,
              ),
              const SizedBox(height: 13),
              FlightMeter(
                label: _game.assisted ? 'Guided flight' : 'Route telemetry',
                value: '${_game.moves} ${_game.moves == 1 ? 'turn' : 'turns'}',
                fraction: preview.steps.length / 25,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _actions() {
    if (_phase == FlightPhase.briefing) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FlightControl(
            key: const ValueKey('arm-mission'),
            label: 'BEGIN MISSION',
            icon: Icons.power_settings_new_rounded,
            onTap: _arm,
            primary: true,
          ),
          const SizedBox(height: 10),
          _ruleStrip(),
        ],
      );
    }
    if (_phase == FlightPhase.debrief) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FlightControl(
            key: const ValueKey('debrief-action'),
            label: _flight!.success ? 'PLOT NEXT COURSE' : 'REVISE & RETRY',
            icon: _flight!.success
                ? Icons.travel_explore_rounded
                : Icons.replay_rounded,
            accent: _flight!.success ? Palette.rust : hazardGold,
            onTap: _flight!.success ? _openMap : _retry,
            primary: true,
          ),
          const SizedBox(height: 10),
          _ruleStrip(),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: FlightControl(
                key: const ValueKey('flight-undo'),
                label: 'Undo',
                icon: Icons.undo_rounded,
                onTap: _game.canUndo && _running
                    ? () {
                        _game.undo();
                        setState(() => _hintIndex = null);
                      }
                    : null,
                compact: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FlightControl(
                key: const ValueKey('flight-hint'),
                label: _hintIndex == null ? 'Guidance' : 'Turn relay',
                icon: Icons.radar_rounded,
                onTap: _running ? _hint : null,
                compact: true,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: FlightControl(
                key: const ValueKey('flight-pause'),
                label: _paused ? 'Resume' : 'Hold',
                icon: _paused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                onTap: () {
                  setState(() {
                    _paused = !_paused;
                    _lastTick = _clockMicros;
                  });
                },
                compact: true,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        FlightControl(
          key: const ValueKey('launch-mission'),
          label: _paused ? 'FLIGHT ON HOLD' : 'COMMIT TO LAUNCH',
          icon: Icons.rocket_launch_rounded,
          onTap: _running ? _launch : null,
          primary: true,
          accent: Palette.light,
        ),
      ],
    );
  }

  Widget _ruleStrip() => FlightControl(
    key: const ValueKey('mission-rules'),
    label: 'Flight rules · ${_game.mission.rules.length}',
    icon: Icons.menu_book_rounded,
    onTap: _rules,
  );

  Widget _dailyClock() {
    final duration = _game.dailyResetAt.difference(_now);
    final seconds = math.max(0, duration.inSeconds);
    final hrs = seconds ~/ 3600, mins = seconds ~/ 60 % 60, secs = seconds % 60;
    return Row(
      children: [
        OrbitClock(
          progress: (seconds / 86400).clamp(0, 1),
          readout:
              '${hrs.toString().padLeft(2, '0')}:${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}',
          label: 'Next signal',
          size: 110,
          accent: portalViolet,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: FlightMeter(
            label: 'Orbital window',
            value: _game.dailyCompleted
                ? 'Signal delivered'
                : 'Signal available',
            fraction: 1 - (seconds / 86400).clamp(0, 1),
            accent: portalViolet,
          ),
        ),
      ],
    );
  }

  Widget _mapView() => LayoutBuilder(
    builder: (context, box) => Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
          child: Row(
            children: [
              const Icon(Icons.explore_rounded, color: Palette.rust, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'STELLAR CARTOGRAPHY',
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 1.7,
                        color: Palette.rust,
                      ),
                    ),
                    Text('The Aster expedition', style: bookTitle(24)),
                  ],
                ),
              ),
              SizedBox(
                width: 60,
                child: FlightControl(
                  label: 'Back',
                  icon: Icons.close_rounded,
                  compact: true,
                  onTap: () => setState(() {
                    _phase = _mapReturnPhase;
                    _lastTick = _clockMicros;
                  }),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GalaxyRouteMap(
            highestUnlocked: _game.highestUnlocked,
            currentLevel: _game.campaignLevel,
            totalLevels: Mission.campaignCount,
            onSelect: _travel,
            reducedMotion: _reduced,
            height: box.maxHeight,
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: FlightMeter(
                  label: 'Routes cleared',
                  value:
                      '${_game.completedLevels.length} / ${Mission.campaignCount}',
                  fraction:
                      _game.completedLevels.length / Mission.campaignCount,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: FlightControl(
                  key: const ValueKey('daily-signal'),
                  label: 'Daily signal',
                  icon: Icons.satellite_alt_rounded,
                  onTap: _daily,
                  accent: portalViolet,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _cinematicView() => AnimatedBuilder(
    animation: _cinema,
    builder: (context, _) {
      if (_phase == FlightPhase.travel) {
        return Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _WarpPainter(_reduced ? 1 : _cinema.value),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  OrbitClock(
                    progress: _cinema.value,
                    readout: '${_game.currentLevel}'.padLeft(2, '0'),
                    label: 'Coordinate',
                    size: 130,
                  ),
                  const SizedBox(height: 20),
                  Text(_game.mission.title, style: bookTitle(28)),
                ],
              ),
            ),
          ],
        );
      }
      return Stack(
        children: [
          if (_phase == FlightPhase.flight)
            Positioned.fill(
              child: CockpitFlight(
                mission: _game.mission,
                result: _flight!,
                progress: _cinema.value,
                reducedMotion: _reduced,
              ),
            )
          else
            Center(
              child: RocketLaunchScene(
                height: MediaQuery.sizeOf(context).height * .7,
                countdown: _cinema.value < .6
                    ? math.max(1, (3 - _cinema.value * 5).ceil())
                    : null,
                countdownProgress: (_cinema.value / .6).clamp(0, 1),
                launchProgress: ((_cinema.value - .6) / .4).clamp(0, 1),
                reducedMotion: _reduced,
              ),
            ),
          Positioned(
            top: 22,
            left: 22,
            right: 22,
            child: Semantics(
              liveRegion: true,
              child: Column(
                children: [
                  Text(
                    _phase == FlightPhase.ignition
                        ? 'FLIGHT DIRECTOR · ALL SYSTEMS GO'
                        : 'ONBOARD · LIVE FLIGHT',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      letterSpacing: 2,
                      color: Palette.rust,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _phase == FlightPhase.ignition
                        ? 'Ignition sequence'
                        : 'Follow the signal',
                    style: bookTitle(28),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Row(
              children: [
                Expanded(
                  child: FlightMeter(
                    label: 'Flight recorder',
                    value: _phase == FlightPhase.ignition
                        ? 'Engines armed'
                        : 'Route in progress',
                    fraction: _cinema.value,
                  ),
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 115,
                  child: FlightControl(
                    key: const ValueKey('skip-flight'),
                    label: 'Skip flight',
                    icon: Icons.skip_next_rounded,
                    onTap: () {
                      _cinema.stop();
                      setState(() => _phase = FlightPhase.debrief);
                    },
                    compact: true,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    },
  );

  Future<void> _panel(
    String title,
    Widget Function(StateSetter) content,
  ) async {
    setState(() => _modal = true);
    _lastTick = _clockMicros;
    _cinema.stop();
    await showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close $title',
      barrierColor: const Color(0xDC030814),
      transitionDuration: Duration(milliseconds: _reduced ? 0 : 180),
      pageBuilder: (context, a, b) => SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 500,
                maxHeight: MediaQuery.sizeOf(context).height - 64,
              ),
              child: Material(
                color: const Color(0xFF0E1B30),
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Palette.rust.withValues(alpha: .55),
                    ),
                  ),
                  child: StatefulBuilder(
                    builder: (context, setPanel) => SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.cell_tower_rounded,
                                color: Palette.rust,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(title, style: bookTitle(23)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 22),
                          content(setPanel),
                          const SizedBox(height: 24),
                          FlightControl(
                            key: const ValueKey('close-flight-panel'),
                            label: 'Return to flight',
                            icon: Icons.keyboard_return_rounded,
                            onTap: () => Navigator.pop(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _modal = false;
      _lastTick = _clockMicros;
    });
    if (_cinematic && _running) _cinema.forward();
  }

  void _rules() => _panel(
    'Flight manual',
    (_) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _transmission(
          'MISSION',
          'Turn the route sectors. Fly from the launch beacon, collect every star, and reach the gold dock. A connected route still needs a successful flight.',
        ),
        for (final rule in _game.mission.rules) _transmission('BRIEFING', rule),
        _transmission(
          'LAUNCH WINDOW',
          'Begin Mission arms the countdown. Launch early when ready. At zero, the rocket leaves on the route you have built. Hold, comms, and leaving the app pause the clock.',
        ),
        _transmission(
          'RETRY',
          'A failed flight shows the exact break. Revise & Retry keeps your edits and starts a new attempt with a fresh asteroid forecast. Marked routes show their risk; a safe detour always remains available.',
        ),
      ],
    ),
  );

  Widget _transmission(String label, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.radio_button_checked, size: 16, color: Palette.rust),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.5,
                  color: Palette.rust,
                ),
              ),
              const SizedBox(height: 4),
              Text(text, style: const TextStyle(fontSize: 15, height: 1.4)),
            ],
          ),
        ),
      ],
    ),
  );

  void _inspect(int index) {
    final cell = _game.mission.cells[index];
    _panel(
      'Sector ${index ~/ 5 + 1}.${index % 5 + 1}',
      (_) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Icon(
              _hazardIcon(cell.kind),
              size: 52,
              color: cellAccent(cell.kind),
            ),
          ),
          const SizedBox(height: 16),
          _transmission(cellRole(cell.kind).toUpperCase(), switch (cell.kind) {
            CellKind.lockedRelay => 'This route is bolted into position. Shape the surrounding sectors to meet its openings.',
            CellKind.block => 'This sector is impassable. Plan around it.',
            CellKind.oneWay => 'The arrow is the only allowed direction of flight. Arriving against it loses the signal.',
            CellKind.wormhole => 'Enter this gate to emerge from its paired gate. Continue from the partner’s exit.',
            CellKind.blackHole => 'This gravity fork turns flight clockwise. Inspect the fixed branches before committing.',
            CellKind.whiteHole => 'This gravity fork turns flight counterclockwise. Its pull differs from the black hole.',
            CellKind.slingshot => 'The star boosts the rocket over one sector. The landing route must receive it.',
            CellKind.asteroid =>
              'Collision risk: ${cell.riskPercent}%. The same launch attempt has a stable forecast. A safe detour exists.',
            CellKind.relay =>
              'Tap to turn this route clockwise by one quarter turn.',
          }),
        ],
      ),
    );
  }

  IconData _hazardIcon(CellKind kind) => switch (kind) {
    CellKind.wormhole => Icons.blur_circular_rounded,
    CellKind.block || CellKind.asteroid => Icons.grain_rounded,
    CellKind.blackHole || CellKind.whiteHole => Icons.donut_large_rounded,
    CellKind.slingshot => Icons.stars_rounded,
    CellKind.lockedRelay => Icons.lock_outline_rounded,
    CellKind.oneWay => Icons.arrow_forward_rounded,
    _ => Icons.route_rounded,
  };

  void _settings() => _panel(
    'Flight systems',
    (setPanel) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FlightControl(
          label: 'Mission flight rules',
          icon: Icons.menu_book_rounded,
          onTap: () => setPanel(() => _manualExpanded = !_manualExpanded),
        ),
        const SizedBox(height: 12),
        if (_manualExpanded)
          for (final rule in _game.mission.rules)
            _transmission('FLIGHT MANUAL', rule),
        _option('Untimed planning', Icons.all_inclusive_rounded, _untimed, () {
          _untimed = !_untimed;
          _lastTick = _clockMicros;
          _remaining = _game.mission.timeLimitSeconds.toDouble();
          _saveOption('untimed', _untimed);
          setPanel(() {});
        }),
        _option('Motion sky', Icons.screen_rotation_rounded, _motionSky, () {
          _motionSky = !_motionSky;
          _saveOption('motionSky', _motionSky);
          setPanel(() {});
        }),
        _option(
          'Reduced motion',
          Icons.motion_photos_off_rounded,
          _reduceMotion,
          () {
            _reduceMotion = !_reduceMotion;
            _saveOption('reduceMotion', _reduceMotion);
            setPanel(() {});
          },
        ),
        _option('Haptic signals', Icons.vibration_rounded, _haptics, () {
          _haptics = !_haptics;
          _saveOption('haptics', _haptics);
          setPanel(() {});
        }),
        const SizedBox(height: 14),
        _transmission(
          'MOTION SYSTEM',
          'Phone tilt shifts only the constellations. Motion readings stay on this device. System Reduced Motion also disables the moving sky and cockpit optic flow.',
        ),
        FlightControl(
          label: 'Licenses & typography',
          icon: Icons.info_outline_rounded,
          onTap: () {
            _licenseEntries ??= LicenseRegistry.licenses.toList();
            setPanel(() => _licenseExpanded = !_licenseExpanded);
          },
        ),
        if (_licenseExpanded)
          FutureBuilder<List<LicenseEntry>>(
            future: _licenseEntries,
            builder: (context, snapshot) => Padding(
              padding: const EdgeInsets.only(top: 18),
              child: snapshot.hasData
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (final entry in snapshot.data!) ...[
                          Text(
                            entry.packages.join(' · '),
                            style: const TextStyle(
                              color: Palette.rust,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            entry.paragraphs.map((p) => p.text).join('\n\n'),
                            style: const TextStyle(fontSize: 14),
                          ),
                          const SizedBox(height: 20),
                        ],
                      ],
                    )
                  : const Text('Reading the onboard license registry…'),
            ),
          ),
      ],
    ),
  );

  Widget _option(
    String label,
    IconData icon,
    bool enabled,
    VoidCallback action,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: FlightControl(
      key: ValueKey('option-$label'),
      label: '$label · ${enabled ? 'ON' : 'OFF'}',
      value: enabled ? 'On' : 'Off',
      icon: icon,
      onTap: action,
      accent: enabled ? Palette.rust : Palette.secondary,
    ),
  );
  void _saveOption(String name, bool value) {
    unawaited(_preferences?.setBool('glowpath.flight.$name', value));
    setState(() {});
  }
}

class _MissionNumberPainter extends CustomPainter {
  @override
  void paint(Canvas c, Size s) {
    final p = Paint()
      ..color = Palette.rust
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final center = s.center(Offset.zero);
    c.drawCircle(
      center,
      s.width * .42,
      p..color = Palette.rust.withValues(alpha: .2),
    );
    c.drawArc(
      Rect.fromCircle(center: center, radius: s.width * .47),
      -.6,
      4.4,
      false,
      p..color = Palette.rust,
    );
    c.drawLine(Offset(0, s.height * .5), Offset(8, s.height * .5), p);
    c.drawLine(
      Offset(s.width - 8, s.height * .5),
      Offset(s.width, s.height * .5),
      p,
    );
  }

  @override
  bool shouldRepaint(_MissionNumberPainter old) => false;
}

class _WarpPainter extends CustomPainter {
  const _WarpPainter(this.progress);
  final double progress;
  @override
  void paint(Canvas c, Size s) {
    final center = s.center(Offset.zero), r = math.Random(37);
    for (var i = 0; i < 90; i++) {
      final a = r.nextDouble() * math.pi * 2,
          d = r.nextDouble() * s.longestSide * .6;
      final v = Offset(math.cos(a), math.sin(a));
      c.drawLine(
        center + v * d,
        center + v * (d + progress * 100),
        Paint()
          ..color = (i % 5 == 0 ? Palette.rust : Palette.white).withValues(
            alpha: .15 + progress * .5,
          )
          ..strokeWidth = 1 + r.nextDouble(),
      );
    }
  }

  @override
  bool shouldRepaint(_WarpPainter old) => progress != old.progress;
}
