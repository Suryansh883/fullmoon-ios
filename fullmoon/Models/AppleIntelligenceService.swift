//
//  AppleIntelligenceService.swift
//  fullmoon
//
//  Apple Intelligence (Foundation Models) integration.
//  On-device model, built-in, no download. Requires iOS 26+ and Apple Intelligence enabled.
//

import Foundation
import SwiftData

/// Model identifier used in settings and model list when using Apple Intelligence.
let appleIntelligenceModelId = "apple-intelligence"

enum AppleIntelligenceError: LocalizedError {
    case notAvailable(reason: String)
    case generationFailed(Error)

    var errorDescription: String? {
        switch self {
        case .notAvailable(let reason):
            return String(localized: "Apple Intelligence is not available. \(reason)")
        case .generationFailed(let error):
            return String(localized: "Generation failed: \(error.localizedDescription)")
        }
    }
}

enum AppleIntelligenceService {
    /// Whether the system language model (Apple Intelligence) is available on this device.
    /// Returns false when Foundation Models is unavailable (e.g. pre‑iOS 26) or when Apple Intelligence is disabled.
    static var isAvailable: Bool {
        if #available(macOS 26.0, iOS 26.0, *) {
            return _isAvailableOnNewOS
        }
        return false
    }

    /// User-facing message when Apple Intelligence is unavailable.
    static func unavailabilityMessage() -> String {
        if #available(macOS 26.0, iOS 26.0, *) {
            return _unavailabilityMessageOnNewOS()
        }
        return String(localized: "Apple Intelligence requires macOS 26.0 / iOS 26.0 or newer. Please choose another model.")
    }

    /// Generate a response using Apple Intelligence. Call only when `isAvailable` is true, or handle errors.
    @available(macOS 26.0, iOS 26.0, *)
    static func generateResponse(
        thread: Thread,
        systemPrompt: String
    ) async throws -> String {
        #if canImport(FoundationModels)
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            break
        case .unavailable:
            throw AppleIntelligenceError.notAvailable(reason: Self.unavailabilityMessage())
        }

        let promptString = buildPromptFromThread(thread, systemPrompt: systemPrompt)
        let session = LanguageModelSession {
            systemPrompt
        }
        let response = try await session.respond(to: promptString)
        return response.content
        #else
        throw AppleIntelligenceError.notAvailable(reason: Self.unavailabilityMessage())
        #endif
    }

    /// Build a single prompt string from thread history for the system model.
    private static func buildPromptFromThread(_ thread: Thread, systemPrompt: String) -> String {
        var parts: [String] = []
        for message in thread.sortedMessages {
            let prefix = message.role == .user ? "User" : "Assistant"
            parts.append("\(prefix): \(message.content)")
        }
        return parts.isEmpty ? "" : parts.joined(separator: "\n\n")
    }
}

// MARK: - Foundation Models (macOS 26.0 / iOS 26.0+)
#if canImport(FoundationModels)
import FoundationModels

@available(macOS 26.0, iOS 26.0, *)
extension AppleIntelligenceService {
    static var _isAvailableOnNewOS: Bool {
        let model = SystemLanguageModel.default
        if case .available = model.availability {
            return true
        }
        return false
    }

    static func _unavailabilityMessageOnNewOS() -> String {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            return ""
        case .unavailable:
            return String(localized: "Apple Intelligence is not available on this device. Enable it in Settings or choose another model.")
        }
    }
}
#endif
