import RealityKit
import UIKit
import simd

/// Scene artwork for the native spatial prototype. All dimensions are metres.
/// Roots are independent interaction targets; their visible children never own
/// input, so pokes, pinches and drags resolve to one predictable route piece.
@MainActor
enum SpatialGeometry {
    static let radius: Float = 1.45
    static let rowSpacing: Float = 0.65
    static let cyan = UIColor(red: 0.58, green: 0.87, blue: 0.86, alpha: 1)
    static let gold = UIColor(red: 0.94, green: 0.78, blue: 0.49, alpha: 1)
    static let channel = UIColor(red: 0.61, green: 0.73, blue: 0.83, alpha: 1)
    static let navy = UIColor(red: 0.025, green: 0.048, blue: 0.081, alpha: 1)
    private static let sphereMesh = MeshResource.generateSphere(radius: 1)
    private static let cylinderMesh = MeshResource.generateCylinder(height: 1, radius: 1)
    private static let coneMesh = MeshResource.generateCone(height: 1, radius: 1)

    static func tilePosition(index: Int) -> SIMD3<Float> {
        let angle = -.pi / 2 + Float(index % 6) * .pi / 3
        return [sin(angle) * radius, 2.1 - Float(index / 6) * rowSpacing, -cos(angle) * radius]
    }

    /// Neighbouring tiles return exactly the same position for their shared port.
    static func portPosition(index: Int, port: Int) -> SIMD3<Float> {
        let center = tilePosition(index: index)
        if port == 1 { return center + [0, rowSpacing / 2, 0] }
        if port == 4 { return center - [0, rowSpacing / 2, 0] }
        let angle = -.pi / 2 + Float(index % 6) * .pi / 3 + (port == 2 ? .pi / 6 : -.pi / 6)
        return [sin(angle) * radius, center.y, -cos(angle) * radius]
    }

    static func tile(index: Int, mask: Int, lit: Bool, star: Bool, start: Bool, finish: Bool) -> Entity {
        let root = Entity()
        root.name = "tile-\(index)"
        let center = tilePosition(index: index)
        root.position = center
        let inward = simd_normalize(SIMD3<Float>(-center.x, 0, -center.z))
        let ports = [1, 2, 4, 8].filter { mask & $0 != 0 }
        guard ports.count == 2 else { return root }
        let a = portPosition(index: index, port: ports[0]) - center
        let b = portPosition(index: index, port: ports[1]) - center
        let points = routePoints(index: index, mask: mask).map { $0 - center }
        root.addChild(tube(points: points, radius: 0.032, color: lit ? gold : channel, unlit: false))
        // A narrow lit seam reinforces flow without washing out the silhouette.
        if lit {
            root.addChild(tube(points: points.map { $0 + inward * 0.027 }, radius: 0.006, color: .init(white: 1, alpha: 1), unlit: true))
        }
        for p in [a, b] {
            let joint = sphere(radius: 0.037, color: lit ? gold : UIColor(red: 0.24, green: 0.36, blue: 0.43, alpha: 1))
            joint.position = p
            root.addChild(joint)
        }
        // A dark central spindle makes the turnable joint recognizable without
        // reintroducing an opaque tile surface around the player.
        let spindle = sphere(radius: 0.05, color: navy)
        spindle.position = inward * 0.025
        root.addChild(spindle)
        let grip = ring(radius: 0.051, tubeRadius: 0.0025, color: lit ? gold : cyan)
        grip.position = inward * 0.070
        grip.orientation = simd_quatf(from: [0, 1, 0], to: inward)
        root.addChild(grip)
        if star {
            let mark = starEntity(radius: 0.064, color: lit ? UIColor(red: 1, green: 0.90, blue: 0.64, alpha: 1) : gold)
            mark.position = inward * 0.095
            mark.orientation = simd_quatf(from: [0, 0, 1], to: inward)
            root.addChild(mark)
        } else {
            let dot = sphere(radius: 0.013, color: lit ? gold : cyan, unlit: true)
            dot.position = inward * 0.07
            root.addChild(dot)
        }
        if start || finish {
            let color = start ? cyan : gold
            let label = text(start ? "START" : "FINISH", color: color, size: 0.052)
            label.position = inward * 0.14 + SIMD3<Float>(0, -0.13, 0)
            label.orientation = simd_quatf(from: [0, 0, 1], to: inward)
            root.addChild(label)
            let beacon = ring(radius: 0.075, tubeRadius: 0.004, color: color)
            beacon.position = inward * 0.10
            beacon.orientation = simd_quatf(from: [0, 1, 0], to: inward)
            root.addChild(beacon)
        }
        root.components.set(InputTargetComponent())
        let touchShapes = points.enumerated().compactMap { sample -> ShapeResource? in
            guard sample.offset % 4 == 0 else { return nil }
            return ShapeResource.generateSphere(radius: 0.10).offsetBy(translation: sample.element)
        }
        root.components.set(CollisionComponent(shapes: touchShapes + [.generateSphere(radius: 0.17)]))
        root.components.set(HoverEffectComponent())
        return root
    }

