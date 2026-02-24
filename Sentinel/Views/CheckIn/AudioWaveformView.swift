import SwiftUI

/// Animated audio waveform visualization driven by current audio level.
///
/// Renders vertical bars that respond to microphone input level,
/// creating a real-time waveform effect for the tactical check-in UI.
struct AudioWaveformView: View {
    let audioLevel: Float
    let barCount: Int
    let accentColor: Color

    @State private var barHeights: [CGFloat] = []

    init(audioLevel: Float, barCount: Int = 24, accentColor: Color = Color(red: 0, green: 0.9, blue: 0.85)) {
        self.audioLevel = audioLevel
        self.barCount = barCount
        self.accentColor = accentColor
    }

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(accentColor)
                    .frame(width: 3, height: barHeight(for: index))
            }
        }
        .frame(height: 40)
        .onChange(of: audioLevel) { _, newLevel in
            updateBars(level: newLevel)
        }
        .onAppear {
            barHeights = Array(repeating: 4, count: barCount)
        }
    }

    private func barHeight(for index: Int) -> CGFloat {
        guard index < barHeights.count else { return 4 }
        return barHeights[index]
    }

    private func updateBars(level: Float) {
        // Normalize audio level from dB (-60 to 0) to 0...1
        let normalized = CGFloat(max(0, min(1, (level + 60) / 60)))

        // Shift existing bars left and add new one on the right
        var newHeights = barHeights
        if newHeights.count > 1 {
            newHeights.removeFirst()
        }

        // Add some natural variation
        let variation = CGFloat.random(in: 0.7...1.3)
        let newBar = max(4, normalized * 36 * variation)
        newHeights.append(newBar)

        withAnimation(.linear(duration: 0.05)) {
            barHeights = newHeights
        }
    }
}
