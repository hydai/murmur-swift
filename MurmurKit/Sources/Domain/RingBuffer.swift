/// A fixed-size circular buffer that avoids O(N) array shifts on append.
/// Conforms to `RandomAccessCollection` for seamless integration with SwiftUI.
public struct RingBuffer<Element>: Sendable, RandomAccessCollection where Element: Sendable {
    private var buffer: [Element?]
    private var head: Int = 0
    private(set) public var count: Int = 0
    public let capacity: Int

    public init(capacity: Int) {
        precondition(capacity > 0)
        self.capacity = capacity
        self.buffer = [Element?](repeating: nil, count: capacity)
    }

    public mutating func append(_ element: Element) {
        buffer[head] = element
        head = (head + 1) % capacity
        if count < capacity {
            count += 1
        }
    }

    public mutating func clear() {
        head = 0
        count = 0
        for i in 0..<capacity {
            buffer[i] = nil
        }
    }

    // MARK: - Collection Conformance

    public var startIndex: Int { 0 }
    public var endIndex: Int { count }

    public subscript(position: Int) -> Element {
        precondition(position >= 0 && position < count, "Index out of bounds")
        let start = count < capacity ? 0 : head
        let index = (start + position) % capacity
        return buffer[index]!
    }
}
