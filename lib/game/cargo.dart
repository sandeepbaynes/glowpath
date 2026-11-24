/// Cargo is a visible, optional reward. It never changes whether a route wins.
enum CargoPower { none, time, lens }

enum CargoKind {
  moonPearl(
    'Moon pearl',
    'A polished fragment from a quiet lunar sea.',
    0xFFD5E9EA,
  ),
  cometShard(
    'Comet shard',
    'A bright fragment carried between distant worlds.',
    0xFFE8C794,
  ),
  dawnPrism(
    'Dawn prism',
    'A rare prism found during the morning signal window.',
    0xFFECCAA9,
    isRare: true,
  ),
  nightOpal(
    'Night opal',
    'A rare opal found during the evening signal window.',
    0xFFC4B5E7,
    isRare: true,
  ),
  chronoCell(
    'Chrono cell',
    'Store a charge to add eight seconds to a future flight.',
    0xFF9CDBD1,
    power: CargoPower.time,
  ),
  routeLens(
    'Route lens',
    'Store a charge to align up to three relays on a future route.',
    0xFFA8C9ED,
    power: CargoPower.lens,
  );

  const CargoKind(
    this.label,
    this.description,
    this.colorValue, {
    this.isRare = false,
    this.power = CargoPower.none,
  });
  final String label, description;
  final int colorValue;
  final bool isRare;
  final CargoPower power;
  bool get rare => isRare;
  String get windowLabel => switch (this) {
    dawnPrism => '06:00–10:00 local time',
    nightOpal => '18:00–22:00 local time',
    _ => 'Any time',
  };
  bool availableAt(DateTime now) => switch (this) {
    dawnPrism => now.hour >= 6 && now.hour < 10,
    nightOpal => now.hour >= 18 && now.hour < 22,
    _ => true,
  };
}

/// The encounter is pinned when an attempt begins. Crossing a clock boundary,
/// pausing or resuming never removes a collectible already visible on the board.
/// Local clock windows are a discovery feature, not trusted server-side scarcity.
class CargoEncounter {
  const CargoEncounter._({
    required this.kind,
    required this.cell,
    required this.levelNumber,
    required this.claimKey,
  });
  final CargoKind kind;
  final int cell, levelNumber;
  final String claimKey;
  String get windowKey => claimKey;
  String get windowLabel => kind.windowLabel;

  factory CargoEncounter.forRound({
    required int level,
    required int cell,
    required DateTime now,
  }) {
    if (level < 1 || cell < 0 || cell >= 25) {
      throw ArgumentError('Cargo requires a valid route and cell.');
    }
    // The four ordinary rewards cycle independently of the clock. A replay
    // cannot reroll a different common object by waiting a few minutes.
    const common = [
      CargoKind.moonPearl,
      CargoKind.cometShard,
      CargoKind.chronoCell,
      CargoKind.routeLens,
    ];
    final slot = (level - 31) ~/ 5;
    var kind = common[((slot % common.length) + common.length) % common.length];
    // Every third salvage route is a recurring rare-object rendezvous.
    if (slot % 3 == 0) {
      if (CargoKind.dawnPrism.availableAt(now)) {
        kind = CargoKind.dawnPrism;
      } else if (CargoKind.nightOpal.availableAt(now)) {
        kind = CargoKind.nightOpal;
      }
    }
    final date =
        '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
    return CargoEncounter._(
      kind: kind,
      cell: cell,
      levelNumber: level,
      claimKey: 'cargo/$level/${kind.name}${kind.isRare ? '/$date' : ''}',
    );
  }

  Map<String, dynamic> toJson() => {
    'kind': kind.name,
    'cell': cell,
    'level': levelNumber,
    'claimKey': claimKey,
  };
  static CargoEncounter? fromJson(Object? value) {
    if (value is! Map<String, dynamic>) return null;
    final kindName = value['kind'],
        cell = value['cell'],
        level = value['level'];
    final claim = value['claimKey'];
    if (cell is! int ||
        cell < 0 ||
        cell >= 25 ||
        level is! int ||
        level < 1 ||
        claim is! String ||
        claim.length > 100) {
      return null;
    }
    CargoKind? kind;
    for (final candidate in CargoKind.values) {
      if (candidate.name == kindName) kind = candidate;
    }
    if (kind == null) return null;
    final prefix = 'cargo/$level/${kind.name}';
    if (kind.isRare) {
      if (!claim.startsWith('$prefix/')) return null;
      final date = claim.substring(prefix.length + 1);
      final parsed = DateTime.tryParse(date);
      if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(date) ||
          parsed == null ||
          '${parsed.year.toString().padLeft(4, '0')}-'
                  '${parsed.month.toString().padLeft(2, '0')}-'
                  '${parsed.day.toString().padLeft(2, '0')}' !=
              date) {
        return null;
      }
    } else if (claim != prefix) {
      return null;
    }
    return CargoEncounter._(
      kind: kind,
      cell: cell,
      levelNumber: level,
      claimKey: claim,
    );
  }
}
