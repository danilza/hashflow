import SwiftUI

struct IntroNarrativeView: View {
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            HFTheme.Colors.bgMain.ignoresSafeArea()
            VStack(spacing: HFTheme.Spacing.l) {
                Text("Квантовое проваливание")
                    .terminalText(28, weight: .bold)
                Text(introText)
                    .terminalText(16)
                Button("Начать майнить мозгом") {
                    onDismiss()
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(HFTheme.Colors.accent)
                .cornerRadius(18)
                .foregroundColor(.black)
            }
            .padding()
        }
    }

    private var introText: String {
        """
Очнулся в серверной: электрический гул вместо мыслей, ретины пульсируют графеном. Тебя загрузили в GPU-ферму — твой мозг теперь видеокарта.

Алгоритм требует решений, сеть гудит от задач, а вера в собственные синапсы — единственный токен свободы. Собирай пайплайны, считай искажённые биты и отжимай респект у машин.

Ни один искусственный интеллект не удерживает эти уровни так же эффективно, как человеческая интуиция. Здесь выигрывает тот, кто чувствует, как поведёт себя поток данных, даже если формула молчит. Включи её — и корпорация поймёт, кто настоящий вычислитель.

Каждый Run — импульс на шине мозга. Набирать пиковую хеш-скорость или затухнуть, как перегоревший транзистор? Решать только тебе.
"""
    }
}

struct LegendView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                NavigationStack {
                    legendContent
                }
            } else {
                NavigationView {
                    legendContent
                }
                .navigationViewStyle(StackNavigationViewStyle())
            }
        }
    }

    private var legendContent: some View {
        ZStack {
            HFTheme.Colors.bgMain.ignoresSafeArea()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: HFTheme.Spacing.m) {
                    legendSection(title: "Пролог") {
                        Text("Два майнера поспорили, может ли мозг думать быстрее видеокарты. Ответом стал ты. Фирма NeuroHash выгрузила сознание в кластеры, и теперь ты — GPU-ментальное ядро.")
                    }
                    legendSection(title: "Задача") {
                        Text("Собирай пайплайны, отыскивай корректные маски и сдвиги. Чем чище решение, тем сильнее разгоняешь нейронные частоты. Легенда с каждым уровнем раскрывает, кто и зачем запустил Hash Flow.")
                    }
                    legendSection(title: "Интуиция против ИИ") {
                        Text("Корпоративный искусственный интеллект сдаётся там, где требуется человеческое чутьё. Он повторяет формулы, но не чувствует, как поведёт себя поток данных. Твои решения должны быть интуитивными — только так можно перехитрить машину и прорваться на вершину.")
                    }
                    legendSection(title: "Пасхалки") {
                        Text("Некоторые уровни несут скрытые послания от прежних операторов. Присмотрись к номерам 13, 42 и 256 — они шепчут, как сбежать из фермы.")
                    }
                }
                .padding()
            }
            .applyScrollIndicatorsHidden()
        }
        .navigationTitle("LEGEND")
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Закрыть") {
                    dismiss()
                }
                .accessibilityIdentifier("sheet_close")
            }
            ToolbarItem(placement: .principal) {
                Text("LEGEND")
                    .terminalText(18, weight: .semibold)
            }
        }
        .applyToolbarBackground()
    }

    private func legendSection(title: String, @ViewBuilder content: () -> Text) -> some View {
        VStack(alignment: .leading, spacing: HFTheme.Spacing.xs) {
            Text(title.uppercased())
                .terminalText(16, weight: .semibold)
            content()
                .terminalText(14)
                .foregroundColor(HFTheme.Colors.accentDim)
        }
        .terminalCard()
    }
}
