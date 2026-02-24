import Foundation

/// Represents a media item in the Hope Box
/// Can be a mission briefing video or reinforcement asset
struct HopeBoxItem: Codable, Identifiable {
    let id: UUID
    var title: String
    var subtitle: String?
    var type: HopeBoxItemType
    var mediaType: HopeBoxMediaType
    var filePaths: [String]
    var thumbnailPath: String?
    var duration: TimeInterval?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        subtitle: String? = nil,
        type: HopeBoxItemType,
        mediaType: HopeBoxMediaType,
        filePaths: [String],
        thumbnailPath: String? = nil,
        duration: TimeInterval? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.type = type
        self.mediaType = mediaType
        self.filePaths = filePaths
        self.thumbnailPath = thumbnailPath
        self.duration = duration
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Formatted duration string (e.g., "0:45")
    var formattedDuration: String? {
        guard let duration = duration else { return nil }
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Supporting Types

/// Type of Hope Box content
enum HopeBoxItemType: String, Codable {
    case missionBriefing = "mission_briefing"
    case reinforcement = "reinforcement"
}

/// Source of the briefing
enum BriefingSource: String, Codable {
    case selfCommand = "self_command"
    case battleBuddy = "battle_buddy"
}

/// Media type for Hope Box items
enum HopeBoxMediaType: String, Codable {
    case video
    case photo
    case photoCollection
}

/// Container for Hope Box data
struct HopeBox: Codable {
    var selfCommandBriefing: HopeBoxItem?
    var battleBuddyBriefing: HopeBoxItem?
    var reinforcements: [HopeBoxItem]
    var createdAt: Date
    var updatedAt: Date

    init(
        selfCommandBriefing: HopeBoxItem? = nil,
        battleBuddyBriefing: HopeBoxItem? = nil,
        reinforcements: [HopeBoxItem] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.selfCommandBriefing = selfCommandBriefing
        self.battleBuddyBriefing = battleBuddyBriefing
        self.reinforcements = reinforcements
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Check if any content exists
    var hasContent: Bool {
        selfCommandBriefing != nil || battleBuddyBriefing != nil || !reinforcements.isEmpty
    }

    /// Get briefing for specified source
    func briefing(for source: BriefingSource) -> HopeBoxItem? {
        switch source {
        case .selfCommand:
            return selfCommandBriefing
        case .battleBuddy:
            return battleBuddyBriefing
        }
    }
}