    /// Sampled centreline for the rocket; incomingPort reverses the samples
    /// when the flight enters from the other end of the same physical piece.
    static func routePoints(index: Int, mask: Int, incomingPort: Int? = nil) -> [SIMD3<Float>] {
        let center = tilePosition(index: index)
        let ports = [1, 2, 4, 8].filter { mask & $0 != 0 }
        guard ports.count == 2 else { return [center] }
        let a = portPosition(index: index, port: ports[0]) - center
        let b = portPosition(index: index, port: ports[1]) - center
        let points: [SIMD3<Float>]
        if Set(ports) == Set([1, 4]) {
            points = (0...24).map { a + (b - a) * Float($0) / 24 }
        } else if Set(ports) == Set([2, 8]) {
            let angle = -.pi / 2 + Float(index % 6) * .pi / 3
            points = (0...24).map { step in
                let theta = angle + .pi / 6 - Float(step) / 24 * .pi / 3
                return SIMD3<Float>(sin(theta) * radius, center.y, -cos(theta) * radius) - center
            }
        } else {
            // Cubic tangents meet the neighbouring piece at the port. The bend
            // remains a tube in space, rather than a drawing on a square panel.
            func inwardTangent(port: Int) -> SIMD3<Float> {
                if port == 1 { return [0, -1, 0] }
                if port == 4 { return [0, 1, 0] }
                let angle = -.pi / 2 + Float(index % 6) * .pi / 3 + (port == 2 ? .pi / 6 : -.pi / 6)
                let increasingAngle = SIMD3<Float>(cos(angle), 0, sin(angle))
                return port == 2 ? -increasingAngle : increasingAngle
            }
            let controlA = a + inwardTangent(port: ports[0]) * simd_length(a) * 0.78
            let controlB = b + inwardTangent(port: ports[1]) * simd_length(b) * 0.78
            points = (0...24).map { step in
                let t = Float(step) / 24, u = 1 - t
                return a * (u * u * u) + controlA * (3 * u * u * t)
                    + controlB * (3 * u * t * t) + b * (t * t * t)
            }
        }
        let world = points.map { $0 + center }
        return incomingPort == ports.last ? world.reversed() : world
    }

