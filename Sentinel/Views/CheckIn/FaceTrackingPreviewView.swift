import SwiftUI
import AVFoundation
import AVKit
import Vision

// MARK: - Live Camera Preview (normal check-in)

/// Wraps AVCaptureVideoPreviewLayer for live camera telemetry display.
struct FaceTrackingPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    let faceObservation: VNFaceObservation?
    let accentColor: Color

    func makeUIView(context: Context) -> FaceTrackingPreviewUIView {
        FaceTrackingPreviewUIView(session: session)
    }

    func updateUIView(_ uiView: FaceTrackingPreviewUIView, context: Context) {
        // Layout is handled in layoutSubviews; no dynamic updates needed.
    }
}

class FaceTrackingPreviewUIView: UIView {
    private var capturePreviewLayer: AVCaptureVideoPreviewLayer?

    init(session: AVCaptureSession) {
        super.init(frame: .zero)
        self.clipsToBounds = true
        let pLayer = AVCaptureVideoPreviewLayer(session: session)
        pLayer.videoGravity = .resizeAspectFill
        layer.addSublayer(pLayer)
        capturePreviewLayer = pLayer
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func layoutSubviews() {
        super.layoutSubviews()
        capturePreviewLayer?.frame = bounds
    }
}

// MARK: - Inline Video Preview (developer video-injection mode)

/// Displays a playing AVPlayer in a contained pane using AVPlayerViewController,
/// which correctly handles rendering alongside AVPlayerItemVideoOutput on the same item.
struct InlineVideoPlayer: UIViewControllerRepresentable {
    let player: AVPlayer

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let vc = AVPlayerViewController()
        vc.player = player
        vc.showsPlaybackControls = false
        vc.videoGravity = .resizeAspectFill
        return vc
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        if uiViewController.player !== player {
            uiViewController.player = player
        }
    }
}
