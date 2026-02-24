import Foundation
import UIKit

/// Shared utilities for phone calls and SMS
/// Centralizes phone number handling for consistency across the app
enum PhoneUtilities {

    // MARK: - Phone Number Sanitization

    /// Sanitize a phone number for use in tel:// or sms:// URLs
    /// Preserves digits, #, and * characters (for extensions and special services)
    static func sanitize(_ phoneNumber: String) -> String {
        phoneNumber.filter { $0.isNumber || $0 == "#" || $0 == "*" }
    }

    // MARK: - Calling

    /// Place a phone call to a social contact
    static func call(_ contact: SocialContact) {
        guard let phone = contact.phoneNumber else { return }
        call(phoneNumber: phone)
    }

    /// Place a phone call to a professional contact
    /// Handles text-only contacts by opening SMS instead
    static func call(_ contact: ProfessionalContact) {
        if contact.isTextOnly {
            sendSMS(to: contact.phoneNumber, body: "HOME")
        } else {
            call(phoneNumber: contact.phoneNumber)
        }
    }

    /// Place a phone call to a raw phone number
    static func call(phoneNumber: String) {
        let sanitized = sanitize(phoneNumber)
        guard !sanitized.isEmpty,
              let url = URL(string: "tel://\(sanitized)") else { return }
        UIApplication.shared.open(url)
    }

    /// Call the 988 Suicide & Crisis Lifeline
    static func call988() {
        call(phoneNumber: "988")
    }

    /// Call 911 emergency services
    static func call911() {
        call(phoneNumber: "911")
    }

    // MARK: - SMS

    /// Send an SMS message
    /// - Parameters:
    ///   - phoneNumber: The recipient's phone number
    ///   - body: Optional pre-filled message body
    static func sendSMS(to phoneNumber: String, body: String? = nil) {
        let sanitized = sanitize(phoneNumber)
        guard !sanitized.isEmpty else { return }

        var urlString = "sms:\(sanitized)"
        if let body = body, !body.isEmpty {
            // URL encode the body
            if let encoded = body.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) {
                urlString += "?body=\(encoded)"
            }
        }

        guard let url = URL(string: urlString) else { return }
        UIApplication.shared.open(url)
    }

    /// Send SMS to Crisis Text Line (741741)
    static func textCrisisLine() {
        sendSMS(to: "741741", body: "HOME")
    }

    // MARK: - URL Validation

    /// Check if a phone call can be made on this device
    static var canMakePhoneCalls: Bool {
        guard let url = URL(string: "tel://") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }

    /// Check if SMS can be sent on this device
    static var canSendSMS: Bool {
        guard let url = URL(string: "sms:") else { return false }
        return UIApplication.shared.canOpenURL(url)
    }
}
