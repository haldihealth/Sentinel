import Foundation
import os.log

/// Centralized logging system using OSLog for structured, performant logging
///
/// Usage:
/// ```swift
/// Logger.ai.info("Starting inference")
/// Logger.healthKit.error("Failed to fetch data: \(error)")
/// Logger.checkIn.debug("State transition: \(state)")
/// ```
///
/// Benefits over `print()`:
/// - Disabled in release builds (no performance impact)
/// - Structured logs viewable in Console.app
/// - Category-based filtering
/// - Type-safe formatting
enum Logger {
    /// AI and MedGemma inference logging
    static let ai = os.Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.sentinel", category: "AI")
    
    /// HealthKit queries and data fetching
    static let healthKit = os.Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.sentinel", category: "HealthKit")
    
    /// Check-in workflow and state management
    static let checkIn = os.Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.sentinel", category: "CheckIn")
    
    /// UI interactions and navigation
    static let ui = os.Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.sentinel", category: "UI")
    
    /// LCSC (Longitudinal Clinical State Compression) operations
    static let lcsc = os.Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.sentinel", category: "LCSC")
    
    /// Storage and persistence operations
    static let storage = os.Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.sentinel", category: "Storage")
    
    /// Camera and media capture
    static let camera = os.Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.sentinel", category: "Camera")
    
    /// Audio recording and speech analysis
    static let audio = os.Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.sentinel", category: "Audio")

    /// Hope Box media and storage operations
    static let hopeBox = os.Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.sentinel", category: "HopeBox")
}

// MARK: - Structured Logging Helpers

extension os.Logger {
    /// Log a timed operation with automatic duration calculation
    /// - Parameters:
    ///   - operation: Description of the operation
    ///   - block: The operation to time
    func timed<T>(_ operation: String, block: () throws -> T) rethrows -> T {
        let start = Date()
        self.info("⏱️ \(operation) - START")
        defer {
            let duration = Date().timeIntervalSince(start)
            let durationString = String(format: "%.2f", duration)
            self.info("⏱️ \(operation) - DONE (\(durationString)s)")
        }
        return try block()
    }
    
    /// Log async timed operation
    /// - Parameters:
    ///   - operation: Description of the operation
    ///   - block: The async operation to time
    func timed<T>(_ operation: String, block: () async throws -> T) async rethrows -> T {
        let start = Date()
        self.info("⏱️ \(operation) - START")
        defer {
            let duration = Date().timeIntervalSince(start)
            let durationString = String(format: "%.2f", duration)
            self.info("⏱️ \(operation) - DONE (\(durationString)s)")
        }
        return try await block()
    }
}
