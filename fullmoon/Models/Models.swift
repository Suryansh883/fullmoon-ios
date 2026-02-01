//
//  Models.swift
//  fullmoon
//
//  Created by Jordan Singer on 10/4/24.
//

import Foundation
import MLXLMCommon

public extension ModelConfiguration {
    enum ModelType {
        case regular, reasoning
    }

    var modelType: ModelType {
        switch self {
        case .deepseek_r1_distill_qwen_1_5b_4bit: .reasoning
        case .deepseek_r1_distill_qwen_1_5b_8bit: .reasoning
        case .qwen_3_4b_4bit: .reasoning
        case .qwen_3_8b_4bit: .reasoning
        default: .regular
        }
    }
}

extension ModelConfiguration: @retroactive Equatable {
    public static func == (lhs: MLXLMCommon.ModelConfiguration, rhs: MLXLMCommon.ModelConfiguration) -> Bool {
        return lhs.name == rhs.name
    }

    public static let llama_3_2_1b_4bit = ModelConfiguration(
        id: "mlx-community/Llama-3.2-1B-Instruct-4bit"
    )

    public static let llama_3_2_3b_4bit = ModelConfiguration(
        id: "mlx-community/Llama-3.2-3B-Instruct-4bit"
    )

    public static let deepseek_r1_distill_qwen_1_5b_4bit = ModelConfiguration(
        id: "mlx-community/DeepSeek-R1-Distill-Qwen-1.5B-4bit"
    )

    public static let deepseek_r1_distill_qwen_1_5b_8bit = ModelConfiguration(
        id: "mlx-community/DeepSeek-R1-Distill-Qwen-1.5B-8bit"
    )

    public static let qwen_3_4b_4bit = ModelConfiguration(
        id: "mlx-community/Qwen3-4B-4bit"
    )

    public static let qwen_3_8b_4bit = ModelConfiguration(
        id: "mlx-community/Qwen3-8B-4bit"
    )

    // Gemma 2
    public static let gemma_2_2b_it_4bit = ModelConfiguration(
        id: "mlx-community/gemma-2-2b-it-4bit"
    )

    // Gemma 3
    public static let gemma_3_1b_it_4bit = ModelConfiguration(
        id: "mlx-community/gemma-3-1b-it-4bit"
    )
    public static let gemma_3_270m_4bit = ModelConfiguration(
        id: "mlx-community/gemma-3-270m-4bit"
    )

    // IBM Granite 4.0
    public static let granite_4_0_h_tiny_3bit = ModelConfiguration(
        id: "mlx-community/granite-4.0-h-tiny-3bit-MLX"
    )
    public static let granite_4_0_h_1b_4bit = ModelConfiguration(
        id: "mlx-community/granite-4.0-h-1b-4bit"
    )
    // Qwen 3
    public static let qwen_3_vl_2b_4bit = ModelConfiguration(
        id: "mlx-community/Qwen3-VL-2B-Instruct-4bit"
    )
    public static let qwen_3_1_7b_4bit = ModelConfiguration(
        id: "mlx-community/Qwen3-1.7B-4bit"
    )
    public static let qwen_3_0_6b_4bit = ModelConfiguration(
        id: "mlx-community/Qwen3-0.6B-4bit"
    )

    public static var availableModels: [ModelConfiguration] = [
        llama_3_2_1b_4bit,
        llama_3_2_3b_4bit,
        deepseek_r1_distill_qwen_1_5b_4bit,
        deepseek_r1_distill_qwen_1_5b_8bit,
        qwen_3_4b_4bit,
        qwen_3_8b_4bit,
        gemma_2_2b_it_4bit,
        gemma_3_1b_it_4bit,
        gemma_3_270m_4bit,
        granite_4_0_h_tiny_3bit,
        granite_4_0_h_1b_4bit,
        qwen_3_vl_2b_4bit,
        qwen_3_1_7b_4bit,
        qwen_3_0_6b_4bit,
    ]

    public static var defaultModel: ModelConfiguration {
        llama_3_2_1b_4bit
    }

    public static func getModelByName(_ name: String) -> ModelConfiguration? {
        if let model = availableModels.first(where: { $0.name == name }) {
            return model
        } else {
            return nil
        }
    }

    func getPromptHistory(thread: Thread, systemPrompt: String) -> [[String: String]] {
        var history: [[String: String]] = []

        // system prompt
        history.append([
            "role": "system",
            "content": systemPrompt,
        ])

        // messages
        for message in thread.sortedMessages {
            let role = message.role.rawValue
            history.append([
                "role": role,
                "content": formatForTokenizer(message.content), // remove reasoning part
            ])
        }

        return history
    }

    // TODO: Remove this function when Jinja gets updated
    func formatForTokenizer(_ message: String) -> String {
        if modelType == .reasoning {
            let pattern = "<think>.*?(</think>|$)"
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
                let range = NSRange(location: 0, length: message.utf16.count)
                let formattedMessage = regex.stringByReplacingMatches(in: message, options: [], range: range, withTemplate: "")
                return " " + formattedMessage
            } catch {
                return " " + message
            }
        }
        return message
    }

    /// Returns the model's approximate size, in GB.
    public var modelSize: Decimal? {
        switch self {
        case .llama_3_2_1b_4bit: return 0.7
        case .llama_3_2_3b_4bit: return 1.8
        case .deepseek_r1_distill_qwen_1_5b_4bit: return 1.0
        case .deepseek_r1_distill_qwen_1_5b_8bit: return 1.9
        case .qwen_3_4b_4bit: return 2.3
        case .qwen_3_8b_4bit: return 4.7
        case .gemma_2_2b_it_4bit: return 1.47
        case .gemma_3_1b_it_4bit: return 0.733
        case .gemma_3_270m_4bit: return 0.463
        case .granite_4_0_h_tiny_3bit: return 1.81
        case .granite_4_0_h_1b_4bit: return 1.2
        case .qwen_3_vl_2b_4bit: return 1.8
        case .qwen_3_1_7b_4bit: return 0.979
        case .qwen_3_0_6b_4bit: return 0.346
        default: return nil
        }
    }
}
