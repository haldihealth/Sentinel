import Foundation

/// Error type for async timeout operations
enum TimeoutError: LocalizedError {
    case timedOut(seconds: TimeInterval)
    case cancelled
    
    var errorDescription: String? {
        switch self {
        case .timedOut(let seconds):
            return "Operation timed out after \(Int(seconds)) seconds"
        case .cancelled:
            return "Operation was cancelled"
        }
    }
}

/// Generic async timeout helper to reduce code duplication
///
/// Replaces repeated timeout pattern with `withThrowingTaskGroup`
/// Used throughout the app for LLM inference, HealthKit queries, etc.
///
/// ## Usage Examples
/// ```swift
/// // Throwing version - use when timeout should propagate as error
/// let result = try await AsyncHelpers.withTimeout(seconds: 30) {
///     try await longRunningOperation()
/// }
///
/// // Optional version - use when timeout should return nil
/// let result = await AsyncHelpers.withTimeoutOptional(seconds: 10) {
///     try await fetchData()
/// }
/// ```
struct AsyncHelpers {
    
    /// Executes an async operation with a timeout
    /// - Parameters:
    ///   - seconds: Timeout duration in seconds
    ///   - operation: The async operation to execute
    /// - Returns: The result of the operation
    /// - Throws: `TimeoutError.timedOut` if timeout occurs, or operation's error
    static func withTimeout<T>(
        seconds: TimeInterval,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            // Task 1: The actual operation
            group.addTask {
                try await operation()
            }
            
            // Task 2: Timeout
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError.timedOut(seconds: seconds)
            }
            
            // Wait for first completion
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
    
    /// Executes an async operation with a timeout, returning nil on timeout instead of throwing
    /// - Parameters:
    ///   - seconds: Timeout duration in seconds
    ///   - operation: The async operation to execute
    /// - Returns: The result of the operation, or nil if timeout or cancellation occurs
    static func withTimeoutOptional<T>(
        seconds: TimeInterval,
        operation: @escaping () async throws -> T
    ) async -> T? {
        do {
            return try await withTimeout(seconds: seconds, operation: operation)
        } catch {
            return nil
        }
    }
    
    /// Executes an async operation with a timeout that respects task cancellation
    /// - Parameters:
    ///   - seconds: Timeout duration in seconds
    ///   - operation: The async operation to execute
    /// - Returns: The result of the operation
    /// - Throws: `TimeoutError.cancelled` if cancelled, `TimeoutError.timedOut` if timeout, or operation's error
    static func withCancellableTimeout<T>(
        seconds: TimeInterval,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        // Check for cancellation before starting
        try Task.checkCancellation()
        
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                throw TimeoutError.timedOut(seconds: seconds)
            }
            
            // Check for cancellation while waiting
            guard let result = try await group.next() else {
                throw TimeoutError.cancelled
            }
            group.cancelAll()
            return result
        }
    }
}
