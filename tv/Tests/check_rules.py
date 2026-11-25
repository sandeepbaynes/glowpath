#!/usr/bin/env python3
"""Run the tvOS preview's actual routing engine against deterministic checks.

The engine uses SwiftUI's ObservableObject but no platform UI; compiling this
extracted section for the host avoids introducing a simulator-only test target.
No rule implementation is duplicated in this harness.
"""
from pathlib import Path
import subprocess
import tempfile

source = (Path(__file__).parents[1] / 'GlowpathTV/GlowpathTVApp.swift').read_text()
engine = source[source.index('private let routePlans'):source.index('private struct StarMark')]
checks = r'''
@main struct RuleChecks {
    @MainActor static func main() {
        let suite = "app.glowpath.tvpreview.tests.\(UUID().uuidString)"
        let storage = UserDefaults(suiteName: suite)!
        defer { storage.removePersistentDomain(forName: suite) }
        let mission = TVMission(storage: storage)
        for level in 1...150 {
            mission.level = level
            mission.prepare()
            precondition(mission.remaining == 90 && !mission.started)
            precondition(mission.stars.count == 3)
            precondition(mission.masks.allSatisfy { $0.nonzeroBitCount == 2 })
            for _ in 0..<10 where mission.result == nil { mission.hint() }
            precondition(mission.result == true, "Unsolvable preview route \(level)")
            precondition(mission.collected == 3)
            precondition(mission.hintUsed)
        }
        mission.level = 1
        mission.prepare()
        mission.hint()
        mission.setActive(false)
        let paused = mission.remaining
        mission.tick(Date().addingTimeInterval(1000))
        precondition(mission.remaining == paused && mission.result == nil)
        mission.setActive(true)
        mission.tick(Date().addingTimeInterval(1000))
        precondition(mission.result == false && mission.remaining == 0)
        let retained = mission.masks
        mission.retry()
        precondition(mission.remaining == 90 && mission.result == nil && !mission.started)
        precondition(mission.masks == retained && mission.hintUsed)
        print("150 solvable routes; star collection, pause, timeout and retry checks passed.")
    }
}
'''
with tempfile.TemporaryDirectory(prefix='glowpath-tv-checks-') as temp:
    swift = Path(temp) / 'RuleChecks.swift'
    swift.write_text('import SwiftUI\nimport Foundation\n' + engine + checks)
    binary = Path(temp) / 'checks'
    subprocess.run(['xcrun', 'swiftc', '-parse-as-library', str(swift), '-o', str(binary)], check=True)
    subprocess.run([str(binary)], check=True)
