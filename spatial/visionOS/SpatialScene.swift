import ARKit
import Foundation
import QuartzCore
import RealityKit
import SwiftUI
import UIKit

struct SpatialInteractable: Component {}

@MainActor
final class SpatialScene: ObservableObject {
    enum Mode { case map, puzzle }
    @Published private(set) var mode: Mode = .map
    @Published private(set) var selectedPlanet = 0
    @Published private(set) var puzzle = SpatialPuzzle()
    @Published private(set) var status = "A galaxy around you."
    @Published private(set) var flying = false
    @Published private(set) var trackingStatus = ""

    let root = Entity()
    let instrument = Entity()
    private let galaxy = Entity()
    private let chamber = Entity()
    private let orbitControl = Entity()
    private let session = ARKitSession()
    private let worldTracking = WorldTrackingProvider()
    private var built = false
    private var running = false
    private var lastUpdate = CACurrentMediaTime()
    private var lastHead = SIMD3<Float>(0, 1.6, 0)
    private var lastHeading: Float = 0
    private var originHeading: Float = 0
    private var originHead: SIMD3<Float>?
    private var yaw: Float = 0
    private var targetYaw: Float = 0
    private var pitch: Float = 0
    private var targetPitch: Float = 0
    private var travel: Float = 0
    private var targetTravel: Float = 0
    private var dragName: String?
    private var dragYaw: Float = 0
    private var dragPitch: Float = 0
    private var tileDragTurns = 0
    private var isDraggingOrbit = false
    private var ship: Entity?
    private var flightPoints: [SIMD3<Float>] = []
    private var flightDistance: Float = 0
    private var flightDistances: [Float] = []
    private var flightStart: TimeInterval?
    private var pauseStarted: TimeInterval?
    var reducedMotion = false
    var active = true {
        didSet {
            guard oldValue != active else { return }
            if !active {
                pauseStarted = CACurrentMediaTime()
                cancelManipulation()
            } else {
                if let paused = pauseStarted, let start = flightStart {
                    flightStart = start + CACurrentMediaTime() - paused
                }
                pauseStarted = nil
                lastUpdate = CACurrentMediaTime()
            }
        }
    }

    func build() {
        guard !built else { return }
        built = true
        SpatialInteractable.registerComponent()
        root.name = "glowpath-spatial-world"
        root.addChild(SpatialGeometry.universe())
        root.addChild(galaxy)
        root.addChild(chamber)
        root.addChild(instrument)
        root.addChild(orbitControl)
        galaxy.position = [0, 1.45, 0]
        chamber.position = [0, 1.45, 0]
        for index in 0..<12 {
            let planet = SpatialGeometry.planet(index: index)
            planet.components.set(SpatialInteractable())
            let angle = Float(index) * 2.39996
            let distance = Float(3.8 + Double(index) * 0.65)
            planet.position = [sin(angle) * distance,
                               0.15 + sin(Float(index) * 1.7) * 1.15,
                               -cos(angle) * distance]
            galaxy.addChild(planet)
        }
        makeOrbitControl()
        enterMap()
        #if DEBUG
        // Repeatable simulator composition checks; never enabled in release.
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--preview-route") { enterPuzzle() }
        if arguments.contains("--preview-solved") {
            enterPuzzle()
            while puzzle.hint() != nil {}
            drawPuzzle()
            completeIfReady()
        }
        #endif
    }

    private func makeOrbitControl() {
        // An actual object in the scene, graspable from any side. This rotates
        // the route/galaxy independently of the player's tracked viewpoint.
        orbitControl.name = "orbit-handle"
        let center = SIMD3<Float>(0, 0.86, 0)
        for index in 0..<72 {
            let a = Float(index) * .pi * 2 / 72
            let b = Float(index + 1) * .pi * 2 / 72
            let p = center + SIMD3<Float>(sin(a) * 0.74, 0, -cos(a) * 0.74)
            let q = center + SIMD3<Float>(sin(b) * 0.74, 0, -cos(b) * 0.74)
            let segment = SpatialGeometry.rail(from: p, to: q,
                color: UIColor(red: 0.36, green: 0.65, blue: 0.68, alpha: 1), radius: 0.009)
            segment.name = "orbit-handle"
            segment.generateCollisionShapes(recursive: true)
            segment.components.set(InputTargetComponent())
            segment.components.set(HoverEffectComponent())
            segment.components.set(SpatialInteractable())
            orbitControl.addChild(segment)
        }
    }

