import SwiftUI

// MARK: - Shared Theme

struct HFTheme {
    struct Colors {
        static let bgMain = Color.black
        static let bgPanel = Color(red: 0.06, green: 0.06, blue: 0.06)
        static let bgPanelSoft = Color(red: 0.08, green: 0.08, blue: 0.08)
        static let accent = Color(red: 0.0, green: 1.0, blue: 0.35)
        static let accentSoft = Color(red: 0.45, green: 1.0, blue: 0.65)
        static let accentDim = Color(red: 0.55, green: 1.0, blue: 0.75)
        static let separator = Color.white.opacity(0.08)
        struct Conveyor {
            static let xor = Color(red: 1.0, green: 0.3, blue: 0.43)
            static let shift = Color(red: 0.61, green: 0.36, blue: 0.9)
            static let idle = Color(red: 0.0, green: 0.73, blue: 0.98)
        }
    }

    struct Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat = 8
        static let m: CGFloat = 12
        static let l: CGFloat = 16
        static let xl: CGFloat = 24
    }
}

struct TerminalCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(HFTheme.Spacing.l)
            .background(HFTheme.Colors.bgPanel)
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(HFTheme.Colors.accent.opacity(0.4), lineWidth: 1)
            )
            .cornerRadius(18)
            .shadow(color: HFTheme.Colors.accent.opacity(0.25), radius: 14)
    }
}

extension View {
    func terminalCard() -> some View {
        modifier(TerminalCard())
    }

    func terminalText(_ size: CGFloat, weight: Font.Weight = .regular) -> some View {
        font(.system(size: size, weight: weight, design: .monospaced))
            .foregroundColor(HFTheme.Colors.accentSoft)
    }
}

// MARK: - Palette & Style (legacy)

enum HackerPalette {
    static let neonGreen = Color(red: 0, green: 1, blue: 0.255)
    static let neonSoft = Color(red: 0.15, green: 1, blue: 0.38)
    static let neonDim = Color(red: 0.34, green: 1, blue: 0.59)
    static let neonEdge = Color(red: 0, green: 1, blue: 0.255).opacity(0.4)
    static let neonGlow = Color(red: 0, green: 1, blue: 0.255).opacity(0.15)
    static let neonTerminal = Color(red: 0.36, green: 1, blue: 0.61)

    static let dark = Color(red: 5/255, green: 5/255, blue: 5/255)
    static let panel = Color(red: 0.04, green: 0.04, blue: 0.05)
    static let terminal = Color(red: 0.05, green: 0.06, blue: 0.05)
    static let pipeline = Color(red: 0.03, green: 0.03, blue: 0.04)
}

enum HackerInset: CGFloat {
    case xs = 4
    case s = 8
    case m = 12
    case l = 16
    case xl = 24
    case xxl = 32
}

struct HackerPadding {
    let size: HackerInset
    let edges: Edge.Set

    static func custom(_ size: HackerInset, edges: Edge.Set = .all) -> HackerPadding {
        HackerPadding(size: size, edges: edges)
    }
}

extension View {
    func padding(_ style: HackerPadding) -> some View {
        padding(style.edges, style.size.rawValue)
    }
}

enum HackerHaptics {
    static func light() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.prepare()
        impact.impactOccurred()
    }

    static func medium() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.prepare()
        impact.impactOccurred()
    }
}

struct HackerBackgroundView<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ZStack {
            HFTheme.Colors.bgMain.ignoresSafeArea()
            MatrixRainView()
                .opacity(0.25)
                .ignoresSafeArea()
            content
        }
    }
}

struct HackerCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(HackerPalette.panel)
                    .shadow(color: HackerPalette.neonGreen.opacity(0.6), radius: 6, y: 4)
            )
            .foregroundColor(HackerPalette.neonGreen)
            .font(.system(.body, design: .monospaced))
    }
}

extension View {
    func hackerCard() -> some View {
        modifier(HackerCard())
    }

