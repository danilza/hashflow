import SwiftUI

private struct SwipeBackGestureModifier: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    let perform: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .leading) {
                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: 24)
                    .gesture(
                        DragGesture(minimumDistance: 20, coordinateSpace: .local)
                            .onEnded { value in
                                guard value.translation.width > 80,
                                      abs(value.translation.width) > abs(value.translation.height) else { return }
                                (perform ?? { dismiss() })()
                            }
                    )
            }
    }
}

extension View {
    func enableSwipeBack(perform: (() -> Void)? = nil) -> some View {
        modifier(SwipeBackGestureModifier(perform: perform))
    }
}
