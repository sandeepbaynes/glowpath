import Foundation

@main
struct SpatialPuzzleChecks {
    static func main() throws {
        let level = SpatialLevel.standard
        precondition(level.tileCount == 18 && level.route.count == 18)
        precondition(Set(level.route).count == 18)
        precondition(level.startIndex == 6 && level.endIndex == 9)
        precondition(level.starIndices.count == 3)

        // Seam connections are actual neighbors; the top and bottom stop.
        precondition(level.neighbor(of: 0, through: 8) == 5)
        precondition(level.neighbor(of: 5, through: 2) == 0)
        precondition(level.neighbor(of: 17, through: 2) == 12)
        precondition(level.neighbor(of: 0, through: 1) == nil)
        precondition(level.neighbor(of: 17, through: 4) == nil)
        precondition(level.neighbor(of: level.startIndex, through: level.entrance) == nil)
        precondition(level.neighbor(of: level.endIndex, through: level.exit) == nil)

        var puzzle = SpatialPuzzle()
        precondition(!puzzle.evaluation.complete, "The opening arrangement must need work")
        puzzle.masks = level.solutionMasks
        precondition(puzzle.evaluation.complete)
        precondition(puzzle.evaluation.collected == 3)
        precondition(puzzle.evaluation.orderedRoute == level.route)

        // Remove the external START connection and the entire route is dark.
        puzzle.masks[level.startIndex] = 3
        precondition(puzzle.evaluation.lit.isEmpty && !puzzle.evaluation.complete)

        // A break beyond the rear seam lights only the prefix, not later stars.
        puzzle.masks = level.solutionMasks
        puzzle.masks[11] = 10
        precondition(puzzle.evaluation.orderedRoute == [6, 0, 5])
        precondition(puzzle.evaluation.collected == 1)
        precondition(!puzzle.evaluation.complete)

        // A short direct route reaches FINISH but cannot omit the three stars.
        puzzle.masks = [Int](repeating: 10, count: 18)
        precondition(puzzle.evaluation.orderedRoute == [6, 7, 8, 9])
        precondition(!puzzle.evaluation.complete && puzzle.evaluation.collected == 0)

        puzzle.reset()
        let original = puzzle.masks
        for _ in 0..<4 { precondition(puzzle.rotate(5)) }
        precondition(puzzle.masks == original, "Four rotations must preserve the piece")
        precondition(!puzzle.rotate(-1) && !puzzle.rotate(18))

        // A held half-turn may pass a solved position; only release commits.
        puzzle.masks = level.solutionMasks
        let elbow = level.startIndex
        for _ in 0..<3 { puzzle.masks[elbow] = SpatialPuzzle.rotatedClockwise(puzzle.masks[elbow]) }
        precondition(puzzle.rotate(elbow, quarterTurns: 2))
        precondition(puzzle.masks[elbow] == SpatialPuzzle.rotatedClockwise(level.solutionMasks[elbow]))
        precondition(!puzzle.evaluation.complete)
        precondition(puzzle.rotate(elbow, quarterTurns: -1))
        precondition(puzzle.evaluation.complete)
        puzzle.reset()

        var hints = 0
        while let _ = puzzle.hint() {
            hints += 1
            precondition(hints <= level.tileCount, "Hints must converge")
        }
        precondition(hints > 0 && puzzle.evaluation.complete)
        precondition(puzzle.hint() == nil && !puzzle.rotate(0))
        puzzle.reset()
        precondition(puzzle.masks == level.initialMasks && !puzzle.evaluation.complete)

        // Defensive trace: malformed pieces and missing masks never crash.
        puzzle.masks[level.startIndex] = 15
        precondition(!puzzle.evaluation.complete && puzzle.evaluation.lit.isEmpty)
        puzzle.masks = []
        precondition(puzzle.evaluation.lit.isEmpty)

        if CommandLine.arguments.contains("--export") {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(level)
            FileHandle.standardOutput.write(data)
            print("")
        } else {
            let path = CommandLine.arguments.dropFirst().first ?? "spatial/levels/first-orbit.json"
            let exported = try JSONDecoder().decode(SpatialLevel.self, from: Data(contentsOf: URL(fileURLWithPath: path)))
            precondition(exported == level, "The cross-engine JSON contract must match the native level")
            print("Spatial route checks passed: wrap, endpoints, 3D orbit route, stars, rotation, hints, reset and JSON parity.")
        }
    }
}
