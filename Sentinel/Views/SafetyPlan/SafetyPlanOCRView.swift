import SwiftUI
import VisionKit
import PhotosUI

/// View for scanning/importing a paper Safety Plan using OCR
struct SafetyPlanOCRView: View {
    @ObservedObject var viewModel: SafetyPlanViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showDocumentScanner = false
    @State private var showPhotoPicker = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var scannedImages: [UIImage] = []
    @State private var showProcessingView = false
    @State private var showResultsView = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Header illustration
                headerIllustration

                // Content
                ScrollView {
                    VStack(spacing: Spacing.xl) {
                        // Instructions
                        instructionsView

                        // Action buttons
                        actionButtonsView

                        // Tips
                        tipsView
                    }
                    .padding(.horizontal, Spacing.screenHorizontal)
                    .padding(.bottom, Spacing.xxxl)
                }
            }
            .background(Theme.background)
            .navigationTitle("Scan Safety Plan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .sheet(isPresented: $showDocumentScanner) {
                DocumentScannerView { images in
                    scannedImages = images
                    processScannedImages()
                }
            }
            .photosPicker(
                isPresented: $showPhotoPicker,
                selection: $selectedPhotos,
                maxSelectionCount: 4,
                matching: .images
            )
            .onChange(of: selectedPhotos) { _, newValue in
                Task {
                    await loadSelectedPhotos(newValue)
                }
            }
            .sheet(isPresented: $showProcessingView) {
                processingView
            }
            .sheet(isPresented: $showResultsView) {
                OCRResultsView(viewModel: viewModel) {
                    showResultsView = false
                    dismiss()
                }
            }
        }
    }

    // MARK: - Header Illustration

    private var headerIllustration: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Theme.primary.opacity(0.2), Theme.background],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 200)

            // Icon
            VStack(spacing: Spacing.md) {
                ZStack {
                    Circle()
                        .fill(Theme.surface)
                        .frame(width: 100, height: 100)

                    Image(systemName: "doc.text.viewfinder")
                        .font(.system(size: 44))
                        .foregroundStyle(Theme.primary)
                }

                Text("Import Your Existing Plan")
                    .font(Typography.title3)
                    .foregroundStyle(.white)
            }
        }
    }

    // MARK: - Instructions

    private var instructionsView: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("HOW IT WORKS")
                .font(Typography.captionSmall)
                .foregroundStyle(.secondary)
                .tracking(1)

            VStack(alignment: .leading, spacing: Spacing.lg) {
                instructionStep(number: 1, text: "Take photos of your paper Safety Plan or select existing photos")
                instructionStep(number: 2, text: "Our OCR technology will read and extract the text")
                instructionStep(number: 3, text: "Review and edit the imported information")
            }
        }
    }

    private func instructionStep(number: Int, text: String) -> some View {
        HStack(alignment: .top, spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(Theme.primary)
                    .frame(width: 28, height: 28)

                Text("\(number)")
                    .font(Typography.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)
            }

            Text(text)
                .font(Typography.body)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Action Buttons

    private var actionButtonsView: some View {
        VStack(spacing: Spacing.md) {
            // Scan document button
            if VNDocumentCameraViewController.isSupported {
                Button(action: { showDocumentScanner = true }) {
                    HStack(spacing: Spacing.md) {
                        ZStack {
                            Circle()
                                .fill(Theme.primary.opacity(0.2))
                                .frame(width: 52, height: 52)

                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 24))
                                .foregroundStyle(Theme.primary)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Scan Document")
                                .font(Typography.bodyEmphasis)
                                .foregroundStyle(.white)

                            Text("Use camera to scan your paper plan")
                                .font(Typography.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .padding(Spacing.lg)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: CornerRadius.standard))
                }
                .buttonStyle(.plain)
            }

            // Select from photos button
            Button(action: { showPhotoPicker = true }) {
                HStack(spacing: Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(Theme.primary.opacity(0.2))
                            .frame(width: 52, height: 52)

                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 24))
                            .foregroundStyle(Theme.primary)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Select from Photos")
                            .font(Typography.bodyEmphasis)
                            .foregroundStyle(.white)

                        Text("Choose existing photos of your plan")
                            .font(Typography.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(Spacing.lg)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: CornerRadius.standard))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Tips

    private var tipsView: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("TIPS FOR BEST RESULTS")
                .font(Typography.captionSmall)
                .foregroundStyle(.secondary)
                .tracking(1)

            VStack(alignment: .leading, spacing: Spacing.sm) {
                tipItem(icon: "light.max", text: "Use good lighting")
                tipItem(icon: "rectangle.portrait", text: "Keep the page flat and aligned")
                tipItem(icon: "doc.on.doc", text: "Scan all pages if your plan has multiple pages")
                tipItem(icon: "hand.draw", text: "Printed text works best; handwriting may have some errors")
            }
            .padding(Spacing.md)
            .background(Theme.surface.opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.standard))
        }
    }

    private func tipItem(icon: String, text: String) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundStyle(Theme.primary)
                .frame(width: 20)

            Text(text)
                .font(Typography.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Processing View

    private var processingView: some View {
        VStack(spacing: Spacing.xl) {
            Spacer()

            // Progress indicator
            ZStack {
                Circle()
                    .stroke(Theme.surface, lineWidth: 8)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: viewModel.ocrProgress)
                    .stroke(Theme.primary, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: viewModel.ocrProgress)

                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 36))
                    .foregroundStyle(Theme.primary)
            }

            VStack(spacing: Spacing.sm) {
                Text("Processing...")
                    .font(Typography.title3)
                    .foregroundStyle(.white)

                Text("Reading your safety plan")
                    .font(Typography.body)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Cancel button
            Button(action: {
                showProcessingView = false
            }) {
                Text("Cancel")
                    .font(Typography.bodyEmphasis)
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, Spacing.xxxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
        .presentationDetents([.medium])
    }

    // MARK: - Actions

    private func processScannedImages() {
        guard !scannedImages.isEmpty else { return }

        showProcessingView = true

        Task {
            await viewModel.processOCRImages(scannedImages)

            await MainActor.run {
                showProcessingView = false

                if viewModel.errorMessage == nil {
                    showResultsView = true
                }
            }
        }
    }

    private func loadSelectedPhotos(_ items: [PhotosPickerItem]) async {
        var images: [UIImage] = []

        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                images.append(image)
            }
        }

        if !images.isEmpty {
            await MainActor.run {
                scannedImages = images
                selectedPhotos = []
                processScannedImages()
            }
        }
    }
}

