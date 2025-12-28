import SwiftUI
import UniformTypeIdentifiers

struct LevelPlayView: View {
    @EnvironmentObject var profileVM: GameProfileViewModel
    @Environment(\.dismiss) private var dismiss
    @Binding var level: Level
    @StateObject private var graphVM: HashGraphViewModel
    @State private var showTrace = false
    @State private var showHelp = false
    @State private var showSuccess = false
    @State private var lastBonus = 0
    @State private var penaltyMessage: String?
    @State private var completionBreakdown: [String] = []
    @State private var attemptCount = 0
    @State private var showHintAlert = false
    @State private var hintText = ""
    @State private var showOutOfTokensAlert = false
    @State private var outOfTokensNote: String?
    @State private var didBuyTokens = false
    @State private var hintUsageCount = 0
    @State private var achievementMessage: String?
    @State private var showNoise = false
    @State private var showDuplicateAlert = false
    @State private var duplicateAlertMessage: String?
    @State private var nftStatusMessage: String?
    @StateObject private var keyboardObserver = KeyboardObserver()
    @State private var isCheckingUniqueness = false
    private let pipelineAnchor = "pipeline-anchor"
    @State private var runButtonPressed = false
    @State private var isRunInFlight = false
    @State private var draggedNode: HashNode?
    @State private var dropGapIndex: Int?
    @State private var paletteOptions: [NodePaletteOption] = []
    @State private var paletteCountdown: Int = 10
    @State private var paletteTimer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    @State private var isPalettePaused = false
    @State private var isPaletteCollapsed = false
    @State private var showLeaderboardSheet = false
    @State private var isPipelineFrozen = false
    private let paletteRefreshInterval = 10
    private let paletteColumns = Array(repeating: GridItem(.flexible(), spacing: HFTheme.Spacing.s), count: 3)

    private let originDifficulty: LevelDifficulty?
    private let dailyLevels: [Level]?
    private let dailyIndex: Int?
    private let onDailyAdvance: ((Int) -> Void)?

    init(
        level: Binding<Level>,
        originDifficulty: LevelDifficulty? = nil,
        dailyLevels: [Level]? = nil,
        dailyIndex: Int? = nil,
        onDailyAdvance: ((Int) -> Void)? = nil
    ) {
        self._level = level
        self.originDifficulty = originDifficulty
        self.dailyLevels = dailyLevels
        self.dailyIndex = dailyIndex
        self.onDailyAdvance = onDailyAdvance
        _graphVM = StateObject(wrappedValue: HashGraphViewModel(
            inputValue: level.wrappedValue.inputValue,
            targetValue: level.wrappedValue.targetValue
        ))
    }

