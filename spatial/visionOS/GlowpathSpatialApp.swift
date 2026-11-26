import SwiftUI
import RealityKit

@main
struct GlowpathSpatialApp: App {
    @StateObject private var scene = SpatialScene()
    var body: some SwiftUI.Scene {
        ImmersiveSpace(id: "galaxy") {
            ImmersiveGalaxy(scene: scene)
        }
        .immersionStyle(selection: .constant(.full), in: .full)
    }
}

private struct ImmersiveGalaxy: View {
    @ObservedObject var scene: SpatialScene
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reducedMotion

    var body: some View {
        RealityView { content, attachments in
            content.add(scene.root)
            scene.build()
            if let controls = attachments.entity(for: "controls") {
                // A small in-world instrument; the planets and puzzle themselves
                // occupy the entire space and are never hosted in this panel.
                controls.position = [0, 1.32, -1.18]
                controls.orientation = simd_quatf(angle: -.pi / 16, axis: [1, 0, 0])
                scene.instrument.addChild(controls)
            }
        } attachments: {
            Attachment(id: "controls") {
                SpatialInstruments(scene: scene)
                    .frame(width: 620)
                    .padding(22)
                    .glassBackgroundEffect()
            }
        }
        .simultaneousGesture(SpatialTapGesture().targetedToEntity(where: .has(SpatialInteractable.self)).onEnded { value in
            scene.tap(value.entity)
        })
        .simultaneousGesture(DragGesture(minimumDistance: 8).targetedToEntity(where: .has(SpatialInteractable.self))
            .onChanged { value in
                let delta = value.convert(value.translation3D, from: .local, to: .scene)
                scene.drag(value.entity, translation: delta)
            }
            .onEnded { value in scene.release(value.entity) })
        .simultaneousGesture(RotateGesture3D().targetedToEntity(where: .has(SpatialInteractable.self))
            .onChanged { value in
                guard let parent = value.entity.parent else { return }
                let rotation = value.convert(value.rotation, from: .local, to: parent)
                scene.twist(value.entity, rotation: rotation)
            }
            .onEnded { value in scene.release(value.entity) })
        .task {
            scene.reducedMotion = reducedMotion
            await scene.runTracking()
        }
        .onChange(of: reducedMotion) { _, value in scene.reducedMotion = value }
        .onChange(of: phase) { _, value in scene.active = value == .active }
        .onDisappear { scene.stop() }
    }
}

private struct SpatialInstruments: View {
    @ObservedObject var scene: SpatialScene
    private let cyan = Color(red: 0.6, green: 0.87, blue: 0.86)

    var body: some View {
        VStack(spacing: 13) {
            HStack(alignment: .firstTextBaseline) {
                Text(scene.mode == .map ? "VOYAGE / IMMERSIVE" : "ORBITAL ROUTE / 01")
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .tracking(2).foregroundStyle(cyan)
                Spacer()
                Text(scene.mode == .map ? "\(scene.selectedPlanet + 1) / 12" : "\(scene.puzzle.evaluation.collected) / 3 stars")
                    .font(.system(size: 17, weight: .medium)).monospacedDigit()
            }
            Text(scene.status).font(.system(size: 23, weight: .medium))
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
            if scene.mode == .map {
                Text("Look around. Touch a world. Pull the orbit ring to explore.")
                    .font(.system(size: 16)).foregroundStyle(.secondary)
                HStack(spacing: 18) {
                    Button("Previous") { scene.browse(-1) }
                    Button("Chart this route", systemImage: "sparkle") { scene.enterPuzzle() }
                        .tint(cyan)
                    Button("Next") { scene.browse(1) }
                }.buttonStyle(.bordered)
            } else {
                Text(scene.puzzle.evaluation.complete
                     ? "Follow your rocket through the space around you."
                     : "Cyan START on your left → three stars → gold FINISH on your right.")
                    .font(.system(size: 16)).foregroundStyle(.secondary)
                HStack(spacing: 16) {
                    Button("Voyage") { scene.enterMap() }
                    Button("Hint") { scene.hint() }.disabled(scene.flying)
                    Button("Reset") { scene.resetPuzzle() }.disabled(scene.flying)
                }.buttonStyle(.bordered)
            }
            HStack(spacing: 10) {
                Button("Turn left", systemImage: "arrow.counterclockwise") { scene.turnWorld(-1) }
                Button("Up", systemImage: "arrow.up") { scene.tiltWorld(-1) }
                Button("Recenter", systemImage: "scope") { scene.recenter() }
                Button("Down", systemImage: "arrow.down") { scene.tiltWorld(1) }
                Button("Turn right", systemImage: "arrow.clockwise") { scene.turnWorld(1) }
            }.buttonStyle(.borderless).font(.system(size: 14))
            if !scene.trackingStatus.isEmpty {
                Text(scene.trackingStatus).font(.system(size: 12)).foregroundStyle(.secondary)
            }
        }.foregroundStyle(Color(red: 0.96, green: 0.95, blue: 0.92))
    }
}
