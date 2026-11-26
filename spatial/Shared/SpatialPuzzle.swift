import Foundation

/// Renderer-independent routes for the immersive prototype.
///
/// Tiles occupy three elevation bands around the player. Columns wrap at the
/// rear seam; rows do not wrap. Coordinates are a renderer concern. Port bits
/// run clockwise: north/up = 1, east = 2, south/down = 4, west = 8.
struct SpatialLevel: Codable, Equatable, Sendable {
    let schemaVersion: Int
    let id: String
    let rows: Int
    let columns: Int
    let startIndex: Int
    let endIndex: Int
    let entrance: Int
    let exit: Int
    let solutionMasks: [Int]
    let initialMasks: [Int]
    let starIndices: [Int]
    let route: [Int]

    var tileCount: Int { rows * columns }

    func index(row: Int, column: Int) -> Int? {
        guard row >= 0, row < rows, column >= 0, column < columns else { return nil }
        return row * columns + column
    }

    /// External endpoint ports have no neighboring tile. All other east/west
    /// ports wrap around the player, including at columns zero and five.
    func neighbor(of index: Int, through port: Int) -> Int? {
        guard (0..<tileCount).contains(index) else { return nil }
        if (index == startIndex && port == entrance) || (index == endIndex && port == exit) {
            return nil
        }
        let row = index / columns
        let column = index % columns
        switch port {
        case 1: return self.index(row: row - 1, column: column)
        case 2: return self.index(row: row, column: (column + 1) % columns)
        case 4: return self.index(row: row + 1, column: column)
        case 8: return self.index(row: row, column: (column + columns - 1) % columns)
        default: return nil
        }
    }

    /// A full orbit: left START, upper and lower elevations, front and rear
    /// connections, then right FINISH. JSON exports use this same contract.
    static let standard: SpatialLevel = {
        let route = [6, 0, 5, 11, 17, 12, 13, 7, 1, 2, 8, 14, 15, 16, 10, 4, 3, 9]
        let columns = 6
        func direction(from a: Int, to b: Int) -> Int {
            if b == a - columns { return 1 }
            if b == a + columns { return 4 }
            if a / columns == b / columns && (a % columns + 1) % columns == b % columns { return 2 }
            return 8
        }
        var solution = [Int](repeating: 5, count: 18)
        for (position, tile) in route.enumerated() {
            let incoming = position == 0 ? 8 : direction(from: tile, to: route[position - 1])
            let outgoing = position == route.count - 1 ? 2 : direction(from: tile, to: route[position + 1])
            solution[tile] = incoming | outgoing
        }
        let initial = solution.enumerated().map { index, mask in
            var rotated = mask
            for _ in 0..<((index * 7 + 1) % 3 + 1) {
                rotated = SpatialPuzzle.rotatedClockwise(rotated)
            }
            return rotated
        }
        return SpatialLevel(
            schemaVersion: 1, id: "first-orbit", rows: 3, columns: columns,
            startIndex: 6, endIndex: 9, entrance: 8, exit: 2,
            solutionMasks: solution, initialMasks: initial,
            starIndices: [5, 14, 10], route: route
        )
    }()
}

struct SpatialEvaluation: Equatable, Sendable {
    let lit: Set<Int>
    let collected: Int
    let complete: Bool
    let orderedRoute: [Int]
}

struct SpatialPuzzle: Sendable {
    let level: SpatialLevel
    var masks: [Int]

    init(level: SpatialLevel = .standard) {
        self.level = level
        masks = level.initialMasks
    }

    static func rotatedClockwise(_ mask: Int) -> Int {
        ((mask << 1) & 15) | ((mask >> 3) & 1)
    }

    static func opposite(_ port: Int) -> Int {
        switch port {
        case 1: return 4
        case 2: return 8
        case 4: return 1
        case 8: return 2
        default: return 0
        }
    }

    @discardableResult
    mutating func rotate(_ index: Int, quarterTurns: Int = 1) -> Bool {
        guard masks.indices.contains(index), !evaluation.complete else { return false }
        let turns = ((quarterTurns % 4) + 4) % 4
        guard turns != 0 else { return false }
        // A grab commits only its final orientation. Passing through a solved
        // orientation while turning must not stop the remaining rotation.
        for _ in 0..<turns { masks[index] = Self.rotatedClockwise(masks[index]) }
        return true
    }

    /// Align the next incorrect piece along the authored route.
    @discardableResult
    mutating func hint() -> Int? {
        guard !evaluation.complete,
              let index = level.route.first(where: {
                  masks.indices.contains($0) && level.solutionMasks.indices.contains($0)
                      && masks[$0] != level.solutionMasks[$0]
              }) else { return nil }
        masks[index] = level.solutionMasks[index]
        return index
    }

    mutating func reset() {
        masks = level.initialMasks
    }

    var evaluation: SpatialEvaluation {
        var lit = Set<Int>()
        var ordered = [Int]()
        var index = level.startIndex
        var incoming = level.entrance
        var reachedFinish = false

        while masks.indices.contains(index), !lit.contains(index) {
            let mask = masks[index]
            // The prototype only has two-port pieces. Malformed input must
            // stop safely instead of making an arbitrary branch choice.
            guard mask >= 0, mask <= 15, mask.nonzeroBitCount == 2,
                  mask & incoming != 0 else { break }
            lit.insert(index)
            ordered.append(index)
            let outgoing = mask ^ incoming
            if index == level.endIndex && outgoing == level.exit {
                reachedFinish = true
                break
            }
            guard let next = level.neighbor(of: index, through: outgoing) else { break }
            index = next
            incoming = Self.opposite(outgoing)
        }
        let collected = Set(level.starIndices).intersection(lit).count
        return SpatialEvaluation(
            lit: lit, collected: collected,
            complete: reachedFinish && collected == Set(level.starIndices).count,
            orderedRoute: ordered
        )
    }
}
