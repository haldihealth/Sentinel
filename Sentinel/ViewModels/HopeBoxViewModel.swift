import Foundation
import Combine
import UIKit
import SwiftUI
import AVFoundation
import PhotosUI
import os.log

/// Manages the Hope Box feature
///
/// Handles mission briefing recordings and reinforcement assets
/// for crisis intervention support.
@MainActor
final class HopeBoxViewModel: ObservableObject {
    // MARK: - Published State

    @Published var isLoading = false
    @Published var errorMessage: String?

    /// The user's hope box data
    @Published var hopeBox: HopeBox?


    /// Video recording state
    @Published var isRecording = false
    @Published var recordingProgress: Double = 0
    @Published var hasRecordedVideo = false

    /// Media picker state
    @Published var showMediaPicker = false
    @Published var showVideoPicker = false

    /// Playback state
    @Published var isPlayingBriefing = false
    @Published var isPlayingReinforcement = false
    @Published var currentlyPlayingId: UUID?

    /// Recording countdown
    @Published var countdownValue: Int = 0
    @Published var isCountingDown = false

    // MARK: - Dependencies

    private let localStorage: LocalStorage
    private let fileManager = FileManager.default

    // MARK: - Constants

    let maxBriefingDuration: TimeInterval = 30
    let maxReinforcementDuration: TimeInterval = 60

    // MARK: - Directory Paths

