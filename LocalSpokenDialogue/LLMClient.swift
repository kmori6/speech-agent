//
//  LLMClient.swift
//  LocalSpokenDialogue
//
//  Created by Kosuke Mori on 2026/03/19.
//

import Foundation
import Combine
import llama

struct Request: Encodable {
    let model: String
    let instructions: String
    let input: [Content]
}

struct Responses: Decodable {
    let id: String
    let output: [Content]
}

struct Content: Codable {
    let role: String
    let content: [ContentItem]
}

struct ContentItem: Codable {
    let type: String
    let text: String
}

final class LLMClient: ObservableObject {
    private let baseURL = "https://api.openai.com/v1"
    private let model = "gpt-5.4"
    private let instructions = "You are a helpful assistant."
    
    @Published var isReady = false
    private let modelFileName = "Qwen3.5-4B-Q4_K_M"
    private let modelFileExtension = "gguf"
    private var context: LlamaContext?
    
    func load() async {
        if isReady {
            return
        }
        
        do {
            guard let modelURL = Bundle.main.url(
                forResource: modelFileName,
                withExtension: modelFileExtension,
            ) else {
                print("model url error.")
                return
            }

            context = try LlamaContext.create_context(path: modelURL.path)
            isReady = true
            print("loaded model.")
        } catch {
            print("model load failed.")
        }
    }
    
    func responses(messages: [Message]) async -> String {
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] else {
            return ""
        }
        
        guard let url = URL(string: "\(baseURL)/responses") else {
            return ""
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        var contents: [Content] = []
        for message in messages {
            let type = message.role == "user" ? "input_text" : "output_text"
            let item = ContentItem(type: type, text: message.content)
            let content = Content(role: message.role, content: [item])
            contents.append(content)
        }
        
        let body = Request(model: model, instructions: instructions, input: contents)
        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (data, _) = try await URLSession.shared.data(for: request)
            let decoder = JSONDecoder()
            let json = try decoder.decode(Responses.self, from: data)
            let text = json.output[0].content[0].text
            return text
        } catch {
            print(error)
            return ""
        }
    }
}
