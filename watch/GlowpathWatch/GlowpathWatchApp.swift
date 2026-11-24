import SwiftUI
import WatchKit

@main
struct GlowpathWatchApp: App {
    var body: some Scene {
        WindowGroup { WatchMissionView() }
    }
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
private final class WatchMission: ObservableObject {
    @Published var level = max(1, UserDefaults.standard.integer(forKey: "watchPreviewLevel"))
    @Published var masks = [Int](repeating: 5, count: 9)
    @Published var lit = Set<Int>()
    @Published var remaining = 30.0
    @Published var turns = 0
    @Published var result: Bool? = nil
    @Published var started = false
    @Published var best = UserDefaults.standard.integer(forKey: "watchPreviewBest")
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

    init() { prepare() }
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
        remaining = 30
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
        WKInterfaceDevice.current().play(.click)
        refreshPath()
    }

    func hint() {
        guard result == nil,
              let index = routePlans[(level - 1) % routePlans.count].first(where: { masks[$0] != solution[$0] }) else { return }
        if !started { started = true; lastTick = Date(); resumeTimer() }
        hintUsed = true
        masks[index] = solution[index]
        turns += 1
        WKInterfaceDevice.current().play(.directionUp)
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
            UserDefaults.standard.set(best, forKey: "watchPreviewBest")
            WKInterfaceDevice.current().play(.success)
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
        if remaining == 0 { result = false; lastTick = nil; timer?.invalidate(); timer = nil; WKInterfaceDevice.current().play(.failure) }
    }

    func retry() {
        remaining = 30
        result = nil
        started = false
        turns = 0
        // The retained tile arrangement still includes any hint assistance.
        lastTick = nil
    }

    func next() {
        level += 1
        UserDefaults.standard.set(level, forKey: "watchPreviewLevel")
        prepare()
    }
}

private struct WatchMissionView: View {
    @StateObject private var mission = WatchMission()
    @Environment(\.scenePhase) private var phase
    @Environment(\.accessibilityReduceMotion) private var reducedMotion
    @AppStorage("watchPreviewHelpSeen") private var helpSeen = false
    @State private var showingHelp = false