    static func planet(index: Int) -> Entity {
        let root = Entity()
        root.name = "planet-\(index)"
        let surface = Entity()
        surface.name = "surface"
        root.addChild(surface)
        let variation = abs(index) % 6
        let r: Float = [0.40, 0.48, 0.55, 0.43, 0.50, 0.36][variation]
        let palettes: [(UIColor, UIColor)] = [
            (.init(red: 0.29, green: 0.61, blue: 0.63, alpha: 1), .init(red: 0.61, green: 0.83, blue: 0.76, alpha: 1)),
            (.init(red: 0.10, green: 0.34, blue: 0.46, alpha: 1), .init(red: 0.45, green: 0.66, blue: 0.51, alpha: 1)),
            (.init(red: 0.72, green: 0.48, blue: 0.23, alpha: 1), .init(red: 0.97, green: 0.78, blue: 0.43, alpha: 1)),
            (.init(red: 0.34, green: 0.52, blue: 0.64, alpha: 1), .init(red: 0.72, green: 0.87, blue: 0.88, alpha: 1)),
            (.init(red: 0.27, green: 0.23, blue: 0.45, alpha: 1), .init(red: 0.63, green: 0.55, blue: 0.79, alpha: 1)),
            (.init(red: 0.43, green: 0.21, blue: 0.16, alpha: 1), .init(red: 0.83, green: 0.48, blue: 0.28, alpha: 1))
        ]
        let (base, accent) = palettes[variation]
        let body = sphere(radius: r, color: base)
        body.name = "planet-body"
        surface.addChild(body)
        // Actual spherical mesh bands retain their shape when viewed from the
        // back, unlike decals or a flat replacement for the Voyage artwork.
        for band in 0..<7 {
            let latitude = Float(band - 3) * 0.22
            let halfWidth: Float = variation == 1 ? 0.028 : (band % 2 == 0 ? 0.045 : 0.021)
            let ribbon = latitudeBand(radius: r * 1.003, latitude: latitude, halfWidth: halfWidth,
                                      wave: variation == 3 ? 0.022 : 0.01,
                                      color: band % 2 == 0 ? accent : base)
            surface.addChild(ribbon)
        }
        if variation == 2 || variation == 4 {
            let rings = Entity()
            for lane in 0..<4 {
                rings.addChild(ring(radius: r * (1.36 + Float(lane) * 0.12), tubeRadius: lane == 0 ? 0.009 : 0.004, color: accent))
            }
            rings.orientation = simd_quatf(angle: 0.30, axis: [0, 0, 1]) * simd_quatf(angle: 0.1, axis: [1, 0, 0])
            surface.addChild(rings)
        } else if variation == 1 {
            // Low, sculpted land masses are part of the sphere in every view.
            for n in 0..<8 {
                let azimuth = Float(n) * 2.399
                let y = Float((n * 7) % 13 - 6) / 10
                let normal = simd_normalize(SIMD3<Float>(cos(azimuth), y, sin(azimuth)))
                let land = sphere(radius: 1, color: accent)
                land.scale = [r * 0.30, r * 0.19, r * 0.035]
                land.position = normal * r * 0.987
                land.orientation = simd_quatf(from: [0, 0, 1], to: normal)
                surface.addChild(land)
            }
        } else {
            for n in 0..<7 {
                let a = Float(n) * 2.399 + Float(index) * 0.4
                let normal = simd_normalize(SIMD3<Float>(cos(a), Float(n % 3 - 1) * 0.75, sin(a)))
                let crater = sphere(radius: 1, color: n % 2 == 0 ? accent : base)
                crater.scale = [r * 0.09, r * 0.075, r * 0.012]
                crater.position = normal * r * 0.997
                crater.orientation = simd_quatf(from: [0, 0, 1], to: normal)
                surface.addChild(crater)
            }
        }
        let moon = sphere(radius: r * 0.105, color: channel)
        moon.position = [r * 1.45, r * 0.45, r * -0.18]
        surface.addChild(moon)
        root.components.set(InputTargetComponent())
        root.components.set(CollisionComponent(shapes: [.generateSphere(radius: r)]))
        root.components.set(HoverEffectComponent())
        return root
    }

