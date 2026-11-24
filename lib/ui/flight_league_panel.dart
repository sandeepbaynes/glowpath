import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../services/flight_league.dart';
import 'design.dart';
import 'space_controls.dart';
import 'observatory_art.dart';

/// Larger text reduces ranks per page, keeping the controls in view.
class FlightLeaguePanel extends StatefulWidget {
  const FlightLeaguePanel({
    super.key,
    required this.league,
    this.reduceMotion = false,
  });
  final FlightLeague league;
  final bool reduceMotion;
  @override
  State<FlightLeaguePanel> createState() => _FlightLeaguePanelState();
}

class _FlightLeaguePanelState extends State<FlightLeaguePanel> {
  String _mode = 'daily';
  bool _busy = true;
  String? _error, _pilotId;
  List<dynamic> _entries = [];
  int _page = 0, _request = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.league.load();
      if (!mounted || request != _request) return;
      if (widget.league.joined && widget.league.configured) {
        final data = await widget.league.standings(_mode);
        if (!mounted || request != _request) return;
        _entries = data['entries'] as List<dynamic>;
        _pilotId = data['pilotId'] as String?;
      } else {
        _entries = [];
      }
    } catch (e) {
      if (!mounted || request != _request) return;
      _error = e.toString();
    }
    if (mounted && request == _request) setState(() => _busy = false);
  }

  Future<void> _join() async {
    setState(() => _busy = true);
    try {
      await widget.league.join();
      if (mounted) await _load();
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _leave() async {
    setState(() => _busy = true);
    try {
      await widget.league.leave();
      if (!mounted) return;
      _entries = [];
      _page = 0;
      _error = null;
    } catch (e) {
      if (!mounted) return;
      _error = e.toString();
    }
    if (mounted) setState(() => _busy = false);
  }

  Widget _copy(String full, String compact, {required bool dense}) => Semantics(
    label: full,
    child: ExcludeSemantics(
      child: Text(
        dense ? compact : full,
        maxLines: dense ? 3 : 6,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: dense ? 14 : 17,
          height: 1.25,
          color: Palette.secondary,
        ),
      ),
    ),
  );

  Widget _icon({
    required String keyName,
    required String label,
    required IconData icon,
    VoidCallback? onPressed,
  }) => Semantics(
    button: true,
    enabled: onPressed != null,
    label: label,
    onTap: onPressed,
    child: ExcludeSemantics(
      child: IgnorePointer(
        ignoring: onPressed == null,
        child: Opacity(
          opacity: onPressed == null ? .35 : 1,
          child: OrbitUtility(
            key: ValueKey(keyName),
            label: label,
            icon: icon,
            onPressed: onPressed ?? () {},
            width: 48,
            reduceMotion: widget.reduceMotion,
          ),
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, bounds) {
      final scale = MediaQuery.textScalerOf(context);
      final dense = scale.scale(1) > 1.7 || bounds.maxHeight < 460;
      final demo = widget.league.isMock;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            label: demo
                ? 'Preview league. Local demo with simulated rivals. Your scores stay on this device.'
                : 'Flight league. Unassisted clears; best score per route.',
            child: ExcludeSemantics(
              child: Row(
                children: [
                  OrbitalEmblem(
                    size: dense ? 24 : 34,
                    color: Palette.light,
                    variant: 3,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      demo
                          ? (dense ? 'Demo rivals' : 'Preview league')
                          : 'Flight league',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: bookTitle(dense ? 16 : 29),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (demo && !dense)
            const Padding(
              padding: EdgeInsets.only(top: 5),
              child: Text(
                'LOCAL DEMO · SIMULATED RIVALS',
                style: TextStyle(color: Palette.secondary, fontSize: 12),
              ),
            ),
          if (!widget.league.configured)
            Expanded(
              child: Center(
                child: _copy(
                  'The league opens soon. Daily and weekly routes are ready to practice.',
                  'League opens soon.\nKeep practicing.',
                  dense: dense,
                ),
              ),
            )
          else if (!widget.league.joined) ...[
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!dense) ...[
                      const OrbitalEmblem(size: 110, variant: 3),
                      const SizedBox(height: 24),
                    ],
                    _copy(
                      _error ??
                          (demo
                              ? 'Try daily and weekly rankings against simulated rivals. Your scores stay on this device. Shared competition will be connected later.'
                              : 'Join with an anonymous callsign. Your completed challenge routes and scores are shared; your name and contacts stay private.'),
                      _error != null
                          ? 'Connection failed.\nTry again.'
                          : demo
                          ? 'Local scores.\nSimulated rivals.'
                          : 'Anonymous pilot.\nShared scores.',
                      dense: dense,
                    ),
                  ],
                ),
              ),
            ),
            SpaceAction(
              key: const ValueKey('league-join'),
              label: _busy
                  ? 'Joining…'
                  : demo
                  ? 'Join demo'
                  : 'Join league',
              compact: dense,
              icon: Icons.public_rounded,
              onPressed: _busy ? null : _join,
              reduceMotion: widget.reduceMotion,
            ),
          ] else ...[
            Row(
              children: [
                for (final mode in ['daily', 'weekly'])
                  Expanded(
                    child: OrbitMode(
                      key: ValueKey('league-$mode'),
                      label: mode == 'daily' ? 'Daily' : 'Weekly',
                      selected: _mode == mode,
                      onPressed: _busy
                          ? null
                          : () {
                              _mode = mode;
                              _page = 0;
                              _load();
                            },
                      reduceMotion: widget.reduceMotion,
                    ),
                  ),
              ],
            ),
            Expanded(
              child: LayoutBuilder(
                builder: (context, available) {
                  final listHeight = math.max(0.0, available.maxHeight - 64);
                  final rowMinimum = math.max(60.0, scale.scale(18) * 1.3 + 16);
                  final rows = (listHeight / rowMinimum).floor().clamp(1, 6);
                  final pages = math.max(1, (_entries.length / rows).ceil());
                  final page = _page.clamp(0, pages - 1);
                  return Column(
                    children: [
                      Expanded(
                        child: _busy
                            ? const Center(child: CircularProgressIndicator())
                            : _error != null
                            ? Center(
                                child: _copy(
                                  _error!,
                                  'Could not load.\nTap refresh.',
                                  dense: dense,
                                ),
                              )
                            : _entries.isEmpty
                            ? Center(
                                child: _copy(
                                  'Clear a challenge without a hint to post your first score.',
                                  'Clear a route.\nPost a score.',
                                  dense: dense,
                                ),
                              )
                            : Column(
                                children: [
                                  for (final (offset, entry)
                                      in _entries
                                          .skip(page * rows)
                                          .take(rows)
                                          .indexed)
                                    Expanded(
                                      child: _Rank(
                                        entry: entry as Map<String, dynamic>,
                                        rank: page * rows + offset + 1,
                                        current: entry['id'] == _pilotId,
                                        dense: dense,
                                      ),
                                    ),
                                ],
                              ),
                      ),
                      Row(
                        children: [
                          _icon(
                            keyName: 'league-previous',
                            label: 'Previous ranks',
                            icon: Icons.chevron_left_rounded,
                            onPressed: !_busy && page > 0
                                ? () => setState(() => _page = page - 1)
                                : null,
                          ),
                          Expanded(
                            child: Semantics(
                              label: 'Rank page ${page + 1} of $pages',
                              child: ExcludeSemantics(
                                child: Text(
                                  '${page + 1}/$pages',
                                  maxLines: 1,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Palette.secondary,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          _icon(
                            keyName: 'league-next',
                            label: 'Next ranks',
                            icon: Icons.chevron_right_rounded,
                            onPressed: !_busy && page + 1 < pages
                                ? () => setState(() => _page = page + 1)
                                : null,
                          ),
                          _icon(
                            keyName: 'league-refresh',
                            label: 'Refresh rankings',
                            icon: Icons.refresh_rounded,
                            onPressed: _busy ? null : _load,
                          ),
                          _icon(
                            keyName: 'league-leave',
                            label: demo
                                ? 'Delete local preview scores and leave'
                                : 'Delete my scores and leave league',
                            icon: Icons.logout_rounded,
                            onPressed: _busy ? null : _leave,
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ],
      );
    },
  );
}

class _Rank extends StatelessWidget {
  const _Rank({
    required this.entry,
    required this.rank,
    required this.current,
    required this.dense,
  });
  final Map<String, dynamic> entry;
  final int rank;
  final bool current, dense;

  @override
  Widget build(BuildContext context) => Semantics(
    label:
        'Rank $rank. ${entry['name']}. ${entry['score']} points from ${entry['routes']} routes.${current ? ' Your score.' : ''}',
    child: ExcludeSemantics(
      child: Container(
        key: ValueKey('league-rank-$rank'),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Palette.line.withValues(alpha: .5)),
          ),
          color: current ? Palette.rust.withValues(alpha: .06) : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            Text(
              '$rank',
              style: TextStyle(
                color: Palette.secondary,
                fontSize: dense ? 14 : 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    current ? 'You' : entry['name'] as String,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: dense ? 14 : 16,
                      color: Palette.white,
                    ),
                  ),
                  if (!dense) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${entry['routes']} routes charted',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Palette.secondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              '${entry['score']}',
              style: TextStyle(color: Palette.rust, fontSize: dense ? 18 : 22),
            ),
          ],
        ),
      ),
    ),
  );
}