    var body: some View {
        GeometryReader { geometry in
            let boardSide = max(90, min(geometry.size.width - 12, geometry.size.height - 46))
            ZStack {
                FlightColor.space.ignoresSafeArea()
                Starfield().allowsHitTesting(false).accessibilityHidden(true)
                if showingHelp || !helpSeen {
                    briefing(height: geometry.size.height)
                } else if let won = mission.result {
                    outcome(won: won, height: geometry.size.height)
                } else {
                    VStack(spacing: 3) {
                        HStack(spacing: 5) {
                            Button {
                                showingHelp = true
                                mission.setActive(false)
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("ROUTE \(String(format: "%02d", mission.level))")
                                        .font(.system(size: 9, weight: .semibold, design: .rounded)).tracking(0.6)
                                    HStack(spacing: 3) {
                                        ForEach(0..<3, id: \.self) { index in
                                            StarMark().fill(index < mission.collected ? FlightColor.gold : FlightColor.muted.opacity(0.3)).frame(width: 8, height: 8)
                                        }
                                    }
                                }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Route \(mission.level). \(mission.collected) of three stars. How to play")
                            Text("\(Int(ceil(mission.remaining)))s")
                                .font(.system(size: 23, weight: .medium, design: .rounded)).monospacedDigit()
                                .foregroundStyle(mission.remaining <= 8 ? Color(red: 1, green: 0.52, blue: 0.40) : FlightColor.gold)
                                .accessibilityLabel("\(Int(ceil(mission.remaining))) seconds remaining")
                            flightButton("Hint", accent: FlightColor.teal) { mission.hint() }.frame(width: 42)
                        }.frame(height: 40).padding(.horizontal, 10)
                        board.frame(width: boardSide, height: boardSide)

                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .foregroundStyle(FlightColor.ink)
        }
        .onChange(of: phase) { _, newPhase in mission.setActive(newPhase == .active && !showingHelp && helpSeen) }
    }

    private var board: some View {
        GeometryReader { bounds in
            let edge = bounds.size.width / 3
            ZStack {
                RoundedRectangle(cornerRadius: 11).fill(FlightColor.panel.opacity(0.65))
                ForEach(0..<9, id: \.self) { index in
                    Button {
                        withAnimation(reducedMotion ? nil : .spring(response: 0.25, dampingFraction: 0.8)) { mission.turn(index) }
                    } label: {
                        TileDrawing(mask: mission.masks[index], lit: mission.lit.contains(index), star: mission.stars.contains(index), start: index == mission.start, finish: index == mission.end)
                    }
                    .buttonStyle(.plain)
                    .frame(width: edge - 2, height: edge - 2)
                    .position(x: edge * (Double(index % 3) + 0.5), y: edge * (Double(index / 3) + 0.5))
                    .accessibilityLabel("Row \(index / 3 + 1), column \(index % 3 + 1)\(index == mission.start ? ", start" : index == mission.end ? ", finish" : "")\(mission.stars.contains(index) ? ", star" : "")")
                    .accessibilityValue("\(connectionDescription(mission.masks[index])). \(mission.lit.contains(index) ? "Lit" : "Unlit")")
                    .accessibilityHint("Turn clockwise")
                }
            }
        }
    }

    private func briefing(height: CGFloat) -> some View {
        let compact = height < 215
        return VStack(spacing: compact ? 6 : 9) {
            Text("GLOWPATH").font(.system(size: 12, weight: .semibold, design: .rounded)).tracking(2).foregroundStyle(FlightColor.teal)
            if !compact { Text("A little flight.").font(.system(size: 21, weight: .medium, design: .rounded)) }
            HStack(spacing: 7) {
                TileDrawing(mask: 10, lit: true, star: false, start: true, finish: false)
                TileDrawing(mask: 10, lit: true, star: true, start: false, finish: false)
                TileDrawing(mask: 10, lit: true, star: false, start: false, finish: true)
            }.frame(height: compact ? 28 : 36)
            Text("Tap to turn. Link START to FINISH through three stars.")
                .font(.system(size: 12, weight: .regular, design: .rounded)).multilineTextAlignment(.center).foregroundStyle(FlightColor.muted)
            Text("30s · starts on your first tap")
                .font(.system(size: 9, weight: .medium, design: .rounded)).foregroundStyle(FlightColor.gold)
            flightButton("Let's fly", accent: FlightColor.teal) {
                helpSeen = true
                showingHelp = false
                mission.setActive(phase == .active)
            }.frame(height: 38)
        }.padding(.horizontal, 12).frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func outcome(won: Bool, height: CGFloat) -> some View {
        let compact = height < 205
        return VStack(spacing: compact ? 6 : 8) {
            ZStack {
                Circle().stroke(FlightColor.teal.opacity(0.2), lineWidth: 1).frame(width: compact ? 40 : 64, height: compact ? 40 : 64)
                StarMark().fill(won ? FlightColor.gold : FlightColor.muted).frame(width: compact ? 24 : 33, height: compact ? 24 : 33)
            }
            Text(won ? "Signal delivered" : "Signal lost")
                .font(.system(size: 19, weight: .medium, design: .rounded)).minimumScaleFactor(0.8).lineLimit(1)
            Text(won ? "+\(mission.score) points · \(mission.turns) turns" : "Your route stays ready.")
                .font(.system(size: 11, design: .rounded)).foregroundStyle(FlightColor.muted)
            if won { Text("Best flight \(mission.best)").font(.system(size: 10, design: .rounded)).foregroundStyle(FlightColor.gold) }
            flightButton(won ? "Next flight" : "Retry", accent: FlightColor.gold) {
                if won { mission.next() } else { mission.retry() }
            }.frame(height: 42)
        }.padding(.horizontal, 12).frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func flightButton(_ title: String, accent: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.system(size: 12, weight: .semibold, design: .rounded))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(RoundedRectangle(cornerRadius: 12).fill(accent.opacity(0.09)))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(accent.opacity(0.4), lineWidth: 0.7))
        }.buttonStyle(.plain)
    }
}

private func connectionDescription(_ mask: Int) -> String {
    zip([1, 2, 4, 8], ["up", "right", "down", "left"]).filter { mask & $0.0 != 0 }.map { $0.1 }.joined(separator: " and ")
}

private struct TileDrawing: View {
    let mask: Int
    let lit, star, start, finish: Bool
    var body: some View {
        Canvas { context, size in
            let rect = CGRect(origin: .zero, size: size)
            context.fill(Path(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 7), with: .linearGradient(Gradient(colors: [FlightColor.panel, FlightColor.space]), startPoint: .zero, endPoint: CGPoint(x: size.width, y: size.height)))
            context.stroke(Path(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), cornerRadius: 7), with: .color(FlightColor.teal.opacity(lit ? 0.25 : 0.08)), lineWidth: 0.6)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let points = [CGPoint(x: center.x, y: 0), CGPoint(x: size.width, y: center.y), CGPoint(x: center.x, y: size.height), CGPoint(x: 0, y: center.y)]
            let exits = (0..<4).filter { mask & (1 << $0) != 0 }
            var route = Path()
            route.move(to: points[exits[0]])
            if abs(exits[0] - exits[1]) == 2 { route.addLine(to: points[exits[1]]) }
            else { route.addQuadCurve(to: points[exits[1]], control: center) }
            let color = lit ? FlightColor.gold : FlightColor.channel
            if lit { context.stroke(route, with: .color(color.opacity(0.16)), style: StrokeStyle(lineWidth: 12, lineCap: .round)) }
            context.stroke(route, with: .color(color), style: StrokeStyle(lineWidth: max(5, size.width * 0.14), lineCap: .round))
            if star {
                context.fill(Path(ellipseIn: CGRect(x: center.x - 7, y: center.y - 7, width: 14, height: 14)), with: .color(FlightColor.space))
                context.stroke(StarMark().path(in: CGRect(x: center.x - 5, y: center.y - 5, width: 10, height: 10)), with: .color(lit ? FlightColor.gold : FlightColor.channel), lineWidth: 1)
            }
            if start {
                var arrow = Path()
                arrow.move(to: CGPoint(x: 2, y: center.y - 4))
                arrow.addLines([CGPoint(x: 8, y: center.y), CGPoint(x: 2, y: center.y + 4)])
                arrow.closeSubpath()
                context.fill(arrow, with: .color(FlightColor.teal))
            }
            if finish {
                context.stroke(Path(ellipseIn: CGRect(x: size.width - 8, y: center.y - 3, width: 6, height: 6)), with: .color(FlightColor.gold), lineWidth: 1.5)
            }
        }
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

private struct Starfield: View {
    var body: some View {
        Canvas { context, size in
            for index in 0..<24 {
                let x = Double((index * 73 + 17) % 101) / 101 * size.width
                let y = Double((index * 43 + 29) % 103) / 103 * size.height
                let radius = index % 4 == 0 ? 0.7 : 0.4
                context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: radius * 2, height: radius * 2)), with: .color(FlightColor.muted.opacity(0.24)))
            }
        }
    }
}
