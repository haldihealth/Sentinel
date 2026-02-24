import SwiftUI

struct LicenseView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    
                    // Intro
                    SectionHeader("Core Intelligence Engine")
                    
                    licenseGroup(
                        name: "llama.cpp",
                        attribution: "Georgi Gerganov & Contributors",
                        description: "High-performance inference engine for Apple Silicon.",
                        licenseType: "MIT License"
                    )
                    
                    licenseGroup(
                        name: "LLM.swift",
                        attribution: "East River Lee & Contributors",
                        description: "Swift bindings for local LLM inference.",
                        licenseType: "MIT License"
                    )

                    licenseGroup(
                        name: "MedGemma",
                        attribution: "Google DeepMind",
                        description: "Fine-tuned medical LLM for clinical summarization.",
                        licenseType: "Gemma Terms of Use"
                    )
                    
                    SectionHeader("Special Thanks")
                    
                    Text("The GGUF quantization format and the open-source AI community for making local-first, privacy-preserving AI possible.")
                        .font(Typography.body)
                        .foregroundStyle(.secondary)
                    
                }
                .padding(Spacing.lg)
            }
            .background(Theme.background)
            .navigationTitle("Open Source Licenses")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
    
    private func licenseGroup(name: String, attribution: String, description: String, licenseType: String) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Text(name)
                    .font(Typography.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text(licenseType)
                    .font(Typography.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Theme.surfaceHover)
                    .clipShape(Capsule())
            }
            
            Text("Created by \(attribution)")
                .font(Typography.caption)
                .foregroundStyle(Theme.primary)
            
            Text(description)
                .font(Typography.body)
                .foregroundStyle(.secondary)
                .padding(.top, 2)
        }
        .padding(Spacing.md)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: CornerRadius.standard))
    }
}