    private var hopeBoxDirectory: URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("HopeBox", isDirectory: true)
    }

    private var briefingsDirectory: URL {
        hopeBoxDirectory.appendingPathComponent("Briefings", isDirectory: true)
    }

    private var reinforcementsDirectory: URL {
        hopeBoxDirectory.appendingPathComponent("Reinforcements", isDirectory: true)
    }

    private var thumbnailsDirectory: URL {
        hopeBoxDirectory.appendingPathComponent("Thumbnails", isDirectory: true)
    }

    // MARK: - Initialization

    init(localStorage: LocalStorage = LocalStorage()) {
        self.localStorage = localStorage
        createDirectoriesIfNeeded()
    }

    // MARK: - Directory Setup

    private func createDirectoriesIfNeeded() {
        let directories = [hopeBoxDirectory, briefingsDirectory, reinforcementsDirectory, thumbnailsDirectory]
        for directory in directories {
            if !fileManager.fileExists(atPath: directory.path) {
                do {
                    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
                } catch {
                    print("[HopeBox] Failed to create directory at \(directory.path): \(error)")
                    errorMessage = "Failed to initialize storage: \(error.localizedDescription)"
                }
            }
        }
    }

    // MARK: - Public Methods

    /// Loads the hope box from storage
    func loadHopeBox() async {
        isLoading = true
        defer { isLoading = false }

        hopeBox = localStorage.loadHopeBox()

        // Create new if doesn't exist
        if hopeBox == nil {
            hopeBox = HopeBox()
            saveHopeBox()
        }
        
        // Migrate paths if needed
        await migratePaths()
    }
    
    /// Migrates absolute paths to relative paths
    private func migratePaths() async {
        guard var box = hopeBox else { return }
        var needsSave = false
        
        // Helper to convert absolute to relative
        func makeRelative(_ path: String) -> String {
            if path.contains("/Documents/HopeBox/") {
                let components = path.components(separatedBy: "/Documents/")
                if components.count > 1 {
                    return components.last ?? path
                }
            }
            return path
        }
        
        // Migrate Self-Command Briefing
        if let briefing = box.selfCommandBriefing {
            let relativePaths = briefing.filePaths.map { makeRelative($0) }
            let relativeThumbnail = briefing.thumbnailPath.map { makeRelative($0) }
            
            if relativePaths != briefing.filePaths || relativeThumbnail != briefing.thumbnailPath {
                var newBriefing = briefing
                newBriefing.filePaths = relativePaths
                newBriefing.thumbnailPath = relativeThumbnail
                box.selfCommandBriefing = newBriefing
                needsSave = true
            }
        }
        
        // Migrate Reinforcements
        var newReinforcements: [HopeBoxItem] = []
        for reinforcement in box.reinforcements {
            let relativePaths = reinforcement.filePaths.map { makeRelative($0) }
            let relativeThumbnail = reinforcement.thumbnailPath.map { makeRelative($0) }
            
            if relativePaths != reinforcement.filePaths || relativeThumbnail != reinforcement.thumbnailPath {
                var newReinforcement = reinforcement
                newReinforcement.filePaths = relativePaths
                newReinforcement.thumbnailPath = relativeThumbnail
                newReinforcements.append(newReinforcement)
                needsSave = true
            } else {
                newReinforcements.append(reinforcement)
            }
        }
        
        if needsSave {
            box.reinforcements = newReinforcements
            hopeBox = box
            saveHopeBox()
            Logger.hopeBox.info("Migrated paths to relative")
        }
    }

    /// Saves the hope box
    func saveHopeBox() {
        guard var box = hopeBox else { return }
        box.updatedAt = Date()
        localStorage.saveHopeBox(box)
        hopeBox = box
    }

    // MARK: - Briefing Management

    /// Get current briefing for self-command
    var currentBriefing: HopeBoxItem? {
        hopeBox?.selfCommandBriefing
    }

    /// Check if briefing exists for selected source
    var hasBriefing: Bool {
        currentBriefing != nil
    }

    /// Save a recorded briefing video
    func saveBriefing(from videoURL: URL, duration: TimeInterval) async {
        let fileName = "self_command_briefing_\(UUID().uuidString).mp4"
        let destinationURL = briefingsDirectory.appendingPathComponent(fileName)

        do {
            // Copy video to app storage
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: videoURL, to: destinationURL)

            // Generate thumbnail
            let thumbnailPath = await generateThumbnail(from: destinationURL)

            let title = "Self-Command Briefing"
            // Store relative paths
            let relativeVideoPath = "HopeBox/Briefings/\(fileName)"
            
            let item = HopeBoxItem(
                title: title,
                subtitle: "Mission Briefing",
                type: .missionBriefing,
                mediaType: .video,
                filePaths: [relativeVideoPath],
                thumbnailPath: thumbnailPath, // generateThumbnail now returns relative path
                duration: duration
            )

            // Delete old briefing if exists
            if let oldBriefing = currentBriefing {
                deleteBriefingFile(oldBriefing)
            }

            hopeBox?.selfCommandBriefing = item

            saveHopeBox()
            hasRecordedVideo = true
        } catch {
            errorMessage = "Failed to save briefing: \(error.localizedDescription)"
        }
    }

    /// Delete briefing for current source
    func deleteBriefing() {
        if let briefing = currentBriefing {
            deleteBriefingFile(briefing)
        }

        hopeBox?.selfCommandBriefing = nil

        saveHopeBox()
        hasRecordedVideo = false
    }

    private func deleteBriefingFile(_ item: HopeBoxItem) {
        do {
            for path in item.filePaths {
                let fullPath = getFullPath(for: path)
                if fileManager.fileExists(atPath: fullPath.path) {
                    try fileManager.removeItem(at: fullPath)
                }
            }
        } catch {
            Logger.hopeBox.error("Failed to remove briefing file: \(error.localizedDescription)")
            errorMessage = "Failed to delete briefing file: \(error.localizedDescription)"
        }
        if let thumbnailPath = item.thumbnailPath {
            do {
                try fileManager.removeItem(atPath: thumbnailPath)
            } catch {
            Logger.hopeBox.error("Failed to remove briefing thumbnail at \(thumbnailPath): \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Reinforcement Management

    /// Add a reinforcement from photo library
    func addReinforcement(title: String, subtitle: String?, images: [UIImage]) async {
        guard !images.isEmpty else { return }

        let id = UUID()
        let mediaType: HopeBoxMediaType = images.count > 1 ? .photoCollection : .photo

        // Save images
        var savedPaths: [String] = []
        for (index, image) in images.enumerated() {
            let fileName = "reinforcement_\(id.uuidString)_\(index).jpg"
            let path = reinforcementsDirectory.appendingPathComponent(fileName)
            if let data = image.jpegData(compressionQuality: 0.8) {
                do {
                    try data.write(to: path)
                    // Store relative path
                    let relativePath = "HopeBox/Reinforcements/\(fileName)"
                    savedPaths.append(relativePath)
                } catch {
                    Logger.hopeBox.error("Failed to save image \(index) at \(path.path): \(error.localizedDescription)")
                }
            }
        }

        guard !savedPaths.isEmpty else {
            errorMessage = "Failed to save images"
            return
        }

        // Generate thumbnail from first image
        let thumbnailPath = await saveThumbnail(image: images[0], id: id)

        let item = HopeBoxItem(
            id: id,
            title: title,
            subtitle: subtitle,
            type: .reinforcement,
            mediaType: mediaType,
            filePaths: savedPaths,
            thumbnailPath: thumbnailPath
        )

        hopeBox?.reinforcements.append(item)
        saveHopeBox()
    }

    /// Add a video reinforcement
    func addVideoReinforcement(title: String, subtitle: String?, videoURL: URL, duration: TimeInterval) async {
        let id = UUID()
        let fileName = "reinforcement_\(id.uuidString).mp4"
        let destinationURL = reinforcementsDirectory.appendingPathComponent(fileName)

        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: videoURL, to: destinationURL)

            let thumbnailPath = await generateThumbnail(from: destinationURL)

            // Store relative path
            let relativeVideoPath = "HopeBox/Reinforcements/\(fileName)"

            let item = HopeBoxItem(
                id: id,
                title: title,
                subtitle: subtitle,
                type: .reinforcement,
                mediaType: .video,
                filePaths: [relativeVideoPath],
                thumbnailPath: thumbnailPath,
                duration: duration
            )

            hopeBox?.reinforcements.append(item)
            saveHopeBox()
        } catch {
            errorMessage = "Failed to save video: \(error.localizedDescription)"
        }
    }

    /// Remove a reinforcement
    func removeReinforcement(_ item: HopeBoxItem) {
        for path in item.filePaths {
            do {
                let fullPath = getFullPath(for: path)
                if fileManager.fileExists(atPath: fullPath.path) {
                    try fileManager.removeItem(at: fullPath)
                }
            } catch {
                Logger.hopeBox.error("Failed to remove file at \(path): \(error.localizedDescription)")
            }
        }

        if let thumbnailPath = item.thumbnailPath {
            do {
                try fileManager.removeItem(atPath: thumbnailPath)
            } catch {
                Logger.hopeBox.error("Failed to remove thumbnail at \(thumbnailPath): \(error.localizedDescription)")
            }
        }

        hopeBox?.reinforcements.removeAll { $0.id == item.id }
        saveHopeBox()
    }

    /// Reorder reinforcements
    func moveReinforcement(from source: IndexSet, to destination: Int) {
        hopeBox?.reinforcements.move(fromOffsets: source, toOffset: destination)
        saveHopeBox()
    }

    // MARK: - Thumbnail Generation

    private func generateThumbnail(from videoURL: URL) async -> String? {
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true

        let time = CMTime(seconds: 0.5, preferredTimescale: 600)

        do {
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            let uiImage = UIImage(cgImage: cgImage)
            return await saveThumbnail(image: uiImage, id: UUID())
        } catch {
            return nil
        }
    }

    private func saveThumbnail(image: UIImage, id: UUID) async -> String? {
        let fileName = "thumb_\(id.uuidString).jpg"
        let path = thumbnailsDirectory.appendingPathComponent(fileName)

        // Resize for thumbnail maintaining aspect ratio (Aspect Fill)
        let targetSize = CGSize(width: 200, height: 200)
        let renderer = UIGraphicsImageRenderer(size: targetSize)

        let resized = renderer.image { _ in
            let widthRatio = targetSize.width / image.size.width
            let heightRatio = targetSize.height / image.size.height
            let ratio = max(widthRatio, heightRatio)

            let newSize = CGSize(width: image.size.width * ratio, height: image.size.height * ratio)
            let rect = CGRect(
                x: (targetSize.width - newSize.width) / 2,
                y: (targetSize.height - newSize.height) / 2,
                width: newSize.width,
                height: newSize.height
            )

            image.draw(in: rect)
        }

        if let data = resized.jpegData(compressionQuality: 0.7) {
            do {
                try data.write(to: path)
                // Store relative path
                return "HopeBox/Thumbnails/\(fileName)"
            } catch {
                Logger.hopeBox.error("Failed to save thumbnail at \(path.path): \(error.localizedDescription)")
            }
        }

        return nil
    }

    // MARK: - Playback

    private func getFullPath(for relativePath: String) -> URL {
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        // Handle case where path is already absolute (for backward compatibility during migration)
        if relativePath.hasPrefix("/") {
            return URL(fileURLWithPath: relativePath)
        }
        
        // Handle relative path (HopeBox/...)
        return documentsPath.appendingPathComponent(relativePath)
    }

    func getVideoURL(for item: HopeBoxItem) -> URL? {
        guard item.mediaType == .video, let path = item.filePaths.first else { return nil }
        return getFullPath(for: path)
    }

    func getImages(for item: HopeBoxItem) -> [UIImage] {
        guard item.mediaType == .photo || item.mediaType == .photoCollection else { return [] }

        return item.filePaths.compactMap { path in
            let url = getFullPath(for: path)
            return UIImage(contentsOfFile: url.path)
        }
    }

    func getThumbnail(for item: HopeBoxItem) -> UIImage? {
        guard let path = item.thumbnailPath else { return nil }
        let url = getFullPath(for: path)
        return UIImage(contentsOfFile: url.path)
    }

    // MARK: - Deploy All Reinforcements

    /// Plays all reinforcements in sequence
    func deployAllReinforcements() {
        // This will be handled by the view to show a full-screen slideshow
        isPlayingReinforcement = true
    }

    func stopDeployment() {
        isPlayingReinforcement = false
        currentlyPlayingId = nil
    }
}