    @ViewBuilder
    private func scrollContainer(proxy: ScrollViewProxy) -> some View {
        if isPaletteCollapsed {
            ScrollView {
                scrollStackContent
                    .padding(.horizontal, HFTheme.Spacing.l)
                    .padding(.top, HFTheme.Spacing.l)
                    .padding(.bottom, HFTheme.Spacing.l + keyboardObserver.keyboardHeight)
            }
            .accessibilityIdentifier("level_scroll_view")
            .onChange(of: graphVM.nodes.count) { _ in
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    proxy.scrollTo(pipelineAnchor, anchor: .bottom)
                }
            }
            .onChange(of: keyboardObserver.keyboardHeight) { height in
                guard height > 0 else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(pipelineAnchor, anchor: .bottom)
                }
            }
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: HFTheme.Spacing.l) {
                    tracePanel
                    pipelineSection
                    assistantPanel
                }
                .padding(.horizontal, HFTheme.Spacing.l)
                .padding(.top, HFTheme.Spacing.l)
                .padding(.bottom, HFTheme.Spacing.l + keyboardObserver.keyboardHeight)
            }
            .accessibilityIdentifier("level_scroll_view")
            .onChange(of: graphVM.nodes.count) { _ in
                withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
                    proxy.scrollTo(pipelineAnchor, anchor: .bottom)
                }
            }
            .onChange(of: keyboardObserver.keyboardHeight) { height in
                guard height > 0 else { return }
                withAnimation(.easeInOut(duration: 0.25)) {
                    proxy.scrollTo(pipelineAnchor, anchor: .bottom)
                }
            }
        }
    }

    init(
        level: Level,
        originDifficulty: LevelDifficulty? = nil,
        dailyLevels: [Level]? = nil,
        dailyIndex: Int? = nil,
        onDailyAdvance: ((Int) -> Void)? = nil
    ) {
        self.init(
            level: .constant(level),
            originDifficulty: originDifficulty,
            dailyLevels: dailyLevels,
            dailyIndex: dailyIndex,
            onDailyAdvance: onDailyAdvance
        )
    }

    var body: some View {
        let foregroundColor = HFTheme.Colors.accentSoft
        let textFont = Font.system(.body, design: .monospaced)
        let tintColor = HFTheme.Colors.accent
        let navigationTitleText = level.name
        let tapGesture = TapGesture().onEnded { hideKeyboard() }
        let helpSheetView = HelpView()
        let victoryStats = LevelVictoryStats(
            totalRespect: profileVM.profile.totalRespect,
            uniqueSolutions: profileVM.solutionCount(for: level),
            leaderboardRank: currentLeaderboardPosition()
        )
        let successOverlayView = SuccessOverlay(
            respectGain: lastBonus,
            rank: profileVM.profile.rank.rawValue,
            breakdown: completionBreakdown,
            isUnique: graphVM.uniqueSolutionUnlocked,
            stats: victoryStats
        ) {
            showSuccess = false
        } onShowLeaderboard: {
            showLeaderboardSheet = true
        }
        let bonusAlertMessage = Text("Ходов осталось: \(profileVM.movesBalance ?? 0). Кредитов: \(profileVM.creditBalance ?? 0). Можно докупить кредиты, если ходы на нуле.")
        let duplicateMessageText = duplicateAlertMessage ?? "Этот пайплайн уже отправлялся. Собери новый, чтобы получить кредиты и респект."
        let outOfTokensAction = {
            outOfTokensNote = "Завтра можешь попытаться ещё. Если несколько дней подряд будешь топтаться на месте, зона уровней сузится."
        }

        let baseLayout = mainLayout
            .foregroundColor(foregroundColor)
            .font(textFont)
            .tint(tintColor)
            .navigationTitle(navigationTitleText)
            .navigationBarBackButtonHidden(true)

        let base = baseLayout
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    toolbarButton(title: backButtonTitle, systemName: "chevron.left") {
                        handleBackNavigation()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    toolbarButton(title: "Подсказка", systemName: "sparkles") {
                        showHelp = true
                    }
                }
            }
            .sheet(isPresented: $showHelp) {
                helpSheetView
            }
            .applyToolbarBackground()

        let decorated = base
            .onAppear {
                graphVM.reset(for: level)
                preparePaletteForCurrentState()
                graphVM.showPrefilled = true
            }
            .onDisappear {
                isPalettePaused = true
                isCheckingUniqueness = false
            }
            .onChange(of: level.id) { _ in
                graphVM.reset(for: level)
                preparePaletteForCurrentState()
                graphVM.showPrefilled = true
                isPaletteCollapsed = false
                isPalettePaused = false
                isPipelineFrozen = false
                showSuccess = false
            }
            .onChange(of: profileVM.profile.hardcoreMode) { _ in
                preparePaletteForCurrentState()
                updateNodeLockState()
            }
            .onChange(of: isPipelineFrozen) { _ in
                updateNodeLockState()
            }
            .onChange(of: showSuccess) { value in
                if value {
                    isPalettePaused = true
                    isCheckingUniqueness = false
                }
            }
            .overlay(
                Group {
                    if showSuccess {
                        successOverlayView
                    }
                    if isCheckingUniqueness {
                        ZStack {
                            Color.black.opacity(0.45).ignoresSafeArea()
                            VStack(spacing: HFTheme.Spacing.m) {
                                ProgressView()
                                    .progressViewStyle(.circular)
                                    .tint(HFTheme.Colors.accent)
                                Text("Проверка уникальности…")
                                    .terminalText(14, weight: .semibold)
                                    .foregroundColor(HFTheme.Colors.accentSoft)
                            }
                            .padding()
                            .background(HFTheme.Colors.bgPanelSoft)
                            .cornerRadius(12)
                            .shadow(radius: 8)
                        }
                    }
                }
            )
            .alert("SHA-Ассистент на связи", isPresented: $showHintAlert, presenting: hintText) { _ in
                Button("Сохранил", role: .cancel) { }
            } message: { text in
                Text(text)
            }
            .alert("Кредиты закончились", isPresented: $showOutOfTokensAlert) {
                Button("Купить 500 кредитов за 100₽") {
                    Task {
                        await profileVM.purchaseBonusPack()
                        didBuyTokens = true
                        outOfTokensNote = nil
                    }
                }
                Button("Продолжить завтра", role: .cancel) {
                    outOfTokensAction()
                }
            } message: { bonusAlertMessage }
            .alert("Повторный пайплайн", isPresented: $showDuplicateAlert) {
                Button("Ок", role: .cancel) { }
            } message: { Text(duplicateMessageText) }
            .overlay(noiseOverlay)
            .dynamicTypeSize(.medium ... .accessibility5)
            .gesture(
                tapGesture,
                including: .gesture
            )
            .onChange(of: graphVM.nodes) { _ in
                resetDragIndicators()
            }
            .onChange(of: draggedNode?.id) { newValue in
                if newValue == nil {
                    dropGapIndex = nil
                }
            }

        let interactiveView = decorated
            .sheet(isPresented: $showLeaderboardSheet) {
                NavigationView {
                    LeaderboardView()
                        .environmentObject(profileVM)
                }
            }
            .enableSwipeBack(perform: profileVM.currentLevel != nil ? handleBackNavigation : nil)

        return AnyView(interactiveView.interactiveBackGesture(onBack: handleBackNavigation))
    }

    private var mainLayout: some View {
        HackerBackgroundView {
            levelScroll
        }
        .overlay(alignment: .topTrailing) {
            if isUITestMode {
                uitestOverlay
            }
        }
    }

    private var levelScroll: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                if !profileVM.profile.hardcoreMode {
                    VStack(spacing: HFTheme.Spacing.m) {
                        if !isPaletteCollapsed {
                            infoPanel
                                .padding(.horizontal, HFTheme.Spacing.l)
                                .padding(.top, HFTheme.Spacing.l)
                        }
                        if !profileVM.profile.hardcoreMode && !isPipelineFrozen && !isPaletteCollapsed {
                            paletteDock
                                .padding(.horizontal, HFTheme.Spacing.l)
                        }
                    }
                }

                scrollContainer(proxy: proxy)

                Divider()
                    .background(HFTheme.Colors.separator)

                stickyRunBar
                    .padding(.horizontal, HFTheme.Spacing.l)
                    .padding(.vertical, HFTheme.Spacing.m)
                    .background(HFTheme.Colors.bgPanel.opacity(0.95))
            }
        }
    }

    private var isUITestMode: Bool {
        let env = ProcessInfo.processInfo.environment
        if env["UITEST_MODE"] == "1" || env["UITEST_OVERLAY"] == "1" {
            return true
        }
        if env.keys.contains(where: { $0.hasPrefix("UITEST_") }) {
            return true
        }
        if env["XCTestConfigurationFilePath"] != nil {
            return true
        }
        return ProcessInfo.processInfo.arguments.contains("UITEST_MODE")
    }

    private var uitestOverlay: some View {
        VStack(alignment: .trailing, spacing: HFTheme.Spacing.s) {
            Button("SET PIPELINE") {
                applyUITestPipeline()
            }
            .accessibilityIdentifier("uitest_set_pipeline")
            Button("RUN PIPELINE") {
                runPipeline()
            }
            .accessibilityIdentifier("uitest_run_pipeline")
        }
        .font(.system(size: 12, weight: .semibold, design: .monospaced))
        .padding(8)
        .background(Color.black.opacity(0.7))
        .cornerRadius(8)
        .padding(.top, 8)
        .padding(.trailing, 8)
        .accessibilityIdentifier("uitest_overlay")
        .accessibilityElement(children: .contain)
    }

    private var scrollStackContent: some View {
        VStack(alignment: .leading, spacing: HFTheme.Spacing.l) {
            if profileVM.profile.hardcoreMode {
                infoPanel
                pipelineSection
                tracePanel
            } else if isPaletteCollapsed {
                infoPanel
            }
            if isPaletteCollapsed {
                pipelineSection
                tracePanel
            } else if !profileVM.profile.hardcoreMode {
                tracePanel
                pipelineSection
            }
            assistantPanel
        }
    }

    private var noiseOverlay: some View {
        Group {
            if showNoise {
                ASCIINoiseOverlay(duration: 0.6) {
                    showNoise = false
                    runPipeline()
                }
            }
        }
        .allowsHitTesting(false)
    }

    private var infoPanel: some View {
        hackerPanel {
            VStack(alignment: .leading, spacing: HFTheme.Spacing.m) {
                Text(level.name.uppercased())
                    .terminalText(20, weight: .bold)
                Text(level.description)
                    .terminalText(14)
                    .foregroundColor(HFTheme.Colors.accentDim)
                if let hint = level.legendHint {
                    Text(hint)
                        .terminalText(12)
                        .foregroundColor(HFTheme.Colors.accent)
                }

                HStack(alignment: .top, spacing: HFTheme.Spacing.l) {
                    infoColumn(title: "INPUT", value: "\(graphVM.inputValue)")
                    infoColumn(title: "TARGET", value: "\(level.targetValue)")
                    infoColumn(title: "RESULT", value: graphVM.result.map(String.init) ?? "—")
                }

                HStack {
                    Image(systemName: "star.circle.fill")
                        .foregroundColor(HFTheme.Colors.accent)
                    VStack(alignment: .leading, spacing: HFTheme.Spacing.xs) {
                        Text("Ходы: \(profileVM.movesBalance ?? 0)")
                            .terminalText(14, weight: .semibold)
                        Text("Кредиты: \(profileVM.creditBalance ?? 0)")
                            .terminalText(14, weight: .semibold)
                    }
                }

                let statusText: String? = {
                    if let success = graphVM.isSuccess {
                        return success ? "Цель достигнута" : "Цель пока не достигнута"
                    }
                    return nil
                }()
                let statusColor: Color = {
                    if let success = graphVM.isSuccess {
                        return success ? HFTheme.Colors.accentSoft : Color.orange
                    }
                    return HFTheme.Colors.accentSoft
                }()

                Text(statusText ?? "Цель пока не достигнута")
                    .terminalText(15, weight: .medium)
                    .foregroundColor(statusColor)
                    .opacity(statusText == nil ? 0 : 1)

                // Кнопка показа/скрытия предзаполненных нод скрыта по требованию.
            }
        }
        .accessibilityIdentifier("info_panel")
        .onTapGesture {
            if profileVM.profile.hardcoreMode {
                updateNodeLockState()
            }
        }
    }

    private var canReorderNodes: Bool {
        !profileVM.profile.hardcoreMode && !isPipelineFrozen
    }

    private func infoColumn(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: HFTheme.Spacing.xs) {
            Text(title)
                .terminalText(12)
                .foregroundColor(HFTheme.Colors.accentDim)
            Text(value)
                .terminalText(18, weight: .semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var pipelineSection: some View {
        hackerPanel {
            LazyVStack(alignment: .leading, spacing: HFTheme.Spacing.m, pinnedViews: [.sectionHeaders]) {
                Section(header: pipelineStickyHeader) {
                    VStack(alignment: .leading, spacing: HFTheme.Spacing.m) {
                        if showSuccess {
                            Text("Пайплайн (просмотр): изменения недоступны после прохождения.")
                                .terminalText(13)
                                .foregroundColor(HFTheme.Colors.accentDim)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        ForEach(Array(graphVM.nodes.enumerated()), id: \.element.id) { index, node in
                            if canReorderNodes && !showSuccess {
                                dropGapView(targetIndex: index)
                            }
                            let nodeBinding = Binding<HashNode>(
                                get: {
                                    guard graphVM.nodes.indices.contains(index) else { return node }
                                    return graphVM.nodes[index]
                                },
                                set: { newValue in
                                    guard graphVM.nodes.indices.contains(index) else { return }
                                    graphVM.nodes[index] = newValue
                                }
                            )
                            let baseView = NodeRowView(
                                node: nodeBinding,
                                baseValue: graphVM.inputValue,
                                isHardcore: profileVM.profile.hardcoreMode,
                                isEasyDifficulty: level.difficulty == .easy,
                                onDelete: {
                                    removeNode(nodeBinding)
                                }
                            )
                            .disabled(isPipelineFrozen || showSuccess)
                            reorderableNodeView(baseView: baseView, node: nodeBinding.wrappedValue)
                                .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity),
                                                        removal: .scale.combined(with: .opacity)))
                        }
                        if canReorderNodes && !showSuccess {
                            dropGapView(targetIndex: graphVM.nodes.count)
                        }
                        Color.clear.frame(height: 1).id(pipelineAnchor)
                    }
                }
            }
        }
        .accessibilityIdentifier("pipeline_section")
    }

    @ViewBuilder
    private func reorderableNodeView<V: View>(baseView: V, node: HashNode) -> some View {
        baseView
    }

    @ViewBuilder
    private func dropGapView(targetIndex: Int) -> some View {
        Color.clear.frame(height: 1)
    }

    private var pipelineStickyHeader: some View {
        VStack(alignment: .leading, spacing: HFTheme.Spacing.s) {
            Text("ПАЙПЛАЙН")
                .terminalText(16, weight: .semibold)

            HStack(spacing: HFTheme.Spacing.s) {
                pipelineMetric(title: "RESULT", value: graphVM.result.map(String.init) ?? "—")
                pipelineMetric(title: "TARGET", value: "\(level.targetValue)")
            }

            HStack(spacing: HFTheme.Spacing.m) {
                pipelineControlButton(icon: "x.square", title: "Add XOR") {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        graphVM.addXorNode()
                    }
                    HackerHaptics.light()
                }
                .disabled(showSuccess || isPipelineFrozen)
                .accessibilityIdentifier("pipeline_add_xor")
                pipelineControlButton(icon: "arrow.left.and.right", title: "Add Shift") {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        graphVM.addShiftLeftNode()
                    }
                    HackerHaptics.light()
                }
                .disabled(showSuccess || isPipelineFrozen)
                .accessibilityIdentifier("pipeline_add_shift")
            }
        }
        .padding(.horizontal, HFTheme.Spacing.m)
        .padding(.vertical, HFTheme.Spacing.s)
        .background(HFTheme.Colors.bgPanelSoft.opacity(0.95))
        .accessibilityIdentifier("pipeline_header")
    }

    private func pipelineMetric(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .terminalText(10)
                .foregroundColor(HFTheme.Colors.accentDim)
            Text(value)
                .terminalText(14, weight: .semibold)
        }
        .padding(.horizontal, HFTheme.Spacing.m)
        .padding(.vertical, HFTheme.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(HFTheme.Colors.bgPanel)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(HFTheme.Colors.accent.opacity(0.4), lineWidth: 1)
                )
        )
    }

    private var assistantPanel: some View {
        Group {
            if profileVM.profile.hardcoreMode {
                hackerPanel {
                    VStack(alignment: .leading, spacing: HFTheme.Spacing.m) {
                        Text("SHA-Ассистент")
                            .terminalText(16, weight: .semibold)

                        if let penaltyMessage {
                            Text(penaltyMessage)
                                .terminalText(14)
                                .foregroundColor(.orange)
                        }

                        if let note = outOfTokensNote {
                            Text(note)
                                .terminalText(14)
                                .foregroundColor(.orange)
                        }

                        if let achievementMessage {
                            Text(achievementMessage)
                                .terminalText(14)
                                .foregroundColor(.purple)
                        }

                        if let nftStatusMessage {
                            Text(nftStatusMessage)
                                .terminalText(14)
                                .foregroundColor(HFTheme.Colors.accentSoft)
                        }

                        Button {
                            requestHint()
                        } label: {
                            Text("Подсказка за 10 кредитов")
                                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, HFTheme.Spacing.s)
                                .background(HFTheme.Colors.accent)
                                .cornerRadius(12)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var stickyRunBar: some View {
        HStack(spacing: HFTheme.Spacing.m) {
            classicRunButton

            if graphVM.isSuccess == true {
                resetLevelButton
            }

            if graphVM.isSuccess == true, let next = nextLevel {
                nextLevelButton(for: next)
            }
        }
    }

    private var tracePanel: some View {
        hackerPanel {
            DisclosureGroup(isExpanded: $showTrace) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(graphVM.trace.enumerated()), id: \.offset) { _, entry in
                        Text(entry)
                            .terminalText(13)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.top, HFTheme.Spacing.s)
            } label: {
                HStack {
                    Text("TRACE")
                        .terminalText(16, weight: .semibold)
                }
            }
        }
    }

    private var paletteTimerView: some View {
        hackerPanel {
            HStack(spacing: HFTheme.Spacing.m) {
                VStack(alignment: .leading, spacing: HFTheme.Spacing.xs) {
                    Text("Панель нод")
                        .terminalText(16, weight: .semibold)
                    Text("Обновление каждые \(paletteRefreshInterval) сек.")
                        .terminalText(12)
                        .foregroundColor(HFTheme.Colors.accentDim)
                }
                Spacer()
                Text(isPalettePaused ? "PAUSE" : "\(paletteCountdown)s")
                    .terminalText(16, weight: .bold)
                    .foregroundColor(isPalettePaused ? .orange : HFTheme.Colors.accent)
                Button {
                    togglePalettePause()
                } label: {
                    Image(systemName: isPalettePaused ? "play.fill" : "pause.fill")
                        .foregroundColor(.black)
                        .padding(10)
                        .background(HFTheme.Colors.accent)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .disabled(isPipelineFrozen)
            }
        }
        .onReceive(paletteTimer) { _ in
            guard !showSuccess else { return }
            guard !profileVM.profile.hardcoreMode else { return }
            guard !isPalettePaused else { return }
            guard !isPipelineFrozen else { return }
            guard paletteCountdown > 0 else {
                regeneratePaletteOptions()
                return
            }
            paletteCountdown -= 1
            if paletteCountdown <= 0 {
                regeneratePaletteOptions()
            }
        }
    }

    private var nodePaletteGrid: some View {
        hackerPanel {
            if paletteOptions.isEmpty {
                Text("Создаём набор нод...")
                    .terminalText(14)
                    .foregroundColor(HFTheme.Colors.accentDim)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                LazyVGrid(columns: paletteColumns, spacing: HFTheme.Spacing.s) {
                    ForEach(paletteOptions) { option in
                        Button {
                            applyPaletteOption(option)
                        } label: {
                            paletteOptionView(option)
                        }
                        .buttonStyle(.plain)
                        .disabled(isPalettePaused || isPipelineFrozen)
                    }
                }
                .animation(.easeInOut(duration: 0.25), value: paletteOptions)
            }
        }
    }

    private func paletteOptionView(_ option: NodePaletteOption) -> some View {
        let accent = paletteAccentColor(for: option)
        return VStack(spacing: HFTheme.Spacing.xs) {
            Text(option.icon)
                .font(.system(size: 20, weight: .bold, design: .monospaced))
                .foregroundColor(accent)
            Text(option.label)
                .terminalText(11, weight: .semibold)
                .foregroundColor(accent)
            if isPalettePaused {
                Text("Пауза")
                    .terminalText(11)
                    .foregroundColor(HFTheme.Colors.accentDim)
            } else {
                Text(option.valueDescription)
                    .terminalText(14, weight: .bold)
                    .foregroundColor(.white)
            }
        }
        .padding(.vertical, HFTheme.Spacing.s)
        .padding(.horizontal, HFTheme.Spacing.s)
        .frame(maxWidth: .infinity, minHeight: 68)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(accent.opacity(0.15))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(option.isWinning ? Color.green : accent.opacity(0.5), lineWidth: option.isWinning ? 2 : 1)
        )
    }

    private func paletteAccentColor(for option: NodePaletteOption) -> Color {
        switch option.action {
        case .xor:
            return HFTheme.Colors.accent
        case .shift:
            return Color.purple
        }
    }

    private var resetLevelButton: some View {
        Button {
            resetCurrentLevelState()
        } label: {
            HStack {
                Image(systemName: "arrow.counterclockwise")
                Text("Сбросить")
                    .terminalText(14, weight: .semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, HFTheme.Spacing.m)
            .background(HFTheme.Colors.bgPanelSoft)
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
    }

    private var paletteDock: some View {
        VStack(spacing: HFTheme.Spacing.m) {
            paletteTimerView
            nodePaletteGrid
        }
    }

    private func pipelineControlButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(HFTheme.Colors.accentSoft)
                Text(title)
                    .terminalText(15, weight: .semibold)
            }
            .padding(.vertical, HFTheme.Spacing.s)
            .frame(maxWidth: .infinity)
            .background(HFTheme.Colors.bgPanelSoft)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(HFTheme.Colors.accent.opacity(0.5), lineWidth: 1)
            )
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
        .disabled(isPipelineFrozen)
    }

    private var classicRunButton: some View {
        Button {
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            runButtonPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                runButtonPressed = false
            }
            showNoise = true
        } label: {
            HStack {
                Image(systemName: "play.fill")
                    .foregroundColor(.black)
                Text("run")
                    .font(.system(size: 17, weight: .semibold, design: .monospaced))
                    .foregroundColor(.black)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, HFTheme.Spacing.m)
            .background(HFTheme.Colors.accent)
            .cornerRadius(14)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("run_button")
        .scaleEffect(runButtonPressed ? 0.97 : 1)
        .disabled(isPipelineFrozen || isRunInFlight)
    }

    private func togglePalettePause() {
        guard !isPipelineFrozen else { return }
        isPalettePaused.toggle()
        if !isPalettePaused && paletteOptions.isEmpty {
            regeneratePaletteOptions()
        }
    }

    private func applyPaletteOption(_ option: NodePaletteOption) {
        guard !isPalettePaused,
              !profileVM.profile.hardcoreMode,
              !showSuccess,
              !isPipelineFrozen else { return }
        let node = option.makeNode()
        withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
            graphVM.nodes.append(node)
        }
        HackerHaptics.light()
        runPipeline()
    }

    private func preparePaletteForCurrentState() {
        isPipelineFrozen = false
        updateNodeLockState()
        guard !profileVM.profile.hardcoreMode else {
            paletteOptions = []
            return
        }
        isPalettePaused = false
        regeneratePaletteOptions()
    }

    private func regeneratePaletteOptions() {
        guard !profileVM.profile.hardcoreMode else {
            paletteOptions = []
            return
        }
        paletteCountdown = paletteRefreshInterval
        let currentValue = graphVM.result ?? graphVM.inputValue
        paletteOptions = generatePaletteOptions(currentValue: currentValue, targetValue: level.targetValue)
    }

    private func generatePaletteOptions(currentValue: UInt32, targetValue: UInt32) -> [NodePaletteOption] {
        var options: [NodePaletteOption] = []
        var usedMasks = Set<UInt32>()
        let winningMask = targetValue ^ currentValue
        options.append(NodePaletteOption(action: .xor(mask: winningMask), label: "XOR", isWinning: (currentValue ^ winningMask) == targetValue))
        usedMasks.insert(winningMask)

        let maskVariants: [UInt32] = [
            (winningMask << 1) & 0xFFFF_FFFF,
            (winningMask >> 1),
            winningMask ^ 0x00FF00FF,
            winningMask ^ 0xFF00FF00,
            (targetValue & 0xFFFF0000) | (currentValue & 0x0000FFFF),
            winningMask ^ UInt32(level.id & 0xFFFF),
            UInt32.random(in: 1...0xFFFF_FFFF)
        ]

        for variant in maskVariants {
            guard !usedMasks.contains(variant) else { continue }
            options.append(NodePaletteOption(action: .xor(mask: variant), label: "XOR", isWinning: false))
            usedMasks.insert(variant)
            if options.count >= 6 { break }
        }

        while options.count < 6 {
            let randomMask = UInt32.random(in: 1...0xFFFF_FFFF)
            guard !usedMasks.contains(randomMask) else { continue }
            usedMasks.insert(randomMask)
            options.append(NodePaletteOption(action: .xor(mask: randomMask), label: "XOR", isWinning: false))
        }

        let bestShift = max(1, min(8, bestShiftCandidate()))
        var shiftCandidates = [bestShift,
                               max(1, bestShift - 1),
                               min(8, bestShift + 1),
                               (level.id % 5) + 1]
        if shiftCandidates.count < 3 {
            shiftCandidates.append(contentsOf: 1...3)
        }
        var seenShifts = Set<Int>()
        for shift in shiftCandidates where seenShifts.insert(shift).inserted {
            let resultingValue = shiftLeft(currentValue, by: shift)
            options.append(
                NodePaletteOption(
                    action: .shift(bits: shift),
                    label: "SHIFT",
                    isWinning: resultingValue == targetValue
                )
            )
            if options.count >= 9 { break }
        }

        while options.count < 9 {
            let shift = Int.random(in: 1...8)
            guard seenShifts.insert(shift).inserted else { continue }
            let resultingValue = shiftLeft(currentValue, by: shift)
            options.append(NodePaletteOption(action: .shift(bits: shift), label: "SHIFT", isWinning: resultingValue == targetValue))
        }

        return options.shuffled()
    }

    private func shiftLeft(_ value: UInt32, by bits: Int) -> UInt32 {
        let clamped = max(0, min(31, bits))
        return (value << clamped) & 0xFFFF_FFFF
    }

    private func refreshPaletteAfterRunResult() {
        guard !profileVM.profile.hardcoreMode else { return }
        guard !isPipelineFrozen else { return }
        guard !isPalettePaused else { return }
        guard !showSuccess else { return }
        regeneratePaletteOptions()
    }

    private func submitPipelineAnalytics() async -> Bool {
        let overlayTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            isCheckingUniqueness = true
        }
        let watchdog = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 12_000_000_000)
            isCheckingUniqueness = false
        }
        defer {
            overlayTask.cancel()
            watchdog.cancel()
            Task { @MainActor in isCheckingUniqueness = false }
        }

        guard
            let representation = graphVM.pipelineRepresentation(),
            let user = try? await SupabaseService.shared.currentUser(),
            let jsonData = representation.rawJSON.data(using: .utf8),
            let _ = try? JSONSerialization.jsonObject(with: jsonData)
        else { return false }

        let playerUUID = UUID(uuidString: user.id.uuidString) ?? user.id
        do {
            let inserted = try await SupabaseService.shared.recordUniqueSolution(
                playerId: playerUUID,
                levelId: level.id,
                pipelineHash: representation.hash,
                pipelineRaw: representation.rawJSON,
                pipelineLength: representation.length
            )
            await MainActor.run {
                graphVM.uniqueSolutionUnlocked = inserted
                if inserted {
                    nftStatusMessage = "Уникальное решение записано."
                }
            }
            if !inserted {
                await MainActor.run {
                    duplicateAlertMessage = "Этот пайплайн уже отправлялся. Собери новый, чтобы получить кредиты и респект."
                    showDuplicateAlert = true
                }
            }
            await profileVM.refreshCreditsAndSolutions()
            await profileVM.refreshPlayerLevelStats(force: true)
            await profileVM.refreshLevelUniqueSolutionCounts(force: true)
            await profileVM.refreshLeaderboard()
            return inserted
        } catch {
            await MainActor.run {
                graphVM.uniqueSolutionUnlocked = false
            }
            print("Failed to record unique solution:", error.localizedDescription)
            return false
        }
    }

    private func hackerPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(maxWidth: .infinity, alignment: .leading)
            .terminalCard()
    }

    private func runPipeline() {
        guard !isPipelineFrozen, !isRunInFlight else { return }
        isRunInFlight = true
        let fallbackHash = graphVM.solutionHash ?? graphVM.pipelineRepresentation()?.hash ?? UUID().uuidString
        let nodesCount = graphVM.nodes.count
        Task {
            let allowed = await profileVM.chargeRunAttempt(
                levelId: level.id,
                nodes: nodesCount,
                pipelineHash: fallbackHash,
                lastPipelineHash: nil,
                levelTier: "medium"
            )
            await MainActor.run {
                isRunInFlight = false
                if allowed {
                    completePipelineAttempt()
                } else {
                    showOutOfTokensAlert = true
                }
            }
        }
    }

    private func completePipelineAttempt() {
        let previousAttemptCount = attemptCount
        attemptCount += 1
        let success = graphVM.run()
        defer {
            refreshPaletteAfterRunResult()
        }
        let thinkingUnits = max(1, graphVM.nodes.count) * max(1, attemptCount)
        let resultValue = graphVM.result ?? level.inputValue
        profileVM.recordAttempt(for: level, thinkingUnits: thinkingUnits, resultValue: resultValue, success: success)
        updateNodeLockState()
        nftStatusMessage = nil
        if success {
            guard let hash = graphVM.solutionHash else {
                penaltyMessage = "Пайплайн странный — попробуй собрать его заново."
                attemptCount = previousAttemptCount
                resumePipelineState()
                return
            }
            profileVM.recordSolution(level: level, hash: hash)
            graphVM.uniqueSolutionUnlocked = false
            isPalettePaused = true
            isPaletteCollapsed = true
            isPipelineFrozen = true
            Task {
                let inserted = await submitPipelineAnalytics()
                await MainActor.run {
                    if inserted {
                        freezePipelineState()
                        isPalettePaused = true
                        isPaletteCollapsed = true
                        updateAchievementProgress()
                        let result = profileVM.markLevelCompleted(level, isUnique: true)
                        completionBreakdown = result.breakdown
                        lastBonus = result.bonus
                        showSuccess = true
                        penaltyMessage = nil
                    } else {
                        attemptCount = previousAttemptCount
                        resumePipelineState()
                    }
                }
            }
        } else {
            graphVM.uniqueSolutionUnlocked = false
            resumePipelineState()
            profileVM.addHistoryEntry(for: level, entry: "Промах. Результат \(graphVM.result ?? 0).")
            penaltyMessage = "Попытка учтена."
        }
    }

    private func updateAchievementProgress() {
        let count = profileVM.profile.triedSolutionHashes[level.id]?.count ?? 0
        switch count {
        case 3:
            achievementMessage = "Ачивка! 3 уникальных решения — ты в теме."
        case 10:
            achievementMessage = "Мегаочивка! 10 вариаций SHA-магии."
        case 100:
            achievementMessage = "Легенда! 100 решений — конвейеры преклоняются."
        default:
            break
        }
    }

    private var nextLevel: Level? {
        if profileVM.currentLevel != nil {
            return profileVM.nextLevel(after: level)
        }
        if let dailyLevels, let dailyIndex {
            let nextIndex = dailyIndex + 1
            guard nextIndex < dailyLevels.count else { return nil }
            return dailyLevels[nextIndex]
        }
        return profileVM.nextLevel(after: level)
    }

    private func currentLeaderboardPosition() -> Int? {
        guard let username = profileVM.remoteProfile?.username else { return nil }
        return profileVM.leaderboardEntries.firstIndex(where: { $0.username == username }).map { $0 + 1 }
    }

    private func requestHint() {
        Task {
            let ok = await profileVM.consumeCredits(amount: 10, source: "hint")
            await MainActor.run {
                if ok {
                    hintUsageCount += 1
                    hintText = hintMessage(for: hintUsageCount)
                    showHintAlert = true
                } else {
                    showOutOfTokensAlert = true
                }
            }
        }
    }

    private func hintMessage(for usage: Int) -> String {
        let stage = (usage - 1) % 3
        switch stage {
        case 0:
            return maskHint()
        case 1:
            return shiftHint()
        default:
            return inputHint()
        }
    }

    private func maskHint() -> String {
        let hintMask = level.targetValue ^ level.inputValue
        return """
        📡 SHA-Ассистент:
        Эй, оператор! Попробуй применить XOR с маской \(hintMask).
        Это будто выключить лишние лампочки — результат станет ближе к цели.
        """
    }

    private func shiftHint() -> String {
        let shift = bestShiftCandidate()
        return """
        📡 SHA-Ассистент:
        Вижу, что сдвиг на \(shift) бит даёт красивую траекторию.
        Представь, что подталкиваешь число на конвейере — дай ему этот импульс.
        """
    }

    private func inputSuggestion() -> UInt32 {
        let mask = level.targetValue ^ level.inputValue
        if mask != 0 {
            return level.targetValue ^ mask
        }
        return level.targetValue
    }

    private func inputHint() -> String {
        let suggestion = inputSuggestion()
        return """
        📡 SHA-Ассистент:
        Давай начнём с \(suggestion). Я отлаживал подобные цепочки для видеокарт — trust me.
        Введи это число, и смотри на Trace: дальше будем как дуэт диджеев.
        """
    }

    private func bestShiftCandidate() -> Int {
        let input = graphVM.result ?? level.inputValue
        let target = level.targetValue
        var bestShift = 0
        var bestDiff = UInt64.max
        for shift in 0...12 {
            let shifted = UInt64((input << shift) & 0xFFFF_FFFF)
            let diff = shifted > UInt64(target) ? shifted - UInt64(target) : UInt64(target) - shifted
            if diff < bestDiff {
                bestDiff = diff
                bestShift = shift
            }
        }
        return bestShift
    }

    private func removeNode(_ binding: Binding<HashNode>) {
        guard !profileVM.profile.hardcoreMode else { return }
        let id = binding.wrappedValue.id
        if let index = graphVM.nodes.firstIndex(where: { $0.id == id }) {
            _ = withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                graphVM.nodes.remove(at: index)
            }
        }
    }

    private func updateNodeLockState() {
        let shouldLock = profileVM.profile.hardcoreMode || isPipelineFrozen
        graphVM.nodes = graphVM.nodes.map { node in
            var copy = node
            copy.isLocked = shouldLock
            return copy
        }
    }

    private func handleBackNavigation() {
        resumePipelineState()
        graphVM.reset(for: level)
        if profileVM.currentLevel != nil {
            profileVM.closeLevel()
            dismiss()
        } else {
            dismiss()
        }
    }

    private var backButtonTitle: String {
        originDifficulty?.displayName ?? "Назад"
    }

    private func toolbarButton(title: String, systemName: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemName {
                    Image(systemName: systemName)
                        .foregroundColor(HFTheme.Colors.accentSoft)
                }
                Text(title)
                    .terminalText(13, weight: .semibold)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(HFTheme.Colors.accent.opacity(0.8), lineWidth: 1)
            )
        }
    }

    @ViewBuilder
    private func nextLevelButton(for level: Level) -> some View {
        if profileVM.currentLevel != nil {
            Button {
                self.level = level
                profileVM.openLevel(level, originDifficulty: originDifficulty ?? level.difficulty)
            } label: {
                nextButtonContent
            }
            .buttonStyle(.plain)
        } else if let dailyLevels, let dailyIndex {
            Button {
                let nextIndex = dailyIndex + 1
                guard nextIndex < dailyLevels.count else { return }
                self.level = level
                onDailyAdvance?(nextIndex)
            } label: {
                nextButtonContent
            }
            .buttonStyle(.plain)
        } else {
            NavigationLink(
                destination: LevelPlayView(level: level, originDifficulty: originDifficulty)
                    .environmentObject(profileVM)
            ) {
                nextButtonContent
            }
            .buttonStyle(.plain)
        }
    }

    private var nextButtonContent: some View {
        HStack {
            Image(systemName: "arrow.forward.circle")
            Text("Следующий")
                .terminalText(14, weight: .semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, HFTheme.Spacing.m)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(HFTheme.Colors.accent.opacity(0.7), lineWidth: 1)
        )
    }

    private func resetDragIndicators() {
        draggedNode = nil
        dropGapIndex = nil
    }

    private func applyUITestPipeline() {
        graphVM.nodes = [
            HashNode(type: .shiftLeft, shiftBy: 2),
            HashNode(type: .xor, mask: 92)
        ]
        graphVM.result = nil
        graphVM.isSuccess = nil
        graphVM.uniqueSolutionUnlocked = false
        isPipelineFrozen = false
        isPalettePaused = false
        showSuccess = false
    }

    private func resetCurrentLevelState() {
        graphVM.reset(for: level)
        attemptCount = 0
        penaltyMessage = nil
        showSuccess = false
        preparePaletteForCurrentState()
        isPalettePaused = false
        paletteCountdown = paletteRefreshInterval
        graphVM.showPrefilled = true
        isPaletteCollapsed = false
        isPipelineFrozen = false
    }

    private func freezePipelineState() {
        guard !isPipelineFrozen else { return }
        isPipelineFrozen = true
        isPalettePaused = true
        updateNodeLockState()
    }

    private func resumePipelineState() {
        isPipelineFrozen = false
        isPalettePaused = false
        paletteCountdown = paletteRefreshInterval
        updateNodeLockState()
    }
}