    static func universe() -> Entity {
        let root = Entity()
        root.name = "universe"
        var skyMaterial = UnlitMaterial(color: UIColor(red: 0.025, green: 0.045, blue: 0.078, alpha: 1))
        skyMaterial.faceCulling = .front
        let sky = ModelEntity(mesh: sphereMesh, materials: [skyMaterial])
        sky.scale = [80, 80, 80]
        root.addChild(sky)
        // Fibonacci placement fills the entire celestial sphere evenly.
        for n in 0..<340 {
            let y = 1 - 2 * (Float(n) + 0.5) / 340
            let a = Float(n) * 2.399963
            let ringRadius = sqrt(max(0, 1 - y * y))
            let position = SIMD3<Float>(cos(a) * ringRadius, y, sin(a) * ringRadius) * Float(24 + n % 17)
            let color = n % 7 == 0 ? gold : (n % 5 == 0 ? cyan : channel)
            let star = sphere(radius: n % 13 == 0 ? 0.045 : 0.018, color: color, unlit: true)
            star.position = position
            root.addChild(star)
        }
        let key = DirectionalLight()
        key.light.color = UIColor(red: 0.83, green: 0.92, blue: 1, alpha: 1)
        key.light.intensity = 2400
        key.orientation = simd_quatf(angle: -.pi / 4, axis: [1, 0, 0]) * simd_quatf(angle: -.pi / 5, axis: [0, 1, 0])
        root.addChild(key)
        let fill = DirectionalLight()
        fill.light.color = UIColor(red: 0.27, green: 0.48, blue: 0.64, alpha: 1)
        fill.light.intensity = 700
        fill.orientation = simd_quatf(angle: .pi * 0.75, axis: [0, 1, 0])
        root.addChild(fill)
        return root
    }

    static func rail(from: SIMD3<Float>, to: SIMD3<Float>, color: UIColor, radius: Float = 0.014) -> Entity {
        tube(points: [from, to], radius: radius, color: color, unlit: true)
    }

