import SwiftUI

@main
struct GlowpathTVApp: App {
    var body: some Scene { WindowGroup { TVMissionView() } }
}

private enum FlightColor {
    static let space = Color(red: 6/255, green: 11/255, blue: 20/255)
    static let panel = Color(red: 14/255, green: 31/255, blue: 45/255)
    static let teal = Color(red: 154/255, green: 221/255, blue: 220/255)
    static let gold = Color(red: 235/255, green: 201/255, blue: 144/255)
    static let ink = Color(red: 244/255, green: 242/255, blue: 236/255)
    static let muted = Color(red: 169/255, green: 184/255, blue: 198/255)
    static let channel = Color(red: 176/255, green: 195/255, blue: 216/255)
}

private let routePlans = [
    [6, 3, 0, 1, 4, 7, 8, 5, 2],
    [0, 3, 6, 7, 4, 1, 2, 5, 8],
    [3, 0, 1, 4, 7, 8, 5, 2],
    [6, 7, 4, 3, 0, 1, 2, 5, 8],
    [0, 1, 4, 3, 6, 7, 8, 5, 2],
]

private func rotated(_ mask: Int) -> Int { ((mask << 1) & 15) | (mask >> 3) }
private func direction(from a: Int, to b: Int) -> Int {
    if b == a - 3 { return 1 }
    if b == a + 1 { return 2 }
    if b == a + 3 { return 4 }
    return 8
}

@MainActor
private final class TVMission: ObservableObject {
    @Published var level = 1
    @Published var masks = [Int](repeating: 5, count: 9)
    @Published var lit = Set<Int>()
    @Published var remaining = 90.0
    @Published var turns = 0
    @Published var result: Bool? = nil
    @Published var started = false
    @Published var best = 0
    @Published var hintUsed = false
    var solution = [Int](repeating: 5, count: 9)
    var stars = Set<Int>()
    var start = 6
    var end = 2
    private var lastTick: Date?
    private var active = true
    private var timer: Timer?
    var collected: Int { stars.intersection(lit).count }
    var score: Int { max(10, Int(remaining * 10) + 150 - turns * 3 - (hintUsed ? 60 : 0)) }

    private let storage: UserDefaults
    init(storage: UserDefaults = .standard) {
        self.storage = storage
        level = max(1, storage.integer(forKey: "tvPreviewLevel"))
        best = storage.integer(forKey: "tvPreviewBest")
        prepare()
    }
    deinit { timer?.invalidate() }

    func prepare() {
        timer?.invalidate()
        timer = nil
        let route = routePlans[(level - 1) % routePlans.count]
        start = route.first!
        end = route.last!
        stars = Set([route[2], route[route.count / 2], route[route.count - 2]])
        solution = (0..<9).map { (($0 + level) % 2 == 0) ? 5 : 3 }
        for (position, tile) in route.enumerated() {
            let entrance = position == 0 ? 8 : direction(from: tile, to: route[position - 1])
            let exit = position == route.count - 1 ? 2 : direction(from: tile, to: route[position + 1])
            solution[tile] = entrance | exit
        }
        masks = solution.enumerated().map { index, mask in
            var value = mask
            for _ in 0..<((index * 7 + level * 5) % 3 + 1) { value = rotated(value) }
            return value
        }
        remaining = 90
        turns = 0
        result = nil
        started = false
        hintUsed = false
        lastTick = nil
        refreshPath()
    }

    func turn(_ index: Int) {
        guard result == nil else { return }
        if !started { started = true; lastTick = Date(); resumeTimer() }
        masks[index] = rotated(masks[index])
        turns += 1

        refreshPath()
    }

    func hint() {
        guard result == nil,
              let index = routePlans[(level - 1) % routePlans.count].first(where: { masks[$0] != solution[$0] }) else { return }
        if !started { started = true; lastTick = Date(); resumeTimer() }
        hintUsed = true
        masks[index] = solution[index]
        turns += 1

        refreshPath()
    }

    func refreshPath() {
        var reached = Set<Int>()
        var tile = start
        var incoming = 8
        var finished = false
        while !reached.contains(tile) {
            let mask = masks[tile]
            guard mask & incoming != 0 else { break }
            reached.insert(tile)
            let exit = mask ^ incoming
            if tile == end && exit == 2 { finished = true; break }
            let row = tile / 3, column = tile % 3
            if (exit == 1 && row == 0) || (exit == 4 && row == 2) || (exit == 8 && column == 0) || (exit == 2 && column == 2) { break }
            tile += exit == 1 ? -3 : exit == 2 ? 1 : exit == 4 ? 3 : -1
            incoming = exit == 1 ? 4 : exit == 2 ? 8 : exit == 4 ? 1 : 2
        }
        lit = reached
        if finished && stars.isSubset(of: reached) {
            result = true
            timer?.invalidate()
            timer = nil
            lastTick = nil
            best = max(best, score)
            storage.set(best, forKey: "tvPreviewBest")

        }
    }