private struct NodeDropDelegate: DropDelegate {
    let targetNode: HashNode
    @Binding var draggedNode: HashNode?
    let moveAction: (HashNode, HashNode) -> Void
    let onDropCompleted: () -> Void

    func dropEntered(info: DropInfo) {
        guard let dragged = draggedNode, dragged != targetNode else { return }
        moveAction(dragged, targetNode)
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedNode = nil
        onDropCompleted()
        return true
    }

    func dropExited(info: DropInfo) {
    }
}

private struct NodeGapDropDelegate: DropDelegate {
    let targetIndex: Int
    @Binding var draggedNode: HashNode?
    @Binding var dropGapIndex: Int?
    let moveAction: (HashNode, Int) -> Void
    let onDropCompleted: () -> Void

    func dropEntered(info: DropInfo) {
        dropGapIndex = targetIndex
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        defer {
            dropGapIndex = nil
            draggedNode = nil
        }
        guard let node = draggedNode else { return false }
        moveAction(node, targetIndex)
        onDropCompleted()
        return true
    }

    func dropExited(info: DropInfo) {
        dropGapIndex = nil
    }
}


private struct NodePaletteOption: Identifiable, Equatable {
    enum Action: Equatable {
        case xor(mask: UInt32)
        case shift(bits: Int)
    }

