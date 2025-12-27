import SwiftUI
import UniformTypeIdentifiers

struct PipelineSectionView: View {
    @ObservedObject var graphVM: HashGraphViewModel
    let level: Level
    let isHardcore: Bool
    let isEasyDifficulty: Bool
    let canReorderNodes: Bool
    let pipelineAnchor: String
    @Binding var dropGapIndex: Int?
    @Binding var draggedNode: HashNode?
    let removeNode: (Binding<HashNode>) -> Void
    let addXorAction: () -> Void
    let addShiftAction: () -> Void

    var body: some View {
        LazyVStack(alignment: .leading, spacing: HFTheme.Spacing.m, pinnedViews: [.sectionHeaders]) {
            Section(header: pipelineStickyHeader) {
                VStack(alignment: .leading, spacing: HFTheme.Spacing.m) {
                    ForEach(Array(graphVM.nodes.enumerated()), id: \.element.id) { index, node in
                        if canReorderNodes {
                            dropGapView(targetIndex: index)
                        }
                        let nodeBinding = $graphVM.nodes[index]
                        let baseView = NodeRowView(
                            node: nodeBinding,
                            baseValue: graphVM.inputValue,
                            isHardcore: isHardcore,
                            isEasyDifficulty: isEasyDifficulty,
                            onDelete: {
                                removeNode(nodeBinding)
                            }
                        )
                        reorderableNodeView(baseView: baseView, node: nodeBinding.wrappedValue)
                            .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity),
                                                    removal: .scale.combined(with: .opacity)))
                    }
                    if canReorderNodes {
                        dropGapView(targetIndex: graphVM.nodes.count)
                    }
                    Color.clear.frame(height: 1).id(pipelineAnchor)
                }
            }
        }
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
                pipelineControlButton(icon: "x.square", title: "Add XOR", action: addXorAction)
                pipelineControlButton(icon: "arrow.left.and.right", title: "Add Shift", action: addShiftAction)
            }
        }
        .padding(.horizontal, HFTheme.Spacing.m)
        .padding(.vertical, HFTheme.Spacing.s)
        .background(HFTheme.Colors.bgPanelSoft.opacity(0.95))
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

    private func pipelineControlButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(HFTheme.Colors.accentSoft)
                Text(title.uppercased())
                    .terminalText(12, weight: .semibold)
                    .foregroundColor(HFTheme.Colors.accentSoft)
            }
            .padding(.horizontal, HFTheme.Spacing.m)
            .padding(.vertical, HFTheme.Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(HFTheme.Colors.accent.opacity(0.6), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func reorderableNodeView<V: View>(baseView: V, node: HashNode) -> some View {
        return Group {
            if canReorderNodes {
                baseView
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(HFTheme.Colors.accent.opacity(draggedNode?.id == node.id ? 0.9 : 0.3), lineWidth: draggedNode?.id == node.id ? 2 : 1)
                    )
                    .onDrag {
                        draggedNode = node
                        return NSItemProvider(object: node.id.uuidString as NSString)
                    }
                    .onDrop(
                        of: [UTType.text],
                        delegate: NodeDropDelegate(
                            targetNode: node,
                            draggedNode: $draggedNode,
                            moveAction: { dragged, target in
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                                    graphVM.moveNode(dragged: dragged, to: target)
                                }
                            },
                            onDropCompleted: resetDragIndicators
                        )
                    )
            } else {
                baseView
            }
        }
    }

    @ViewBuilder
    private func dropGapView(targetIndex: Int) -> some View {
        let isActive = dropGapIndex == targetIndex
        RoundedRectangle(cornerRadius: 8)
            .strokeBorder(HFTheme.Colors.accent.opacity(isActive ? 0.9 : 0.3), style: StrokeStyle(lineWidth: isActive ? 3 : 1.5, dash: [6, 6]))
            .frame(height: draggedNode == nil ? 0 : (isActive ? 18 : 12))
            .opacity(draggedNode == nil ? 0 : 1)
            .allowsHitTesting(draggedNode != nil)
            .animation(.easeInOut(duration: 0.12), value: dropGapIndex == targetIndex)
            .onDrop(of: [UTType.text], delegate: NodeGapDropDelegate(
                targetIndex: targetIndex,
                draggedNode: $draggedNode,
                dropGapIndex: $dropGapIndex,
                moveAction: { node, index in
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                        graphVM.moveNode(node, to: index)
                    }
                },
                onDropCompleted: resetDragIndicators
            ))
            .padding(.vertical, draggedNode == nil ? 0 : 2)
    }

    private func resetDragIndicators() {
        draggedNode = nil
        dropGapIndex = nil
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
