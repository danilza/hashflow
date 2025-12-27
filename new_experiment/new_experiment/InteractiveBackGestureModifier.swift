import SwiftUI

struct InteractiveBackGestureModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    let onBack: (() -> Void)?
    @State private var translation: CGFloat = 0
    @State private var isDragging = false

    func body(content: Content) -> some View {
        content
            .offset(x: translation)
            .shadow(color: Color.black.opacity(isDragging ? 0.15 : 0), radius: isDragging ? 8 : 0, x: 0, y: 2)
            .gesture(
                DragGesture(minimumDistance: 10, coordinateSpace: .local)
                    .onChanged { value in
                        guard value.translation.width > 0 else {
                            translation = 0
                            isDragging = false
                            return
                        }
                        isDragging = true
                        translation = min(value.translation.width, 140)
                    }
                    .onEnded { value in
                        let shouldDismiss = value.translation.width > 80 || value.predictedEndTranslation.width > 120
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.9)) {
                            if shouldDismiss {
                                translation = 240
                            } else {
                                translation = 0
                            }
                            isDragging = false
                        }
                        if shouldDismiss {
                            // defer to let animation complete slightly
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                if let onBack {
                                    onBack()
                                } else {
                                    dismiss()
                                }
                            }
                        }
                    }
            )
    }
}

extension View {
    func interactiveBackGesture(onBack: (() -> Void)? = nil) -> some View {
        modifier(InteractiveBackGestureModifier(onBack: onBack))
    }
}