    /// The ship points along local -Z, matching RealityKit look(at:) orientation.
    static func rocket() -> Entity {
        let root = Entity()
        root.name = "rocket"
        let body = sphere(radius: 1, color: channel)
        body.scale = [0.035, 0.027, 0.14]
        root.addChild(body)
        let nose = ModelEntity(mesh: coneMesh, materials: [SimpleMaterial(color: .init(white: 0.94, alpha: 1), roughness: 0.26, isMetallic: true)])
        nose.scale = [0.033, 0.12, 0.033]
        nose.orientation = simd_quatf(angle: -.pi / 2, axis: [1, 0, 0])
        nose.position.z = -0.13
        root.addChild(nose)
        let cockpit = sphere(radius: 1, color: navy)
        cockpit.scale = [0.022, 0.015, 0.047]
        cockpit.position = [0, 0.021, -0.052]
        root.addChild(cockpit)
        for side: Float in [-1, 1] {
            let wing = ModelEntity(mesh: .generateBox(size: [0.09, 0.007, 0.09], cornerRadius: 0.003), materials: [SimpleMaterial(color: .init(red: 0.27, green: 0.42, blue: 0.50, alpha: 1), roughness: 0.35, isMetallic: true)])
            wing.position = [side * 0.054, -0.008, 0.055]
            wing.orientation = simd_quatf(angle: side * -.pi / 5, axis: [0, 1, 0])
            root.addChild(wing)
        }
        let engine = ModelEntity(mesh: cylinderMesh, materials: [SimpleMaterial(color: navy, isMetallic: true)])
        engine.scale = [0.03, 0.035, 0.03]
        engine.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
        engine.position.z = 0.13
        root.addChild(engine)
        let exhaust = Entity()
        exhaust.name = "exhaust"
        let flame = ModelEntity(mesh: coneMesh, materials: [UnlitMaterial(color: gold)])
        flame.scale = [0.022, 0.13, 0.022]
        flame.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])
        flame.position.z = 0.205
        exhaust.addChild(flame)
        let core = sphere(radius: 1, color: .init(white: 1, alpha: 1), unlit: true)
        core.scale = [0.012, 0.012, 0.033]
        core.position.z = 0.16
        exhaust.addChild(core)
        root.addChild(exhaust)
        return root
    }

    /// A bounded luminous floor keeps the authored colour legible in a full
    /// space without depending on room/environment illumination. The diffuse
    /// and broad specular response still describes the cylindrical surface.
    private static func readableMaterial(color: UIColor, emission: Float, roughness: Float) -> PhysicallyBasedMaterial {
        var material = PhysicallyBasedMaterial()
        material.baseColor = .init(tint: color)
        material.metallic = .init(floatLiteral: 0.03)
        material.roughness = .init(floatLiteral: roughness)
        material.specular = .init(floatLiteral: 0.25)
        material.emissiveColor = .init(color: color)
        material.emissiveIntensity = emission
        return material
    }

    private static func sphere(radius: Float, color: UIColor, unlit: Bool = false) -> ModelEntity {
        let material: any Material = unlit ? UnlitMaterial(color: color) : readableMaterial(color: color, emission: 0.16, roughness: 0.66)
        let model = ModelEntity(mesh: sphereMesh, materials: [material])
        model.scale = .init(repeating: radius)
        return model
    }

    private static func ring(radius: Float, tubeRadius: Float, color: UIColor) -> Entity {
        let points = (0...80).map { i -> SIMD3<Float> in
            let a = Float(i) / 80 * .pi * 2
            return [cos(a) * radius, 0, sin(a) * radius]
        }
        return tube(points: points, radius: tubeRadius, color: color, unlit: true)
    }

    /// One indexed mesh per tube keeps a smooth path inexpensive to render.
    private static func tube(points: [SIMD3<Float>], radius: Float, color: UIColor, unlit: Bool) -> ModelEntity {
        let sides = 12
        var vertices = [SIMD3<Float>](), normals = [SIMD3<Float>](), indices = [UInt32]()
        let closed = points.count > 3 && simd_distance_squared(points[0], points[points.count - 1]) < 0.000001
        let directions: [SIMD3<Float>] = points.indices.map { i in
            if closed && (i == 0 || i == points.count - 1) {
                return simd_normalize(points[1] - points[points.count - 2])
            }
            return simd_normalize(points[min(i + 1, points.count - 1)] - points[max(0, i - 1)])
        }
        // Transport the previous frame along the curve. Selecting a fresh
        // global reference axis at each sample twists adjoining rings and can
        // fold their joining triangles through the tube at a steep bend.
        let firstReference: SIMD3<Float> = abs(directions[0].y) > 0.90 ? [1, 0, 0] : [0, 1, 0]
        var previousRight = simd_normalize(simd_cross(directions[0], firstReference))
        var rights = [SIMD3<Float>]()
        for direction in directions {
            let projected = previousRight - direction * simd_dot(previousRight, direction)
            if simd_length_squared(projected) > 0.000001 {
                previousRight = simd_normalize(projected)
            } else {
                let reference: SIMD3<Float> = abs(direction.y) > 0.90 ? [1, 0, 0] : [0, 1, 0]
                previousRight = simd_normalize(simd_cross(direction, reference))
            }
            rights.append(previousRight)
        }
        if closed, let last = rights.last {
            // A closed curve may accumulate a small frame twist. Spread its
            // correction over the full loop so the final ring welds cleanly.
            let residual = atan2(simd_dot(directions[0], simd_cross(last, rights[0])), simd_dot(last, rights[0]))
            for i in rights.indices {
                let angle = residual * Float(i) / Float(rights.count - 1)
                rights[i] = simd_quatf(angle: angle, axis: directions[i]).act(rights[i])
            }
            rights[rights.count - 1] = rights[0]
        }
        for i in points.indices {
            let direction = directions[i]
            let right = rights[i]
            let up = simd_cross(right, direction)
            for j in 0..<sides {
                let angle = Float(j) / Float(sides) * .pi * 2
                let normal = right * cos(angle) + up * sin(angle)
                vertices.append(points[i] + normal * radius)
                normals.append(normal)
            }
            if i > 0 {
                for j in 0..<sides {
                    let a = UInt32((i - 1) * sides + j), b = UInt32((i - 1) * sides + (j + 1) % sides)
                    let c = UInt32(i * sides + j), d = UInt32(i * sides + (j + 1) % sides)
                    indices += [a, c, b, b, c, d]
                }
            }
        }
        var descriptor = MeshDescriptor(name: "route-tube")
        descriptor.positions = .init(vertices)
        descriptor.normals = .init(normals)
        descriptor.primitives = .triangles(indices)
        let mesh = (try? MeshResource.generate(from: [descriptor])) ?? sphereMesh
        let material: any Material = unlit ? UnlitMaterial(color: color) : readableMaterial(color: color, emission: 0.65, roughness: 0.52)
        return ModelEntity(mesh: mesh, materials: [material])
    }

    private static func latitudeBand(radius: Float, latitude: Float, halfWidth: Float, wave: Float, color: UIColor) -> Entity {
        var vertices = [SIMD3<Float>](), normals = [SIMD3<Float>](), indices = [UInt32]()
        for i in 0...80 {
            let azimuth = Float(i) / 80 * .pi * 2
            for sign: Float in [-1, 1] {
                let lat = latitude + sign * halfWidth + sin(azimuth * 3) * wave
                let normal = SIMD3<Float>(cos(lat) * cos(azimuth), sin(lat), cos(lat) * sin(azimuth))
                vertices.append(normal * radius)
                normals.append(normal)
            }
            if i > 0 {
                let a = UInt32((i - 1) * 2), b = UInt32(i * 2)
                indices += [a, a + 1, b, a + 1, b + 1, b]
            }
        }
        var descriptor = MeshDescriptor(name: "planet-band")
        descriptor.positions = .init(vertices)
        descriptor.normals = .init(normals)
        descriptor.primitives = .triangles(indices)
        guard let mesh = try? MeshResource.generate(from: [descriptor]) else { return Entity() }
        var material = SimpleMaterial(color: color, roughness: 0.85, isMetallic: false)
        material.faceCulling = .none
        return ModelEntity(mesh: mesh, materials: [material])
    }

    private static func starEntity(radius: Float, color: UIColor) -> Entity {
        var vertices = [SIMD3<Float>(0, 0, 0)]
        var triangles = [UInt32]()
        for i in 0..<10 {
            let a = Float(i) * .pi / 5 + .pi / 2
            let r = radius * (i.isMultiple(of: 2) ? 1 : 0.44)
            vertices.append([cos(a) * r, sin(a) * r, 0])
            triangles += [0, UInt32(i + 1), UInt32((i + 1) % 10 + 1)]
        }
        var descriptor = MeshDescriptor(name: "star")
        descriptor.positions = .init(vertices)
        descriptor.normals = .init(Array(repeating: [0, 0, 1], count: vertices.count))
        descriptor.primitives = .triangles(triangles)
        guard let mesh = try? MeshResource.generate(from: [descriptor]) else { return Entity() }
        var material = UnlitMaterial(color: color)
        material.faceCulling = .none
        return ModelEntity(mesh: mesh, materials: [material])
    }

    private static func text(_ value: String, color: UIColor, size: CGFloat) -> Entity {
        let mesh = MeshResource.generateText(value, extrusionDepth: 0.001, font: .systemFont(ofSize: size, weight: .semibold))
        let label = ModelEntity(mesh: mesh, materials: [UnlitMaterial(color: color)])
        let root = Entity()
        label.position.x = -mesh.bounds.extents.x / 2
        root.addChild(label)
        return root
    }
}