    func setActive(_ value: Bool) {
        if !value { tick(Date()) }
        active = value
        lastTick = value && started && result == nil ? Date() : nil
        if value { resumeTimer() } else { timer?.invalidate(); timer = nil }
    }

    private func resumeTimer() {
        guard active, started, result == nil, timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.tick(Date()) }
        }
    }

    func tick(_ now: Date) {
        guard active, started, result == nil, let previous = lastTick else { return }
        remaining = max(0, remaining - max(0, now.timeIntervalSince(previous)))
        lastTick = now
        if remaining == 0 { result = false; lastTick = nil; timer?.invalidate(); timer = nil; }
    }

    func retry() {
        remaining = 90
        result = nil
        started = false
        turns = 0
        // The retained tile arrangement still includes any hint assistance.
        lastTick = nil
    }

    func next() {
        level += 1
        storage.set(level, forKey: "tvPreviewLevel")
        prepare()
    }
}


private struct StarMark: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        for index in 0..<10 {
            let angle = Double(index) * .pi / 5 - .pi / 2
            let radius = min(rect.width, rect.height) * (index.isMultiple(of: 2) ? 0.5 : 0.22)
            let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}


private struct TVMissionView: View {
    @StateObject private var mission = TVMission()
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @FocusState private var focus: String?
    @State private var previous: [Int]?

    var body: some View {
        GeometryReader { geometry in
            let boardSide = min(geometry.size.height - 190, geometry.size.width * 0.49, 720)
            let panelWidth = min(530.0, geometry.size.width * 0.33)
            ZStack {
                FlightColor.space.ignoresSafeArea()
                TVUniverse().ignoresSafeArea().accessibilityHidden(true)
                HStack(alignment: .center, spacing: 78) {
                    VStack(alignment: .leading, spacing: 22) {
                        HStack {
                            Text("START  →").foregroundStyle(FlightColor.teal)
                            Spacer()
                            HStack(spacing: 12) {
                                ForEach(0..<3, id: \.self) { index in
                                    StarMark().fill(index < mission.collected ? FlightColor.gold : FlightColor.muted.opacity(0.35)).frame(width: 23, height: 23)
                                }
                            }
                            Spacer()
                            Text("→  FINISH").foregroundStyle(FlightColor.gold)
                        }.font(.system(size: 20, weight: .semibold)).tracking(1.2)
                        board(side: boardSide)
                        Text("Move to a tile. Press Select to turn it.")
                            .font(.system(size: 23)).foregroundStyle(FlightColor.muted)
                    }.frame(width: boardSide)
                    VStack(alignment: .leading, spacing: 30) {
                        HStack {
                            VStack(alignment: .leading, spacing: 9) {
                                Text("GLOWPATH").font(.system(size: 19, weight: .semibold)).tracking(4).foregroundStyle(FlightColor.teal)
                                Text("Chart your course.").font(.system(size: 45, weight: .medium))
                            }
                            Spacer()
                        }
                        Text("ROUTE \(String(format: "%02d", mission.level))")
                            .font(.system(size: 20, weight: .medium)).tracking(3).foregroundStyle(FlightColor.muted)
                        if let won = mission.result {
                            VStack(alignment: .leading, spacing: 15) {
                                Text(won ? "Signal delivered" : "Signal lost")
                                    .font(.system(size: 39, weight: .medium)).foregroundStyle(won ? FlightColor.teal : FlightColor.gold)
                                Text(won ? "+\(mission.score) points · \(mission.turns) turns" : "Your route is saved. Try the next connection.")
                                    .font(.system(size: 24)).foregroundStyle(FlightColor.muted)
                                action(won ? "Next flight" : "Retry", tag: "result", color: FlightColor.gold) {
                                    previous = nil
                                    if won { mission.next() } else { mission.retry() }
                                    focus = "tile-\(mission.start)"
                                }
                            }.transition(.opacity)
                        } else {
                            timer
                            Text("Link START to FINISH through all three stars.")
                                .font(.system(size: 28)).lineSpacing(5).fixedSize(horizontal: false, vertical: true)
                            VStack(spacing: 15) {
                                action("Show a hint", tag: "hint", color: FlightColor.teal) { previous = mission.masks; mission.hint() }
                                HStack(spacing: 16) {
                                    action("Undo", tag: "undo", color: FlightColor.muted) {
                                        if let old = previous { mission.masks = old; mission.refreshPath(); previous = nil }
                                    }.disabled(previous == nil)
                                    action("Restart", tag: "restart", color: FlightColor.muted) { previous = nil; mission.prepare(); focus = "tile-\(mission.start)" }
                                }
                            }
                            HStack {
                                Text("\(mission.turns) turns")
                                Spacer()
                                Text(mission.hintUsed ? "Assisted flight" : "Clean flight")
                            }.font(.system(size: 21)).foregroundStyle(FlightColor.muted)
                        }
                        Rectangle().fill(FlightColor.muted.opacity(0.16)).frame(height: 1)
                        HStack {
                            Text("BEST FLIGHT").tracking(2)
                            Spacer()
                            Text("\(mission.best)").monospacedDigit().foregroundStyle(FlightColor.gold)
                        }.font(.system(size: 18, weight: .medium)).foregroundStyle(FlightColor.muted)
                    }.frame(width: panelWidth)
                }
                .padding(80)
            }
            .foregroundStyle(FlightColor.ink)
            .animation(reducedMotion ? nil : .easeInOut(duration: 0.3), value: mission.result)
        }
        .onAppear { focus = "tile-\(mission.start)" }
        .onChange(of: phase) { _, value in mission.setActive(value == .active) }
        .onChange(of: mission.result) { _, result in if result != nil { focus = "result" } }
        .preferredColorScheme(.dark)
    }