    let id = UUID()
    let action: Action
    let label: String
    let isWinning: Bool

    var icon: String {
        switch action {
        case .xor: return "⊕"
        case .shift: return "⇡"
        }
    }

    var valueDescription: String {
        switch action {
        case .xor(let mask):
            return "\(mask)"
        case .shift(let bits):
            return "+\(bits) бит"
        }
    }

    func makeNode() -> HashNode {
        switch action {
        case .xor(let mask):
            return HashNode(type: .xor, mask: mask)
        case .shift(let bits):
            return HashNode(type: .shiftLeft, shiftBy: bits)
        }
    }
}

#Preview {
    LevelPlayView(level: .constant(Level.all.first!))
        .environmentObject(GameProfileViewModel())
}

struct LevelVictoryStats {
    let totalRespect: Int
    let uniqueSolutions: Int
    let leaderboardRank: Int?
}

struct SuccessOverlay: View {
    let respectGain: Int
    let rank: String
    let breakdown: [String]
    let isUnique: Bool
    let stats: LevelVictoryStats
    let onDismiss: () -> Void
    let onShowLeaderboard: () -> Void
    @State private var animateHighlight = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
            VStack(spacing: HFTheme.Spacing.m) {
                Text(isUnique ? "Уникальное решение!" : "HASH STABLE SIGNAL")
                    .terminalText(18, weight: .bold)
                    .scaleEffect(isUnique && animateHighlight ? 1.08 : 1.0)
                    .animation(.spring(response: 0.4, dampingFraction: 0.55), value: animateHighlight)
                Text("Респект +\(respectGain)")
                    .terminalText(16, weight: .semibold)
                Text("Текущий ранг: \(rank)")
                    .terminalText(14)
                    .foregroundColor(HFTheme.Colors.accentDim)
                Text(isUnique ? "Уникальное решение! 🚀" : "Обычное прохождение")
                    .terminalText(14, weight: .semibold)
                    .foregroundColor(isUnique ? HFTheme.Colors.accent : HFTheme.Colors.accentDim)
                    .frame(maxWidth: .infinity, alignment: .leading)
                ForEach(breakdown, id: \.self) { line in
                    Text(line)
                        .terminalText(13)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Сводка")
                        .terminalText(15, weight: .semibold)
                    Text("Всего респекта: \(stats.totalRespect)")
                        .terminalText(13)
                    Text("Уникальных решений: \(stats.uniqueSolutions)")
                        .terminalText(13)
                    if let position = stats.leaderboardRank {
                        Text("Место в таблице: \(position)")
                            .terminalText(13)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: HFTheme.Spacing.m) {
                    Button("Таблица лидеров") {
                        onShowLeaderboard()
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(HFTheme.Colors.bgPanelSoft)
                    .foregroundColor(HFTheme.Colors.accentSoft)
                    .cornerRadius(16)

                    Button("Продолжить") {
                        onDismiss()
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(HFTheme.Colors.accent)
                    .foregroundColor(.black)
                    .cornerRadius(16)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(HFTheme.Colors.bgPanel)
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(HFTheme.Colors.accent.opacity(0.5), lineWidth: 1)
                    )
            )
            .padding()
            .onAppear {
                if isUnique {
                    animateHighlight = true
                }
            }
        }
    }
}
