import SwiftUI

/// Individual C-SSRS question card with Yes/No answer buttons
///
/// Displays a single screening question with subtitle, following the Columbia protocol.
/// Styled to match the Sentinel design system with dark mode support.
struct CSSRQuestionView: View {
    // MARK: - Properties
    
    let questionNumber: Int
    let totalQuestions: Int
    let question: String
    let subtitle: String
    let badgeText: String
    let onAnswer: (Bool) -> Void
    let onBack: (() -> Void)?
    let onEmergency: () -> Void
    
    // MARK: - Body
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Progress indicator
            progressView
            
            // Main content
            ScrollView {
                VStack(spacing: 32) {
                    Spacer()
                        .frame(height: 20)
                    
                    // Protocol badge
                    protocolBadge
                    
                    // Question text
                    questionText
                    
                    // Subtitle
                    subtitleText
                    
                    Spacer()
                        .frame(height: 20)
                }
                .padding(.horizontal, 24)
            }
            
            // Answer buttons
            answerButtonsView
        }
        .background(Theme.background)
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack {
            // Back/Close button
            // Back/Close button removed as requested
            Spacer()
                .frame(width: 40) // Keep spacing balanced
            
            Spacer()
            
            Text("DAILY CHECK-IN")
                .font(.caption)
                .fontWeight(.bold)
                .tracking(1.5)
                .foregroundStyle(.secondary)
            
            Spacer()
            
            // Emergency button
            Button(action: onEmergency) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(.red)
                    .frame(width: 40, height: 40)
                    .background(Color.red.opacity(0.1))
                    .overlay(
                        Circle()
                            .stroke(Color.red.opacity(0.2), lineWidth: 1)
                    )
                    .clipShape(Circle())
            }
            .accessibilityLabel("Emergency Crisis Line")
            .accessibilityHint("Call or text the Veterans Crisis Line immediately")
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }
    
    private var progressView: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Step \(questionNumber)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(Theme.primary)
                
                Spacer()
                
                Text("ASSESSMENT \(questionNumber)/\(totalQuestions)")
                    .font(.caption2)
                    .fontWeight(.medium)
                    .tracking(1.2)
                    .foregroundStyle(.tertiary)
            }
            
            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Theme.surfaceHover)
                    
                    Rectangle()
                        .fill(Theme.primary)
                        .frame(width: geometry.size.width * (CGFloat(questionNumber) / CGFloat(totalQuestions)))
                        .shadow(color: Theme.primary.opacity(0.6), radius: 10, x: 0, y: 0)
                }
            }
            .frame(height: 6)
            .clipShape(RoundedRectangle(cornerRadius: 3))
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 16)
    }

    private var protocolBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 14))
                .foregroundStyle(Theme.primary)
            
            Text(badgeText)
                .font(.system(size: 11, weight: .semibold))
                .tracking(1.0)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Theme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color(uiColor: .separator), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }
    
    private var questionText: some View {
        Text(question)
            .font(.title2)
            .fontWeight(.bold)
            .multilineTextAlignment(.center)
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
    }
    
    private var subtitleText: some View {
        Text(subtitle)
            .font(.subheadline)
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
            .frame(maxWidth: 320)
    }
    
    private var answerButtonsView: some View {
        VStack(spacing: 16) {
            // Answer buttons
            HStack(spacing: 16) {
                // No button
                Button(action: { onAnswer(false) }) {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Theme.surfaceHover)
                                .frame(width: 48, height: 48)
                            
                            Image(systemName: "xmark")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        
                        Text("No")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("No")
                .accessibilityHint("Select No as your answer")
                
                // Yes button
                Button(action: { onAnswer(true) }) {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Theme.primary.opacity(0.1))
                                .frame(width: 48, height: 48)
                            
                            Image(systemName: "checkmark")
                                .font(.system(size: 22, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        
                        Text("Yes")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 120)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Yes")
                .accessibilityHint("Select Yes as your answer")
            }
            .padding(.horizontal, 24)
            
            // Privacy notice
            HStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.quaternary)
                
                Text("Your responses are private, secure, and encrypted. This assessment is used solely to coordinate support resources.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(Theme.surface.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
        }
        .padding(.bottom, 16)
    }
}

// MARK: - Preview

#Preview("Question 1 - Light") {
    CSSRQuestionView(
        questionNumber: 1,
        totalQuestions: 6,
        question: CSSRQuestions.question(at: 0),
        subtitle: CSSRQuestions.subtitle(at: 0),
        badgeText: CSSRQuestions.badge(at: 0),
        onAnswer: { _ in },
        onBack: nil,
        onEmergency: { }
    )
    .preferredColorScheme(.light)
}

#Preview("Question 1 - Dark") {
    CSSRQuestionView(
        questionNumber: 1,
        totalQuestions: 6,
        question: CSSRQuestions.question(at: 0),
        subtitle: CSSRQuestions.subtitle(at: 0),
        badgeText: CSSRQuestions.badge(at: 0),
        onAnswer: { _ in },
        onBack: nil,
        onEmergency: { }
    )
    .preferredColorScheme(.dark)
}

#Preview("Question 4 - Dark") {
    CSSRQuestionView(
        questionNumber: 4,
        totalQuestions: 6,
        question: CSSRQuestions.question(at: 3),
        subtitle: CSSRQuestions.subtitle(at: 3),
        badgeText: CSSRQuestions.badge(at: 3),
        onAnswer: { _ in },
        onBack: { },
        onEmergency: { }
    )
    .preferredColorScheme(.dark)
}