    func enterMap() {
        cancelManipulation()
        flying = false
        ship?.removeFromParent()
        ship = nil
        flightStart = nil
        mode = .map
        chamber.isEnabled = false
        galaxy.isEnabled = true
        status = "World \(selectedPlanet + 1) · Look beyond the horizon."
    }

    func enterPuzzle() {
        mode = .puzzle
        galaxy.isEnabled = false
        chamber.isEnabled = true
        targetYaw = 0
        yaw = 0
        targetPitch = 0
        pitch = 0
        targetTravel = 0
        travel = 0
        status = "The route surrounds you."
        drawPuzzle()
        completeIfReady()
    }

    func resetPuzzle() {
        guard !flying else { return }
        puzzle.reset()
        status = "Turn each joint. Follow the light."
        drawPuzzle()
    }

    func hint() {
        guard mode == .puzzle, !flying else { return }
        if let index = puzzle.hint() {
            // Turn the puzzle gently so an off-screen hint can be found seated.
            face(angle: -.pi / 2 + Float(index % 6) * .pi / 3)
            status = "One joint aligned. Follow the illuminated route."
            drawPuzzle()
            completeIfReady()
        }
    }

    func browse(_ step: Int) {
        selectedPlanet = min(11, max(0, selectedPlanet + step))
        face(angle: Float(selectedPlanet) * 2.39996)
        status = "World \(selectedPlanet + 1) · Touch to explore."
    }

    func turnWorld(_ step: Int) { targetYaw += Float(step) * .pi / 6 }
    func tiltWorld(_ step: Int) { targetPitch = min(0.65, max(-0.65, targetPitch + Float(step) * .pi / 12)) }

    private func face(angle: Float) {
        targetYaw = yaw + atan2(sin(angle - yaw), cos(angle - yaw))
    }

    func recenter() {
        // Recenter only on explicit request. Do not tether the camera or
        // continuously drag the puzzle along with the user's head movement.
        originHead = lastHead
        originHeading = lastHeading
        root.position = [lastHead.x, 0, lastHead.z]
        root.orientation = simd_quatf(angle: lastHeading, axis: [0, 1, 0])
        targetYaw = 0
        targetPitch = 0
        targetTravel = 0
        status = mode == .map ? "Your orbit is centered." : "START left. FINISH right."
    }

    private func interactiveRoot(_ entity: Entity) -> Entity {
        var current = entity
        while current.name.isEmpty, let parent = current.parent { current = parent }
        return current
    }

    func tap(_ entity: Entity) {
        let target = interactiveRoot(entity)
        if target.name.hasPrefix("tile-"), mode == .puzzle, !flying,
           let index = Int(target.name.dropFirst(5)) {
            guard puzzle.rotate(index) else { return }
            drawPuzzle()
            completeIfReady()
        } else if target.name.hasPrefix("planet-"),
                  let index = Int(target.name.dropFirst(7)) {
            selectedPlanet = index
            status = "World \(index + 1) selected. Chart its orbital route."
            target.scale = SIMD3<Float>(repeating: 1.07)
            var settled = target.transform
            settled.scale = .one
            target.move(to: settled, relativeTo: target.parent, duration: 0.45, timingFunction: .easeInOut)
        }
    }