    private func board(side: CGFloat) -> some View {
        let edge = (side - 28) / 3
        return VStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { col in
                        let index = row * 3 + col
                        let selected = focus == "tile-\(index)"
                        Button {
                            previous = mission.masks
                            mission.turn(index)
                        } label: {
                            TVTile(mask: mission.masks[index], lit: mission.lit.contains(index), star: mission.stars.contains(index), start: index == mission.start, finish: index == mission.end)
                                .overlay(RoundedRectangle(cornerRadius: 18).stroke(selected ? FlightColor.teal : .clear, lineWidth: 4).padding(2))
                                .shadow(color: FlightColor.teal.opacity(selected ? 0.25 : 0), radius: 14)
                        }
                        .buttonStyle(TVButtonStyle()).focusEffectDisabled()
                        .frame(width: edge, height: edge)
                        .focused($focus, equals: "tile-\(index)")
                        .disabled(mission.result != nil)
                        .accessibilityLabel("Row \(row + 1), column \(col + 1)\(index == mission.start ? ", start" : index == mission.end ? ", finish" : "")\(mission.stars.contains(index) ? ", star" : "")")
                        .accessibilityValue("\(mission.lit.contains(index) ? "Lit" : "Unlit")")
                        .accessibilityHint("Select to turn clockwise")
                    }
                }
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 28).fill(FlightColor.panel.opacity(0.5)))
        .overlay(RoundedRectangle(cornerRadius: 28).stroke(FlightColor.muted.opacity(0.2), lineWidth: 1))
        .focusSection()
    }

    private var timer: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text(mission.started ? "LAUNCH IN" : "READY TO LAUNCH").font(.system(size: 17, weight: .medium)).tracking(1.8).foregroundStyle(FlightColor.muted)
                Spacer()
                Text("\(Int(ceil(mission.remaining)))s").font(.system(size: 57, weight: .medium)).monospacedDigit().foregroundStyle(FlightColor.gold)
            }
            GeometryReader { proxy in
                let progress = 1 - mission.remaining / 90
                ZStack(alignment: .leading) {
                    Capsule().fill(FlightColor.muted.opacity(0.22)).frame(height: 2)
                    Capsule().fill(FlightColor.gold.opacity(0.75)).frame(width: max(2, proxy.size.width * progress), height: 2)
                    TVRocket().frame(width: 66, height: 35).offset(x: (proxy.size.width - 66) * progress)
                }.frame(maxHeight: .infinity)
            }.frame(height: 38)
            Text(mission.started ? "Keep the signal flowing." : "The clock starts with your first turn.")
                .font(.system(size: 20)).foregroundStyle(FlightColor.muted)
        }
    }

    private func action(_ title: String, tag: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 25, weight: .medium))
                .frame(maxWidth: .infinity).frame(height: 66)
                .background(RoundedRectangle(cornerRadius: 17).fill(color.opacity(focus == tag ? 0.2 : 0.065)))
                .overlay(RoundedRectangle(cornerRadius: 17).stroke(color.opacity(focus == tag ? 1 : 0.32), lineWidth: focus == tag ? 3 : 1))
        }.buttonStyle(TVButtonStyle()).focusEffectDisabled().focused($focus, equals: tag)
    }
}

