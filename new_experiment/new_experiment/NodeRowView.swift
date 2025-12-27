import SwiftUI

struct NodeRowView: View {
    @Binding var node: HashNode
    var baseValue: UInt32 = 0
    var isHardcore: Bool = false
    var isEasyDifficulty: Bool = true
    var onDelete: (() -> Void)?

    @State private var maskInput: String
    @State private var shiftInput: String
    @State private var showMaskPreview = false
    @State private var showShiftPreview = false
    @FocusState private var focusedField: InputField?

    private enum InputField: Hashable {
        case mask
        case shift
    }

    init(node: Binding<HashNode>, baseValue: UInt32 = 0, isHardcore: Bool = false, isEasyDifficulty: Bool = true, onDelete: (() -> Void)? = nil) {
        self._node = node
        self.isHardcore = isHardcore
        self.baseValue = baseValue
        self.isEasyDifficulty = isEasyDifficulty
        self.onDelete = onDelete
        _maskInput = State(initialValue: String(node.wrappedValue.mask))
        _shiftInput = State(initialValue: String(node.wrappedValue.shiftBy))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HFTheme.Spacing.m) {
            HStack(spacing: HFTheme.Spacing.m) {
                Text(node.type == .xor ? "XOR NODE" : "SHIFT NODE")
                    .terminalText(15, weight: .semibold)
                Spacer()
                if isHardcore && node.isLocked {
                    Image(systemName: "lock.fill")
                        .foregroundColor(HFTheme.Colors.accentDim)
                } else if let onDelete, !isHardcore {
                    Button {
                        onDelete()
                        HackerHaptics.light()
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(HFTheme.Colors.accentSoft)
                }
            }

            switch node.type {
            case .xor:
                if isHardcore && node.isLocked {
                    Text("MASK: \(node.mask)")
                        .terminalText(14)
                        .foregroundColor(HFTheme.Colors.accentDim)
                } else {
                    VStack(alignment: .leading, spacing: HFTheme.Spacing.s) {
                        terminalField(title: "Mask", text: $maskInput)
                            .onChange(of: maskInput) { newValue in
                                updateMask(from: newValue)
                                showMaskPreview = !newValue.isEmpty
                            }
                            .focused($focusedField, equals: .mask)
                            .onTapGesture {
                                showMaskPreview = true
                                focusedField = .mask
                            }
                        if showMaskPreview {
                            MaskPreviewView(
                                input: baseValue,
                                maskText: maskInput,
                                showResult: isEasyDifficulty && !isHardcore
                            )
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
            case .shiftLeft:
                if isHardcore && node.isLocked {
                    Text("SHIFT: \(node.shiftBy)")
                        .terminalText(14)
                        .foregroundColor(HFTheme.Colors.accentDim)
                } else {
                    VStack(alignment: .leading, spacing: HFTheme.Spacing.s) {
                        terminalField(title: "Shift", text: $shiftInput)
                            .onChange(of: shiftInput) { newValue in
                                updateShift(from: newValue)
                                showShiftPreview = !newValue.isEmpty
                            }
                            .focused($focusedField, equals: .shift)
                            .onTapGesture {
                                showShiftPreview = true
                                focusedField = .shift
                            }
                        if showShiftPreview {
                            ShiftPreviewView(
                                input: baseValue,
                                shiftText: shiftInput,
                                showResult: isEasyDifficulty && !isHardcore
                            )
                            .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
            }
        }
        .terminalCard()
        .foregroundColor(HFTheme.Colors.accentSoft)
        .dynamicTypeSize(.medium ... .accessibility5)
        .onAppear {
            maskInput = String(node.mask)
            shiftInput = String(node.shiftBy)
        }
        .onChange(of: node.mask) { newValue in
            maskInput = String(newValue)
        }
        .onChange(of: node.shiftBy) { newValue in
            shiftInput = String(newValue)
        }
    }

    private func terminalField(title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: HFTheme.Spacing.xs) {
            Text(title.uppercased())
                .terminalText(12)
                .foregroundColor(HFTheme.Colors.accentDim)
            TextField("0", text: Binding(
                get: { text.wrappedValue },
                set: { newValue in
                    text.wrappedValue = newValue.filter { $0.isNumber }
                }
            ))
            .keyboardType(.numberPad)
            .foregroundColor(HFTheme.Colors.accentSoft)
            .padding(.horizontal, HFTheme.Spacing.m)
            .padding(.vertical, HFTheme.Spacing.s)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(HFTheme.Colors.accent.opacity(0.4), lineWidth: 1)
            )
            .onDrop(of: [.text], isTargeted: nil) { _ in false }
        }
    }

    private func updateMask(from text: String) {
        guard let value = UInt32(text) else { return }
        node.mask = value
    }

    private func updateShift(from text: String) {
        guard let value = Int(text) else { return }
        node.shiftBy = max(0, min(31, value))
    }
}
 
struct MaskPreviewView: View {
    let input: UInt32
    let maskText: String
    let showResult: Bool

    private var maskValue: UInt32? {
        UInt32(maskText)
    }

    private var xorResult: UInt32? {
        guard let maskValue else { return nil }
        return input ^ maskValue
    }
    private var width: Int {
        let inputWidth = String(input, radix: 2).count
        let maskWidth = maskValue.map { String($0, radix: 2).count } ?? 1
        let resultWidth = xorResult.map { String($0, radix: 2).count } ?? 1
        return max(8, max(inputWidth, max(maskWidth, resultWidth)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: HFTheme.Spacing.s) {
            Text("XOR превью")
                .terminalText(13, weight: .semibold)
            bitRow(title: "INPUT", bits: inputBits)
            bitRow(title: "MASK", bits: maskBits, highlightMask: maskHighlights)
            if showResult, let resultBits {
                bitRow(title: "RESULT", bits: resultBits, highlightMask: resultHighlights)
                if let result = xorResult {
                    Text("Новое значение: \(result)")
                        .terminalText(13, weight: .semibold)
                    if !changedPositions.isEmpty {
                        Text("Изменены биты: \(changedPositions)")
                            .terminalText(11)
                            .foregroundColor(HFTheme.Colors.accentDim)
                    }
                }
            }
        }
        .padding(.horizontal, HFTheme.Spacing.m)
        .padding(.vertical, HFTheme.Spacing.s)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .stroke(HFTheme.Colors.accent.opacity(0.35), lineWidth: 1)
        )
    }

    private var inputBits: [Character] {
        binaryString(for: input)
    }

    private var maskBits: [Character] {
        binaryString(for: maskValue ?? 0)
    }

    private var resultBits: [Character]? {
        guard let xorResult else { return nil }
        return binaryString(for: xorResult)
    }

    private var maskHighlights: [Bool]? {
        guard maskValue != nil else { return nil }
        return maskBits.map { $0 == "1" }
    }

    private var resultHighlights: [Bool]? {
        guard let resultBits else { return nil }
        return zip(inputBits, resultBits).map { $0 != $1 }
    }

    private var changedPositions: String {
        guard let highlights = resultHighlights else { return "—" }
        let indexes = highlights.enumerated().compactMap { index, value in
            value ? String(index) : nil
        }
        return indexes.isEmpty ? "—" : indexes.joined(separator: ", ")
    }

    private func bitRow(title: String, bits: [Character], highlightMask: [Bool]? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .terminalText(10)
                .foregroundColor(HFTheme.Colors.accentDim)
            HStack(spacing: 4) {
                ForEach(Array(bits.enumerated()), id: \.offset) { index, bit in
                    Text(String(bit))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(highlightMask?[index] == true ? HFTheme.Colors.accent : HFTheme.Colors.accentSoft)
                        .padding(4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(highlightMask?[index] == true ? HFTheme.Colors.accent.opacity(0.12) : HFTheme.Colors.bgPanel)
                        )
                }
            }
        }
    }

    private func binaryString(for value: UInt32) -> [Character] {
        String(value, radix: 2).padStart(to: width).map { $0 }
    }
}

struct ShiftPreviewView: View {
    let input: UInt32
    let shiftText: String
    let showResult: Bool

    private var shiftValue: Int? {
        guard let value = Int(shiftText), (0...31).contains(value) else { return nil }
        return value
    }

    private var shiftedValue: UInt32? {
        guard let shiftValue else { return nil }
        return UInt32((UInt64(input) << UInt64(shiftValue)) & 0xFFFF_FFFF)
    }

    private var width: Int { 16 }

    var body: some View {
        VStack(alignment: .leading, spacing: HFTheme.Spacing.s) {
            Text("Shift превью")
                .terminalText(13, weight: .semibold)
            bitRow(title: "INPUT", bits: bits(for: input))
            if let shiftValue {
                Text("Сдвиг: \(shiftValue) бит")
                    .terminalText(11)
                    .foregroundColor(HFTheme.Colors.accentDim)
            }
            if showResult, let result = shiftedValue {
                bitRow(title: "RESULT", bits: bits(for: result), highlightMask: shiftHighlights(result: result))
                Text("Новое значение: \(result)")
                    .terminalText(13, weight: .semibold)
            }
        }
        .padding(.horizontal, HFTheme.Spacing.m)
        .padding(.vertical, HFTheme.Spacing.s)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .stroke(HFTheme.Colors.accent.opacity(0.35), lineWidth: 1)
        )
    }

    private func bits(for value: UInt32) -> [Character] {
        String(value, radix: 2).padStart(to: width).map { $0 }
    }

    private func shiftHighlights(result: UInt32) -> [Bool] {
        let original = bits(for: input)
        let newBits = bits(for: result)
        return zip(original, newBits).map { $0 != $1 }
    }

    private func bitRow(title: String, bits: [Character], highlightMask: [Bool]? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .terminalText(10)
                .foregroundColor(HFTheme.Colors.accentDim)
            HStack(spacing: 4) {
                ForEach(Array(bits.enumerated()), id: \.offset) { index, bit in
                    Text(String(bit))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundColor(highlightMask?[index] == true ? HFTheme.Colors.accent : HFTheme.Colors.accentSoft)
                        .padding(4)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(highlightMask?[index] == true ? HFTheme.Colors.accent.opacity(0.12) : HFTheme.Colors.bgPanel)
                        )
                }
            }
        }
    }
}

private extension String {
    func padStart(to length: Int) -> String {
        guard count < length else { return self }
        return String(repeating: "0", count: length - count) + self
    }
}