    func drag(_ entity: Entity, translation: SIMD3<Float>) {
        let target = interactiveRoot(entity)
        guard !flying else { return }
        // Gesture deltas arrive in scene coordinates. Recenter changes the
        // world's heading, so interpret navigation relative to that heading.
        let localDelta = root.orientation(relativeTo: nil).inverse.act(translation)
        if dragName != target.name {
            dragName = target.name
            dragYaw = targetYaw
            dragPitch = targetPitch
            tileDragTurns = 0
        }
        if target.name.hasPrefix("tile-") {
            // A held pipe follows the hand continuously then snaps to a legal
            // quarter-turn on release. No scene movement is needed to edit it.
            let parentDelta = target.parent?.orientation(relativeTo: nil).inverse.act(translation) ?? translation
            let normal = simd_normalize(SIMD3<Float>(target.position.x, 0, target.position.z))
            let tangent = simd_cross(normal, SIMD3<Float>(0, 1, 0))
            let amount = (simd_dot(parentDelta, tangent) + parentDelta.y) * 4
            tileDragTurns = Int((amount / (.pi / 2)).rounded())
            target.orientation = simd_quatf(angle: amount, axis: normal)
            target.scale = SIMD3<Float>(repeating: 1.04)
        } else if target.name.hasPrefix("planet-") {
            target.orientation = simd_quatf(angle: localDelta.x * 3, axis: [0, 1, 0])
                * simd_quatf(angle: -localDelta.y * 2, axis: [1, 0, 0])
        } else if target.name == "orbit-handle" {
            isDraggingOrbit = true
            targetYaw = dragYaw - localDelta.x * 1.8
            targetPitch = min(0.65, max(-0.65, dragPitch + localDelta.y * 1.2))
            if mode == .map { targetTravel = 2.4 * tanh(localDelta.z * 1.5) }
        }
    }

    func twist(_ entity: Entity, rotation: simd_quatf) {
        let target = interactiveRoot(entity)
        guard !flying else { return }
        dragName = target.name
        if target.name.hasPrefix("tile-") {
            let normal = simd_normalize(SIMD3<Float>(target.position.x, 0, target.position.z))
            let projected = simd_dot(rotation.imag, normal)
            let angle = 2 * atan2(projected, rotation.real)
            tileDragTurns = Int((angle / (.pi / 2)).rounded())
            target.orientation = simd_quatf(angle: angle, axis: normal)
        } else if target.name.hasPrefix("planet-") { target.orientation = rotation }
    }

    func release(_ entity: Entity) {
        let target = interactiveRoot(entity)
        guard dragName == target.name else { return }
        dragName = nil
        let committedTurns = tileDragTurns
        tileDragTurns = 0
        if target.name.hasPrefix("tile-"), let index = Int(target.name.dropFirst(5)) {
            puzzle.rotate(index, quarterTurns: committedTurns)
            drawPuzzle()
            completeIfReady()
        } else if target.name.hasPrefix("planet-") {
            var settled = target.transform
            settled.rotation = simd_quatf(angle: 0, axis: [0, 1, 0])
            target.move(to: settled, relativeTo: galaxy, duration: reducedMotion ? 0 : 1.1, timingFunction: .easeInOut)
        }
        isDraggingOrbit = false
        targetTravel = 0
    }

    private func cancelManipulation() {
        let previous = dragName
        dragName = nil
        tileDragTurns = 0
        isDraggingOrbit = false
        targetTravel = 0
        if previous?.hasPrefix("tile-") == true { drawPuzzle() }
        if let previous, let planet = galaxy.findEntity(named: previous) {
            planet.orientation = simd_quatf(angle: 0, axis: [0, 1, 0])
        }
    }

    private func drawPuzzle() {
        chamber.children.removeAll()
        let result = puzzle.evaluation
        for index in puzzle.masks.indices {
            let piece = SpatialGeometry.tile(index: index, mask: puzzle.masks[index],
                lit: result.lit.contains(index), star: puzzle.level.starIndices.contains(index),
                start: index == puzzle.level.startIndex, finish: index == puzzle.level.endIndex)
            piece.components.set(SpatialInteractable())
            piece.position.y -= 1.45
            chamber.addChild(piece)
        }
    }

    private func completeIfReady() {
        guard puzzle.evaluation.complete, !flying else { return }
        status = "Signal delivered · watch your route come alive."
        flying = true
        let route = puzzle.evaluation.orderedRoute
        flightPoints = []
        for (position, index) in route.enumerated() {
            let incoming = position == 0 ? puzzle.level.entrance : port(from: index, to: route[position - 1])
            for p in SpatialGeometry.routePoints(index: index, mask: puzzle.masks[index], incomingPort: incoming) {
                let local = p - SIMD3<Float>(0, 1.45, 0)
                if flightPoints.last.map({ simd_distance($0, local) > 0.00001 }) ?? true {
                    flightPoints.append(local)
                }
            }
        }
        flightDistances = [0]
        for (a, b) in zip(flightPoints, flightPoints.dropFirst()) {
            flightDistances.append((flightDistances.last ?? 0) + simd_distance(a, b))
        }
        flightDistance = flightDistances.last ?? 0
        let rocket = SpatialGeometry.rocket()
        if let first = flightPoints.first {
            rocket.position = first
            if flightPoints.count > 1 {
                rocket.look(at: flightPoints[1], from: first, relativeTo: nil)
            }
        }
        chamber.addChild(rocket)
        ship = rocket
        flightStart = CACurrentMediaTime()
    }

