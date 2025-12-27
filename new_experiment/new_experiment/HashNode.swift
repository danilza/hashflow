import Foundation

enum HashNodeType: String, Codable, CaseIterable {
    case xor
    case shiftLeft
}

struct HashNode: Identifiable, Hashable, Codable {
    let id: UUID
    var type: HashNodeType
    var mask: UInt32
    var shiftBy: Int
    var isLocked: Bool

    init(id: UUID = UUID(), type: HashNodeType, mask: UInt32 = 0xFF, shiftBy: Int = 1, isLocked: Bool = false) {
        self.id = id
        self.type = type
        self.mask = mask
        self.shiftBy = shiftBy
        self.isLocked = isLocked
    }

    static func xorNode(defaultMask: UInt32 = 0xFF) -> HashNode {
        HashNode(type: .xor, mask: defaultMask)
    }

    static func shiftNode(defaultShift: Int = 1) -> HashNode {
        HashNode(type: .shiftLeft, shiftBy: defaultShift)
    }

}
