import SwiftUI

struct SentinelLoadingView: View {
    @Binding var isModelLoading: Bool
    @State private var activeStep = 0
    @State private var showFinalReady = false
    
    private enum Configuration {
        static let appName = "SENTINEL"
        static let subtitle = "OFFLINE | ON-DEVICE | PRIVATE"
        static let steps = [
            "ESTABLISHING SECURED PERIMETER",
            "VERIFYING ON-DEVICE INTEGRITY",
            "INITIALIZING MED-GEMMA ENGINE"
        ]
        static let finalStatus = "LOCAL ENCRYPTION ACTIVE"
        static let stepInterval: TimeInterval = 0.7
    }
    
    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            
            VStack(spacing: 48) {
                VStack(spacing: 12) {
                    Text(Configuration.appName)
                        .font(.system(size: 42, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.primary)
                        .shadow(color: Theme.primary.opacity(0.4), radius: 10)
                    
                    Text(Configuration.subtitle)
                        .font(.system(size: 10, weight: .bold))
                        .tracking(3)
                        .foregroundColor(Theme.primary.opacity(0.6))
                }
                
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(Configuration.steps.indices, id: \.self) { index in
                        HStack(spacing: 16) {
                            diagnosticIcon(for: index)
                            Text(Configuration.steps[index])
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundColor(activeStep >= index ? Theme.primary : .gray.opacity(0.3))
                        }
                    }
                    
                    if showFinalReady {
                        HStack(spacing: 16) {
                            Image(systemName: "lock.shield.fill")
                                .foregroundColor(Theme.primary)
                                .font(.system(size: 16))
                            Text(Configuration.finalStatus)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(Theme.primary)
                        }
                        .transition(.move(edge: .top).combined(with: .opacity))
                    }
                }
                .frame(width: 300, alignment: .leading)
            }
        }
        .onAppear { startDiagnosticTimer() }
        .onChange(of: isModelLoading) { _, loading in
            if !loading {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    activeStep = Configuration.steps.count
                    showFinalReady = true
                }
            }
        }
    }
    
    @ViewBuilder
    private func diagnosticIcon(for index: Int) -> some View {
        if activeStep > index {
            Image(systemName: "checkmark.shield.fill")
                .foregroundColor(Theme.primary)
                .font(.system(size: 14))
        } else if activeStep == index {
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(Theme.primary, lineWidth: 2)
                .frame(width: 14, height: 14)
                .rotationEffect(.degrees(360))
                .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: activeStep)
        } else {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                .frame(width: 14, height: 14)
        }
    }
    
    private func startDiagnosticTimer() {
        for i in 0..<Configuration.steps.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * Configuration.stepInterval) {
                if activeStep < i {
                    withAnimation(.easeIn(duration: 0.3)) { activeStep = i }
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                }
            }
        }
    }
}