    private func port(from index: Int, to next: Int) -> Int {
        if next / 6 < index / 6 { return 1 }
        if next / 6 > index / 6 { return 4 }
        return (next % 6 == (index % 6 + 1) % 6) ? 2 : 8
    }

    func runTracking() async {
        guard !running else { return }
        running = true
        #if targetEnvironment(simulator)
        trackingStatus = "Simulator preview · drag the orbit ring or use Turn."
        #else
        if WorldTrackingProvider.isSupported {
            do { try await session.run([worldTracking]) }
            catch { trackingStatus = "Walking unavailable. Orbit controls still work." }
        } else { trackingStatus = "Use the orbit ring to explore from your seat." }
        #endif
        lastUpdate = CACurrentMediaTime()
        while !Task.isCancelled && running {
            update(CACurrentMediaTime())
            try? await Task.sleep(for: .milliseconds(16))
        }
        session.stop()
    }

    private func update(_ now: TimeInterval) {
        let dt = Float(min(0.05, max(0, now - lastUpdate)))
        lastUpdate = now
        guard active else { return }
        #if !targetEnvironment(simulator)
        if worldTracking.state == .running,
           let anchor = worldTracking.queryDeviceAnchor(atTimestamp: now), anchor.isTracked {
            let c = anchor.originFromAnchorTransform.columns.3
            lastHead = [c.x, c.y, c.z]
            let axis = anchor.originFromAnchorTransform.columns.2
            lastHeading = atan2(axis.x, axis.z)
            if originHead == nil { recenter() }
            if mode == .map, !isDraggingOrbit, let originHead {
                // Only scenery has a compressed travel response. The tracked
                // camera remains completely owned by the operating system.
                let forward = SIMD3<Float>(-sin(originHeading), 0, -cos(originHeading))
                let displacement = simd_dot(lastHead - originHead, forward)
                targetTravel = -displacement + 1.8 * tanh(displacement / 1.8)
            }
        }
        #endif
        let blend = reducedMotion ? Float(1) : 1 - exp(-dt * 8)
        yaw += (targetYaw - yaw) * blend
        pitch += (targetPitch - pitch) * blend
        travel += (targetTravel - travel) * blend
        let orientation = simd_quatf(angle: pitch, axis: [1, 0, 0]) * simd_quatf(angle: yaw, axis: [0, 1, 0])
        galaxy.orientation = orientation
        chamber.orientation = orientation
        galaxy.position.z = travel
        if !reducedMotion, mode == .map {
            for planet in galaxy.children where planet.name != dragName {
                // The body's slow axial drift preserves position and depth.
                if let surface = planet.findEntity(named: "surface") {
                    surface.orientation *= simd_quatf(angle: dt * 0.025, axis: [0, 1, 0])
                }
            }
        }
        if flying, let start = flightStart, let ship, !flightPoints.isEmpty {
            let duration = max(12, Double(flightDistance / 0.8))
            let progress = min(1, Float((now - start) / duration))
            let distance = (progress * progress * (3 - 2 * progress)) * flightDistance
            let upper = flightDistances.firstIndex(where: { $0 > distance }) ?? (flightPoints.count - 1)
            let lower = max(0, upper - 1)
            let segment = max(0.000001, flightDistances[lower + 1] - flightDistances[lower])
            let blend = min(1, max(0, (distance - flightDistances[lower]) / segment))
            let position = flightPoints[lower] * (1 - blend) + flightPoints[lower + 1] * blend
            ship.position = position
            let next = flightPoints[min(flightPoints.count - 1, lower + 2)]
            if simd_distance(position, next) > 0.0001 { ship.look(at: next, from: position, relativeTo: chamber) }
            if progress == 1 {
                flying = false
                flightStart = nil
                status = "Mission complete · three stars charted."
            }
        }
    }

    func stop() { running = false; session.stop() }
}
