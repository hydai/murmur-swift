import Testing
@testable import MurmurKit

@Suite("AudioChunker")
struct AudioChunkerTests {
    @Test("WAV encoding produces valid RIFF header")
    func wavHeader() {
        let samples: [Int16] = [0, 100, -100, 32767, -32768]
        let wav = AudioChunker.encodeWAV(samples: samples)

        // Check RIFF header
        let riff = String(data: wav[0..<4], encoding: .ascii)
        #expect(riff == "RIFF")

        // Check WAVE format
        let wave = String(data: wav[8..<12], encoding: .ascii)
        #expect(wave == "WAVE")

        // Check fmt chunk
        let fmt = String(data: wav[12..<16], encoding: .ascii)
        #expect(fmt == "fmt ")

        // Check data chunk
        let data = String(data: wav[36..<40], encoding: .ascii)
        #expect(data == "data")

        // Data size = 5 samples * 2 bytes = 10
        let dataSize = wav[40..<44].withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
        #expect(dataSize == 10)

        // Total file size: 44 header + 10 data = 54
        #expect(wav.count == 54)
    }

    @Test("Empty samples produce valid WAV")
    func emptyWav() {
        let wav = AudioChunker.encodeWAV(samples: [])
        #expect(wav.count == 44) // Header only
    }
}