private struct TVTile: View {
    let mask: Int
    let lit, star, start, finish: Bool
    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1)
            context.fill(Path(roundedRect: rect, cornerRadius: 18), with: .linearGradient(Gradient(colors: [FlightColor.panel, FlightColor.space]), startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
            context.stroke(Path(roundedRect: rect, cornerRadius: 18), with: .color(FlightColor.muted.opacity(0.1)), lineWidth: 1)
            let c = CGPoint(x: size.width/2, y: size.height/2)
            let edges = [CGPoint(x:c.x,y:0),CGPoint(x:size.width,y:c.y),CGPoint(x:c.x,y:size.height),CGPoint(x:0,y:c.y)]
            let exits = (0..<4).filter { mask & (1 << $0) != 0 }
            var p = Path()
            p.move(to: edges[exits[0]])
            if abs(exits[0] - exits[1]) == 2 { p.addLine(to: edges[exits[1]]) }
            else {
                let a=edges[exits[0]], b=edges[exits[1]]
                let nearA=CGPoint(x:a.x+(c.x-a.x)*0.68,y:a.y+(c.y-a.y)*0.68)
                let nearB=CGPoint(x:b.x+(c.x-b.x)*0.68,y:b.y+(c.y-b.y)*0.68)
                p.addLine(to:nearA); p.addQuadCurve(to:nearB,control:c); p.addLine(to:b)
            }
            let color = lit ? FlightColor.gold : FlightColor.channel
            if lit { context.stroke(p,with:.color(color.opacity(0.14)),style:StrokeStyle(lineWidth:size.width*0.22,lineCap:.butt)) }
            context.stroke(p,with:.color(color),style:StrokeStyle(lineWidth:size.width*0.12,lineCap:.butt))
            if star {
                let circle=CGRect(x:c.x-20,y:c.y-20,width:40,height:40)
                context.fill(Path(ellipseIn:circle),with:.color(FlightColor.space))
                context.stroke(StarMark().path(in:circle.insetBy(dx:5,dy:5)),with:.color(lit ? FlightColor.gold : FlightColor.channel),lineWidth:2)
            }
        }
        .overlay(alignment: start ? .bottomLeading : .topTrailing) {
            if start || finish {
                Text(start ? "START  →" : "FINISH  ◎")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(start ? FlightColor.teal : FlightColor.gold)
                    .padding(.horizontal,9).padding(.vertical,5)
                    .background(Capsule().fill(FlightColor.space))
                    .overlay(Capsule().stroke((start ? FlightColor.teal : FlightColor.gold).opacity(0.55)))
                    .padding(12)
            }
        }
    }
}

private struct TVRocket: View {
    var body: some View {
        Canvas { context, size in
            let s=size.width/66
            context.scaleBy(x:s,y:s)
            let flame=Path(ellipseIn:CGRect(x:0,y:12,width:26,height:11))
            context.fill(flame,with:.linearGradient(Gradient(colors:[FlightColor.gold.opacity(0),FlightColor.gold]),startPoint:.zero,endPoint:CGPoint(x:26,y:0)))
            var ship=Path(); ship.move(to:CGPoint(x:18,y:7)); ship.addLines([CGPoint(x:66,y:17.5),CGPoint(x:18,y:28),CGPoint(x:26,y:17.5)]); ship.closeSubpath()
            context.fill(ship,with:.linearGradient(Gradient(colors:[FlightColor.channel,.white,FlightColor.panel]),startPoint:CGPoint(x:0,y:7),endPoint:CGPoint(x:0,y:28)))
            context.fill(Path(ellipseIn:CGRect(x:35,y:14,width:12,height:5)),with:.color(FlightColor.space))
        }
    }
}

private struct TVUniverse: View {
    var body: some View {
        Canvas { context, size in
            for i in 0..<105 {
                let x=Double((i*73+17)%307)/307*size.width
                let y=Double((i*103+29)%311)/311*size.height
                let r=i%9==0 ? 1.7:0.8
                context.fill(Path(ellipseIn:CGRect(x:x,y:y,width:r*2,height:r*2)),with:.color(FlightColor.muted.opacity(i%9==0 ? 0.3:0.13)))
            }
            let orbit=CGRect(x:size.width*0.78,y:-size.height*0.08,width:380,height:380)
            context.fill(Path(ellipseIn:orbit),with:.radialGradient(Gradient(colors:[FlightColor.teal.opacity(0.14),FlightColor.panel.opacity(0.3),FlightColor.space]),center:CGPoint(x:orbit.minX+100,y:orbit.minY+80),startRadius:0,endRadius:350))
            context.stroke(Path(ellipseIn:orbit.insetBy(dx:-25,dy:90)),with:.color(FlightColor.teal.opacity(0.08)),lineWidth:1)
        }
    }
}

private struct TVButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.opacity(configuration.isPressed ? 0.75 : 1)
    }
}
