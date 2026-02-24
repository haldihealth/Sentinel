import SwiftUI
import SwiftData

/// Main daily check-in flow coordinator
///
/// Manages the complete workflow:
/// 1. Multimodal Check-In (camera + audio)
/// 2. C-SSRS Screening (questionnaire)
/// 3. Completion and Risk Assessment
struct CheckInView: View {
    // MARK: - Properties
    
    @StateObject private var viewModel = CheckInViewModel()
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showEmergencyCrisis = false
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            content
            
            // Crisis alert overlay - Uses new Red Tier Crisis View
            if showEmergencyCrisis {
                RedTierCrisisView()
                    .transition(.opacity)
                    .zIndex(100)
            }
            // Error Overlay
            if let error = viewModel.errorMessage {
                errorOverlay(message: error)
            }
        }
        .onAppear {
            viewModel.modelContext = modelContext
            // Pre-warm the MedGemma model so it's ready in memory when STOP is pressed
            Task {
                try? await MedGemmaEngine.shared.loadModel()
            }
        }
        .onChange(of: viewModel.shouldDismiss) { _, shouldDismiss in
            if shouldDismiss {
                dismiss()
            }
        }
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var content: some View {
        switch viewModel.currentStep {
        case .multimodal:
            IntervalCheckInView()
                .environmentObject(viewModel)
            .environment(\.modelContext, modelContext)
            
        case .cssrs(let index):
            questionFlow(at: index)
        }
    }
    
    // MARK: - Subviews
    
    private func questionFlow(at index: Int) -> some View {
        CSSRQuestionView(
            questionNumber: index + 1,
            totalQuestions: viewModel.totalQuestions,
            question: CSSRQuestions.question(at: index),
            subtitle: CSSRQuestions.subtitle(at: index),
            badgeText: CSSRQuestions.badge(at: index),
            onAnswer: { answer in
                handleAnswer(answer)
            },
            onBack: index > 0 ? {
                withAnimation {
                    viewModel.goBack()
                }
            } : nil,
            onEmergency: {
                showEmergencyCrisis = true
            }
        )
        .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        ))
        .id(index) // Force view recreation for animation
    }
    
    private func errorOverlay(message: String) -> some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture {
                    viewModel.errorMessage = nil
                }
            
            VStack(spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)
                
                Text("Something went wrong")
                    .font(.headline)
                    .foregroundStyle(.primary)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                
                Button("Dismiss") {
                    viewModel.errorMessage = nil
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.primary)
                .padding(.top, 8)
            }
            .padding(24)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(radius: 20)
            .padding(.horizontal, 40)
        }
        .transition(.opacity)
    }
    
    // MARK: - Helper Methods
    
    private func handleAnswer(_ answer: Bool) {
        withAnimation(.easeInOut(duration: 0.3)) {
            viewModel.answerCurrentQuestion(answer)
        }
    }
}

// MARK: - Preview

#Preview("Light Mode") {
    CheckInView()
        .preferredColorScheme(.light)
}

#Preview("Dark Mode") {
    CheckInView()
        .preferredColorScheme(.dark)
}
