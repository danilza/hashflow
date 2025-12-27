import SwiftUI

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                NavigationStack {
                    helpContent
                }
            } else {
                NavigationView {
                    helpContent
                }
                .navigationViewStyle(StackNavigationViewStyle())
            }
        }
        .dynamicTypeSize(.medium ... .accessibility5)
    }

    private var helpContent: some View {
        ZStack {
            HFTheme.Colors.bgMain.ignoresSafeArea()
            MatrixRainView().opacity(0.18)
            ScrollView {
                VStack(alignment: .leading, spacing: HFTheme.Spacing.l) {
                    Text("Как играть")
                        .terminalText(22, weight: .bold)

                    hackerSection(title: "Что делает XOR") {
                        Text("""
XOR — исключающее ИЛИ. Меняет биты по маске.
10 ^ 3 = 9, потому что 1010 XOR 0011 даёт 1001.
""")
                    }

                    hackerSection(title: "Что делает ShiftLeft") {
                        Text("""
ShiftLeft сдвигает биты влево и добивает нулями.
5 (0101) << 2 → 20 (10100).
""")
                    }

                    hackerSection(title: "Trace") {
                        Text("""
Trace показывает каждую операцию цепочки.
Следи за ним, чтобы понимать, какой блок перенастроить.
""")
                    }

                    hackerSection(title: "Порядок узлов") {
                        Text("""
Можно перетаскивать узлы пайплайна (кроме режима хардкор).
Перетаскивание напрямую влияет на итоговый результат OUTPUT — попробуй менять последовательность и смотри, как меняется Trace.
""")
                    }

                    hackerSection(title: "Кредиты") {
                        Text("""
Кредиты получаются только за донат и тратятся на доп. ходы или минт. Без доната — только внутренняя гордость 😏
""")
                    }
                }
                .padding(HFTheme.Spacing.l)
            }
            .background(HFTheme.Colors.bgMain)
        }
        .navigationTitle("TERMINAL LOG")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Закрыть") {
                    dismiss()
                }
                .accessibilityIdentifier("sheet_close")
            }
            ToolbarItem(placement: .principal) {
                Text("TERMINAL LOG")
                    .terminalText(18, weight: .semibold)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .applyToolbarBackground()
    }

    private func hackerSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: HFTheme.Spacing.s) {
            Text(title.uppercased())
                .terminalText(18, weight: .bold)
            content()
                .terminalText(15)
                .foregroundColor(HFTheme.Colors.accentDim)
        }
        .terminalCard()
    }
}
