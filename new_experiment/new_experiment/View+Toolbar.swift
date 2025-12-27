import SwiftUI

extension View {
    @ViewBuilder
    func applyToolbarBackground() -> some View {
        if #available(iOS 16.0, *) {
            self
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarBackground(HFTheme.Colors.bgMain, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
        } else {
            self
        }
    }

    @ViewBuilder
    func scrollContentBackgroundHidden() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}

struct ToolbarNavButton: View {
    let title: String
    let systemName: String?
    let action: () -> Void

    var body: some View {
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
        .buttonStyle(.plain)
    }
}