    func hackerButton() -> some View {
        buttonStyle(.borderedProminent)
            .tint(HackerPalette.neonGreen)
            .buttonBorderShape(.roundedRectangle(radius: 8))
            .shadow(color: HackerPalette.neonGreen.opacity(0.7), radius: 8)
    }
}

// MARK: - Matrix Rain Background

struct MatrixRainView: View {
    private struct Glyph {
        let character: Character
        let baseOpacity: Double
    }

    private struct Column: Identifiable {
        let id = UUID()
        let glyphs: [Glyph]
        let fallSpeed: Double
        let phase: Double
    }

    @State private var columns: [Column] = MatrixRainView.generateColumns(count: 10)

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.45)) { timeline in
            GeometryReader { geo in
                Canvas { context, size in
                    render(context: context, size: size, date: timeline.date)
                }
                .onAppear {
                    updateColumnCount(for: geo.size.width)
                }
                .onChange(of: geo.size.width) { width in
                    updateColumnCount(for: width)
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func render(context: GraphicsContext, size: CGSize, date: Date) {
        guard !columns.isEmpty else { return }
        let spacing: CGFloat = 26
        let travelHeight = size.height + spacing * 24
        let time = date.timeIntervalSinceReferenceDate

        for (index, column) in columns.enumerated() {
            let xPos = CGFloat(index) / CGFloat(max(columns.count - 1, 1)) * size.width
            let offset = (time * column.fallSpeed + column.phase).truncatingRemainder(dividingBy: Double(travelHeight))
            var y: CGFloat = -CGFloat(column.glyphs.count) * spacing + CGFloat(offset)

            for glyph in column.glyphs {
                var text = context.resolve(
                    Text(String(glyph.character))
                        .font(.system(size: 13, design: .monospaced))
                )
                text.shading = .color(HackerPalette.neonGreen.opacity(glyph.baseOpacity))
                context.draw(text, at: CGPoint(x: xPos, y: y))
                y += spacing
            }
        }
    }

    private func updateColumnCount(for width: CGFloat) {
        let desired = max(6, Int(width / 34))
        guard desired != columns.count else { return }
        columns = MatrixRainView.generateColumns(count: desired)
    }

    private static func generateColumns(count: Int) -> [Column] {
        (0..<max(8, count)).map { _ in
            Column(
                glyphs: randomGlyphs(),
                fallSpeed: Double.random(in: 16...28),
                phase: Double.random(in: 0...150)
            )
        }
    }

    private static func randomGlyphs() -> [Glyph] {
        let length = Int.random(in: 8...16)
        return (0..<length).map { _ in
            Glyph(
                character: randomSymbol(),
                baseOpacity: Double.random(in: 0.2...0.65)
            )
        }
    }

    private static func randomSymbol() -> Character {
        let characters = Array("$#%01{}[]/\\<>")
        return characters.randomElement() ?? "0"
    }
}

// MARK: - ASCII Noise Overlay

struct ASCIINoiseOverlay: View {
    let duration: Double
    let onFinish: () -> Void

    @State private var lines: [String] = ASCIINoiseOverlay.randomNoiseFrame()
    @State private var animationTask: Task<Void, Never>?
    @State private var didFinish = false

    var body: some View {
        ZStack {
            HFTheme.Colors.bgMain.ignoresSafeArea()
            HackerPalette.terminal.opacity(0.92).ignoresSafeArea()
            VStack(spacing: 2) {
                ForEach(Array(lines.enumerated()), id: \.offset) { item in
                    Text(item.element)
                        .foregroundColor(HackerPalette.neonGreen)
                        .font(.system(.caption, design: .monospaced))
                }
            }
            .padding(.horizontal, HFTheme.Spacing.m)
        }
        .transition(.opacity)
        .onAppear {
            didFinish = false
            startAnimation()
        }
        .onDisappear {
            stopAnimation()
        }
    }

    private func startAnimation() {
        stopAnimation()
        lines = ASCIINoiseOverlay.randomNoiseFrame()
        animationTask = Task {
            let frameInterval: UInt64 = 80_000_000 // 0.08s
            let start = Date()
            while Date().timeIntervalSince(start) < duration {
                await MainActor.run {
                    lines = ASCIINoiseOverlay.randomNoiseFrame()
                }
                do {
                    try await Task.sleep(nanoseconds: frameInterval)
                } catch {
                    return
                }
                if Task.isCancelled { return }
            }
            await MainActor.run {
                guard !didFinish else { return }
                didFinish = true
                onFinish()
            }
        }
    }

    private func stopAnimation() {
        animationTask?.cancel()
        animationTask = nil
    }

    private static func randomNoiseFrame(lineCount: Int = 12) -> [String] {
        (0..<lineCount).map { _ in randomNoiseLine() }
    }

    private static func randomNoiseLine() -> String {
        let length = Int.random(in: 20...36)
        let chars = "$#%01{}[]/\\\\<>"
        return (0..<length).compactMap { _ in chars.randomElement() }.map(String.init).joined()
    }
}

// MARK: - Value Capsule Picker

struct ValueCapsulePicker<Value: Hashable>: View {
    let title: String
    let options: [Value]
    let selected: Value
    let formatter: (Value) -> String
    let onSelect: (Value) -> Void
    let onShuffle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title.uppercased())
                Spacer()
                Button {
                    onShuffle()
                } label: {
                    Label("Перемешать", systemImage: "arrow.triangle.2.circlepath")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.plain)
                .foregroundColor(HFTheme.Colors.accentSoft)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                ForEach(options, id: \.self) { value in
                    Button {
                        onSelect(value)
                        HackerHaptics.light()
                    } label: {
                        Text(formatter(value))
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                Capsule()
                                    .fill(selected == value ? HFTheme.Colors.accent.opacity(0.2) : HFTheme.Colors.bgPanelSoft)
                                    .overlay(
                                        Capsule()
                                            .stroke(selected == value ? HFTheme.Colors.accent : HFTheme.Colors.accent.opacity(0.35), lineWidth: 1)
                                    )
                                    .shadow(color: selected == value ? HFTheme.Colors.accent.opacity(0.4) : .clear, radius: 6, y: 2)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .font(.system(.footnote, design: .monospaced))
        .foregroundColor(HFTheme.Colors.accentSoft)
    }
}

// MARK: - Mask Picker

struct MaskPickerView: View {
    let correctMask: UInt32?
    let selectedMask: UInt32
    let onSelect: (UInt32) -> Void

    @State private var options: [UInt32] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("MASK".uppercased())
                Spacer()
                Button {
                    shuffle()
                } label: {
                    Label("Перемешать", systemImage: "arrow.triangle.2.circlepath")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.plain)
                .foregroundColor(HFTheme.Colors.accentSoft)
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                ForEach(options, id: \.self) { value in
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                            onSelect(value)
                        }
                        HackerHaptics.light()
                    } label: {
                        MaskCandidateCard(value: value, isSelected: selectedMask == value)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .font(.system(.footnote, design: .monospaced))
        .foregroundColor(HFTheme.Colors.accentSoft)
        .onAppear(perform: shuffle)
    }

    private func shuffle() {
        var set: Set<UInt32> = []
        let desiredCount = 8
        while set.count < desiredCount {
            set.insert(UInt32.random(in: 0...255))
        }
        var list = Array(set)
        if Bool.random(), let correctMask {
            list[Int.random(in: 0..<list.count)] = correctMask
        }
        if !list.contains(selectedMask) {
            list[Int.random(in: 0..<list.count)] = selectedMask
        }
        options = list.shuffled()
    }
}

private struct MaskCandidateCard: View {
    let value: UInt32
    let isSelected: Bool

    @State private var appear = false
    @State private var glow = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(format: "%03d", value))
                .font(.system(.headline, design: .monospaced))
            HStack(spacing: 4) {
                ForEach(Array(value.maskBits.enumerated()), id: \.offset) { index, bit in
                    Text(String(bit))
                        .font(.system(size: 11, design: .monospaced))
                        .padding(4)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(bit == "1" ? HFTheme.Colors.accent.opacity(0.22) : HFTheme.Colors.bgPanelSoft)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(bit == "1" ? HFTheme.Colors.accent : HFTheme.Colors.accent.opacity(0.35), lineWidth: 0.6)
                                )
                        )
                        .shadow(color: glow && bit == "1" ? HFTheme.Colors.accent.opacity(0.4) : .clear, radius: 4, y: 2)
                        .scaleEffect(glow && bit == "1" ? 1.05 : 1)
                        .animation(.easeInOut(duration: 1.4).delay(Double(index) * 0.04), value: glow)
                }
            }
        }
        .padding(.horizontal, HFTheme.Spacing.m)
        .padding(.vertical, HFTheme.Spacing.s)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(HFTheme.Colors.bgPanelSoft)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected ? HFTheme.Colors.accent : HFTheme.Colors.accent.opacity(0.4), lineWidth: 1.2)
                )
                .shadow(color: isSelected ? HFTheme.Colors.accent.opacity(0.35) : .clear, radius: 10, y: 4)
        )
        .scaleEffect(appear ? 1 : 0.92)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                appear = true
            }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }
}