// MARK: - Document Scanner View

/// UIKit wrapper for VNDocumentCameraViewController
struct DocumentScannerView: UIViewControllerRepresentable {
    let onScan: ([UIImage]) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let onScan: ([UIImage]) -> Void

        init(onScan: @escaping ([UIImage]) -> Void) {
            self.onScan = onScan
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var images: [UIImage] = []

            for i in 0..<scan.pageCount {
                images.append(scan.imageOfPage(at: i))
            }

            controller.dismiss(animated: true) {
                self.onScan(images)
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            controller.dismiss(animated: true)
        }
    }
}

// MARK: - OCR Results View

/// Shows the results of OCR processing and allows editing before saving
struct OCRResultsView: View {
    @ObservedObject var viewModel: SafetyPlanViewModel
    let onComplete: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Spacing.xl) {
                    // Success header
                    successHeader

                    // Summary of imported items
                    importSummary

                    // Edit prompt
                    editPrompt
                }
                .padding(.horizontal, Spacing.screenHorizontal)
                .padding(.vertical, Spacing.lg)
            }
            .background(Theme.background)
            .navigationTitle("Import Complete")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onComplete()
                    }
                }
            }
        }
    }

    private var successHeader: some View {
        HStack(spacing: Spacing.md) {
            ZStack {
                Circle()
                    .fill(Theme.primary.opacity(0.2))
                    .frame(width: 56, height: 56)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(Theme.primary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("Successfully Imported")
                    .font(Typography.title3)
                    .foregroundStyle(.white)

                Text("Your safety plan has been scanned")
                    .font(Typography.body)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var importSummary: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            Text("IMPORTED ITEMS")
                .font(Typography.captionSmall)
                .foregroundStyle(.secondary)
                .tracking(1)

            VStack(spacing: Spacing.sm) {
                if let plan = viewModel.safetyPlan {
                    summaryRow("Warning Signs", count: plan.warningSigns.count)
                    summaryRow("Coping Strategies", count: plan.copingStrategies.count)
                    summaryRow("Social Contacts", count: plan.socialDistractions.count)
                    summaryRow("Support Contacts", count: plan.supportContacts.count)
                    summaryRow("Professional Contacts", count: plan.professionalContacts.count)
                    summaryRow("Environment Safety Steps", count: plan.environmentSafetySteps.count)
                    summaryRow("Reasons for Living", count: plan.reasonsForLiving.count)
                }
            }
            .padding(Spacing.md)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.standard))
        }
    }

    private func summaryRow(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(Typography.body)
                .foregroundStyle(.white)

            Spacer()

            HStack(spacing: 4) {
                Text("\(count)")
                    .font(Typography.bodyEmphasis)
                    .foregroundStyle(count > 0 ? Theme.primary : .secondary)

                if count > 0 {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.primary)
                }
            }
        }
    }

    private var editPrompt: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "info.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Theme.primary)

                Text("You can review and edit your plan anytime from the Safety Plan tab")
                    .font(Typography.body)
                    .foregroundStyle(.secondary)
            }
            .padding(Spacing.md)
            .background(Theme.primary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: CornerRadius.standard))
        }
    }
}

// MARK: - Preview

#Preview {
    SafetyPlanOCRView(viewModel: SafetyPlanViewModel())
        .preferredColorScheme(.dark)
}
