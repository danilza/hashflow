import Foundation
import CryptoKit

final class HashGraphViewModel: ObservableObject {
    @Published var inputValue: UInt32
    @Published var targetValue: UInt32?
    @Published var nodes: [HashNode] = []
    @Published var result: UInt32?
    @Published var trace: [String] = []
    @Published var isSuccess: Bool?
    @Published var solutionHash: String?
    @Published var uniqueSolutionUnlocked: Bool = false
    @Published var showPrefilled: Bool = true

    init(inputValue: UInt32, targetValue: UInt32?) {
        self.inputValue = inputValue
        self.targetValue = targetValue
    }

      func addXorNode(defaultMask: UInt32 = 0xFF) {
          nodes.append(.xorNode(defaultMask: defaultMask))
      }

      func addShiftLeftNode(defaultShift: Int = 1) {
          nodes.append(.shiftNode(defaultShift: defaultShift))
      }

      func moveNodes(from source: IndexSet, to destination: Int) {
          nodes.move(fromOffsets: source, toOffset: destination)
      }

      func moveNode(dragged: HashNode, to target: HashNode) {
          guard let fromIndex = nodes.firstIndex(where: { $0.id == dragged.id }),
                let targetIndex = nodes.firstIndex(where: { $0.id == target.id }),
                fromIndex != targetIndex else { return }

          let destination = targetIndex > fromIndex ? targetIndex + 1 : targetIndex
          nodes.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: destination)
      }

      func moveNode(_ node: HashNode, to index: Int) {
          guard let fromIndex = nodes.firstIndex(where: { $0.id == node.id }) else { return }
          var destination = index
          if fromIndex < destination {
              destination -= 1
          }
          destination = max(0, min(nodes.count, destination))
          nodes.move(fromOffsets: IndexSet(integer: fromIndex), toOffset: destination)
      }

      @discardableResult
      func run() -> Bool {
          var current = inputValue
          var newTrace: [String] = []
          newTrace.append("Input: \(current)")
          solutionHash = generateSolutionHash()

          for node in nodes {
              switch node.type {
              case .xor:
                  let before = current
                  current = before ^ node.mask
                  newTrace.append("XOR(mask: \(node.mask)): \(before) ^ \(node.mask) = \(current)")
              case .shiftLeft:
                  let clamped = max(0, min(31, node.shiftBy))
                  let before = current
                  current = (before << clamped) & 0xFFFF_FFFF
                  newTrace.append("ShiftLeft(by: \(clamped)): \(before) << \(clamped) = \(current)")
              }
          }

          result = current
          if let target = targetValue {
              let success = current == target
              isSuccess = success
              newTrace.append(success ? "🎯 Цель достигнута!" : "Цель: \(target), результат: \(current)")
              trace = newTrace
              return success
          } else {
              isSuccess = nil
              trace = newTrace
              return false
          }
      }

    func reset(for level: Level) {
        inputValue = level.inputValue
        targetValue = level.targetValue
        nodes.removeAll()
        result = nil
        trace.removeAll()
        isSuccess = nil
        solutionHash = nil
        uniqueSolutionUnlocked = false
        showPrefilled = true
    }
}

extension HashGraphViewModel {
    func generateSolutionHash() -> String {
        let signature = nodes.map { "\($0.type.rawValue):\($0.mask):\($0.shiftBy)" }.joined(separator: "|")
        let data = Data(signature.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

struct PipelineRepresentation {
    let rawJSON: String
    let hash: String
    let length: Int
}

extension HashGraphViewModel {
    private struct PipelineOperationPayload: Codable {
        let op: String
        let value: UInt32
    }

    private struct PipelinePayload: Codable {
        let operations: [PipelineOperationPayload]
    }

    func pipelineRepresentation() -> PipelineRepresentation? {
        let operations = pipelineOperations()
        guard !operations.isEmpty else { return nil }
        let payload = PipelinePayload(operations: operations)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(payload),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }
        let digest = SHA256.hash(data: data)
        let hash = digest.map { String(format: "%02x", $0) }.joined()
        return PipelineRepresentation(rawJSON: json, hash: hash, length: operations.count)
    }

    private func pipelineOperations() -> [PipelineOperationPayload] {
        nodes.map { node in
            switch node.type {
            case .xor:
                return PipelineOperationPayload(op: "xor", value: node.mask)
            case .shiftLeft:
                return PipelineOperationPayload(op: "shift_left", value: UInt32(max(0, node.shiftBy)))
            }
        }
    }
}
