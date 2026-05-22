import SwiftUI

/// Canvas-based real-time audio waveform visualization.
/// Displays a rolling series of bars driven by RMS audio levels.
struct WaveformIndicator<C: RandomAccessCollection>: View where C.Element == Float, C.Index == Int {
    let levels: C
    let voiceActive: Bool
    var barCount: Int = 40
    var barSpacing: CGFloat = 2

    var body: some View {
        Canvas { context, size in
            let barWidth = (size.width - CGFloat(barCount - 1) * barSpacing) / CGFloat(barCount)
            let midY = size.height / 2

            for i in 0..<barCount {
                let indexOffset = levels.count - barCount + i
                let rms: Float
                if indexOffset >= 0 && indexOffset < levels.count {
                    let index = levels.index(levels.startIndex, offsetBy: indexOffset)
                    rms = levels[index]
                } else {
                    rms = 0
                }

                // Scale RMS (0-1) to bar height, with minimum visible height
                let normalizedHeight = CGFloat(min(rms * 4, 1.0))
                let barHeight = max(2, normalizedHeight * size.height * 0.9)

                let x = CGFloat(i) * (barWidth + barSpacing)
                let rect = CGRect(
                    x: x,
                    y: midY - barHeight / 2,
                    width: barWidth,
                    height: barHeight
                )

                let color: Color = voiceActive ? .green : .gray.opacity(0.5)
                let opacity = 0.4 + normalizedHeight * 0.6

                context.fill(
                    Path(roundedRect: rect, cornerRadius: barWidth / 2),
                    with: .color(color.opacity(opacity))
                )
            }
        }
    }
}
