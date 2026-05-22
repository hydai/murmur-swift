import Testing
@testable import MurmurKit

@Suite("RingBuffer tests")
struct RingBufferTests {

    @Test("Append and sequence")
    func testAppendAndSequence() {
        var buffer = RingBuffer<Int>(capacity: 3)
        #expect(buffer.count == 0)
        
        buffer.append(1)
        #expect(buffer.count == 1)
        #expect(Array(buffer) == [1])
        
        buffer.append(2)
        buffer.append(3)
        #expect(buffer.count == 3)
        #expect(Array(buffer) == [1, 2, 3])
        
        // Wrap around
        buffer.append(4)
        #expect(buffer.count == 3)
        #expect(Array(buffer) == [2, 3, 4])
        
        buffer.append(5)
        #expect(Array(buffer) == [3, 4, 5])
    }
    
    @Test("Clear")
    func testClear() {
        var buffer = RingBuffer<Int>(capacity: 2)
        buffer.append(1)
        buffer.append(2)
        buffer.append(3)
        
        buffer.clear()
        #expect(buffer.count == 0)
        #expect(Array(buffer).isEmpty)
        
        buffer.append(4)
        #expect(buffer.count == 1)
        #expect(Array(buffer) == [4])
    }
}
