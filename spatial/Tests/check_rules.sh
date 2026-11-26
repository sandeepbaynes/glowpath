#!/bin/sh
set -eu
cd "$(dirname "$0")/../.."
task_build="$(mktemp -d "${TMPDIR:-/tmp}/glowpath-spatial-checks.XXXXXX")"
trap 'rm -rf "$task_build"' EXIT HUP INT TERM
xcrun swiftc -module-cache-path "$task_build/ModuleCache" -parse-as-library spatial/Shared/SpatialPuzzle.swift spatial/Tests/SpatialPuzzleChecks.swift -o "$task_build/checks"
"$task_build/checks" "$@"
