import Foundation

/// Encodes Int16 PCM samples as WAV data for REST STT APIs.
public struct AudioChunker: Sendable {
    public init() {}

    /// Encode Int16 PCM samples as a WAV file (16kHz, mono, 16-bit).
    public static func encodeWAV(samples: [Int16]) -> Data {
        let sampleRate: UInt32 = 16000
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8)
        let blockAlign = channels * (bitsPerSample / 8)
        let dataSize = UInt32(samples.count * 2)
        let fileSize = 36 + dataSize

        var data = Data()
        data.reserveCapacity(Int(fileSize + 8))

        // RIFF header
        data.append(contentsOf: "RIFF".utf8)
        data.append(littleEndian: fileSize)
        data.append(contentsOf: "WAVE".utf8)

        // fmt chunk
        data.append(contentsOf: "fmt ".utf8)
        data.append(littleEndian: UInt32(16))       // chunk size
        data.append(littleEndian: UInt16(1))        // PCM format
        data.append(littleEndian: channels)
        data.append(littleEndian: sampleRate)
        data.append(littleEndian: byteRate)
        data.append(littleEndian: blockAlign)
        data.append(littleEndian: bitsPerSample)

        // data chunk
        data.append(contentsOf: "data".utf8)
        data.append(littleEndian: dataSize)

        // Sample data
        samples.withUnsafeBufferPointer { buffer in
            buffer.baseAddress!.withMemoryRebound(to: UInt8.self, capacity: Int(dataSize)) { ptr in
                data.append(ptr, count: Int(dataSize))
            }
        }

        return data
    }
}

// MARK: - Data extension for little-endian writes

extension Data {
    mutating func append(littleEndian value: UInt16) {
        var v = value.littleEndian
        append(Data(bytes: &v, count: 2))
    }

    mutating func append(littleEndian value: UInt32) {
        var v = value.littleEndian
        append(Data(bytes: &v, count: 4))
    }
}
