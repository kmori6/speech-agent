//
//  LLMClient.swift
//  LocalSpokenDialogue
//
//  Created by Kosuke Mori on 2026/03/19.
//

import Combine
import Foundation
import MLXLMCommon
import MLXVLM


final class LLMClient: ObservableObject {
    
    @Published var isReady = false
    private var session: ChatSession?
    private var reasoningEnabled = false
    private let instructions = "You are a helpful assistant. Chat with user in Japanese."
    
    func load() async {
        if isReady {
            return
        }
        
        guard let modelDirectory = Bundle.main.resourceURL?
            .appendingPathComponent("Qwen3.5-4B-MLX-4bit") else {
            fatalError("model folder not found")
        }
        
        do {
            let container = try await loadModelContainer(directory:
              modelDirectory)
            session = ChatSession(
              container,
              instructions: instructions,
              generateParameters: .init(
                  maxTokens: 256,
                  temperature: 0.7,
                  topP: 0.8,
                  presencePenalty: 0.0,
              ),
              additionalContext: ["enable_thinking": reasoningEnabled]
            )
            
            isReady = true
            print("loaded model.")
        } catch {
            print("model load failed.")
        }
    }
    
    func applyChatTemplate(messages: [Message], enableThinking: Bool = false) -> String {
        var prompt = "<|im_start|>system\n\(instructions)<|im_end|>\n"
        
        for message in messages {
            prompt += "<|im_start|>\(message.role)\n\(message.content)<|im_end|>\n"
        }
        
        prompt += "<|im_start|>assistant\n<think>\n"
        if !enableThinking {
            prompt += "\n</think>\n\n"
        }
        
        return prompt
    }
    
    func generate(text: String) async -> Message {
        guard let session else {
            return Message(role: "assistant", content: "model is not loaded.")
        }
        
        do {
            let output = try await session.respond(to: text)
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            let message = Message(role: "assistant", content: trimmed)
            return message
            
        } catch {
            return Message(role: "assistant", content: "generation failed.")
        }
    }
}