private extension UInt32 {
    var maskBits: [Character] {
        let binary = String(self, radix: 2).pad(to: 8)
        return Array(binary)
    }
}

private extension String {
    func pad(to length: Int) -> String {
        if count >= length { return self }
        return String(repeating: "0", count: length - count) + self
    }
}

// MARK: - Hacker Main Menu

struct HackerMainMenuView: View {
    @EnvironmentObject var profileVM: GameProfileViewModel
    @State private var showHelp = false
    @State private var showLegend = false
    @State private var showProfileSettings = false
    @State private var now = Date()
    @State private var hasSeenIntro = false
    @State private var showIntro = false

    var body: some View {
        mainMenuContent
        .sheet(isPresented: $showHelp) {
            HelpView()
        }
        .sheet(isPresented: $showLegend) {
            LegendView()
        }
        .sheet(isPresented: $showProfileSettings) {
            ProfileSettingsView()
                .environmentObject(profileVM)
        }
        .fullScreenCover(isPresented: $showIntro) {
            IntroNarrativeView {
                hasSeenIntro = true
                showIntro = false
            }
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { tick in
            now = tick
        }
        .onAppear {
            if ProcessInfo.processInfo.environment["UITEST_MODE"] == "1" {
                hasSeenIntro = true
                showIntro = false
            } else if !hasSeenIntro {
                showIntro = true
            }
        }
    }

    private var mainMenuContent: some View {
        ZStack {
            HFTheme.Colors.bgMain.ignoresSafeArea()
            MatrixRainView().opacity(0.18).ignoresSafeArea()
            ScrollView {
                VStack(spacing: HFTheme.Spacing.xl) {
                    statusCard
                    menuColumn
                }
                .padding(HFTheme.Spacing.xl)
            }
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: HFTheme.Spacing.s) {
            Text("HASH FLOW / TERMINAL")
                .terminalText(18, weight: .semibold)
            Text("RANK: \(profileVM.profile.rank.rawValue.uppercased())")
                .terminalText(14)
            Text("RESPECT: \(profileVM.profile.totalRespect)")
                .terminalText(14)
            if let hours = profileVM.freeRunHoursRemaining, hours > 0 {
                Text("FREE-RUN: \(hours)H")
                    .terminalText(14)
                    .foregroundColor(HFTheme.Colors.accent)
            } else if profileVM.isFreeRunActive {
                Text("FREE-RUN: ACTIVE")
                    .terminalText(14)
                    .foregroundColor(HFTheme.Colors.accent)
            } else {
                Text("FREE-RUN: OFF")
                    .terminalText(14)
                    .foregroundColor(HFTheme.Colors.accentDim)
            }
            if let moves = profileVM.movesBalance {
                Text("MOVES: \(moves)")
                    .terminalText(14)
                    .foregroundColor(HFTheme.Colors.accentSoft)
            }
            if let credits = profileVM.creditBalance {
                Text("CREDITS: \(credits)")
                    .terminalText(14)
                    .foregroundColor(HFTheme.Colors.accentSoft)
            }
            if let countdown = profileVM.creditRefillCountdown {
                Text("MOVES REFILL: \(countdown)")
                    .terminalText(12)
                    .foregroundColor(HFTheme.Colors.accentSoft)
            }
            if let profile = profileVM.remoteProfile {
                Button {
                    showProfileSettings = true
                } label: {
                    HStack {
                        Image(systemName: "person")
                            .foregroundColor(HFTheme.Colors.accent)
                        Text(profile.username.uppercased())
                            .terminalText(14, weight: .semibold)
                        Spacer()
                        Image(systemName: "slider.horizontal.3")
                            .foregroundColor(HFTheme.Colors.accentSoft)
                    }
                    .padding(.vertical, HFTheme.Spacing.xs)
                    .padding(.horizontal, HFTheme.Spacing.m)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(HFTheme.Colors.accent.opacity(0.5), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("profile_settings_button")
            } else {
                Button {
                    profileVM.shouldPresentAuthSheet = true
                } label: {
                    HStack {
                        Image(systemName: "person.badge.key")
                        Text("Залогиниться")
                            .terminalText(14, weight: .semibold)
                        Spacer()
                    }
                    .padding(.vertical, HFTheme.Spacing.xs)
                    .padding(.horizontal, HFTheme.Spacing.m)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.orange.opacity(0.6), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("open_auth_sheet")
            }
            Toggle("Хардкор режим", isOn: $profileVM.profile.hardcoreMode)
                .toggleStyle(SwitchToggleStyle(tint: HFTheme.Colors.accent))
                .terminalText(14)
                .accessibilityIdentifier("hardcore_toggle")
        }
        .terminalCard()
    }

    private var menuColumn: some View {
        VStack(spacing: HFTheme.Spacing.m) {
            NavigationLink {
                LevelListView()
                    .environmentObject(profileVM)
            } label: {
                menuButtonLabel(title: "START HACKING", symbol: "play.fill")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("menu_start_hacking")

            NavigationLink {
                DailyChallengeMenuView()
                    .environmentObject(profileVM)
            } label: {
                menuButtonLabel(title: "DAILY CHALLENGE", symbol: "clock.arrow.circlepath")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("menu_daily_challenge")

            NavigationLink {
                UniqueSolutionsView()
                    .environmentObject(profileVM)
            } label: {
                menuButtonLabel(title: "UNIQUE SOLUTIONS", symbol: "hexagon")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("menu_unique_solutions")

            Button {
                showHelp = true
            } label: {
                menuButtonLabel(title: "TERMINAL LOG", symbol: "text.book.closed")
            }
            .accessibilityIdentifier("menu_terminal_log")

            Button {
                showLegend = true
            } label: {
                menuButtonLabel(title: "LEGEND", symbol: "scroll")
            }
            .accessibilityIdentifier("menu_legend")

            NavigationLink {
                LeaderboardView()
                    .environmentObject(profileVM)
            } label: {
                menuButtonLabel(title: "LEADERBOARD", symbol: "trophy")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("menu_leaderboard")

            NavigationLink {
                NFTCollectionView()
                    .environmentObject(profileVM)
            } label: {
                menuButtonLabel(title: "MY NFT COLLECTION", symbol: "seal")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("menu_nft_collection")

            NavigationLink {
                StatsView()
                    .environmentObject(profileVM)
            } label: {
                menuButtonLabel(title: "STATS", symbol: "chart.bar.xaxis")
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("menu_stats")
        }
    }

    private func menuButtonLabel(title: String, symbol: String) -> some View {
        HStack(spacing: HFTheme.Spacing.m) {
            Image(systemName: symbol)
                .foregroundColor(HFTheme.Colors.accentSoft)
            Text(title)
                .terminalText(17, weight: .medium)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .terminalCard()
    }

}
