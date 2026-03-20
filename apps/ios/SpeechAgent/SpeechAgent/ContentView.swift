//
//  ContentView.swift
//  SpeechAgent
//
//  Created by Kosuke Mori on 2026/03/18.
//

import SwiftUI

struct Message: Identifiable {
    var id = UUID()
    var role: String
    var content: String
}

struct ContentView: View {
    @State private var text: String = ""
    @State private var messages: [Message] = []
    private var llmClient = LLMClient()
    private var ttsClient = TTSClient()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(messages) { message in
                                MessageView(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding()
                    }
                    .background(Color(.systemGroupedBackground))
                    .onChange(of: messages.count) { _ in
                        if let lastID = messages.last?.id {
                            withAnimation {
                                proxy.scrollTo(lastID, anchor: .bottom)
                            }
                        }
                    }
                }
                
                HStack(alignment: .bottom, spacing: 8) {
                    TextField("Input message", text: $text, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(1...4)
                    
                    Button(action: sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle().fill(Color.blue)
                            )
                    }
                }
                .padding()
                .background(Color(.systemBackground))
            }
        }
    }
    
    private func sendMessage() {
        guard !text.isEmpty else {
            return
        }
        
        messages.append(Message(role: "user", content: text))
        
        Task {
            let output = await llmClient.responses(messages: messages)
            let message = Message(role: "assistant", content: output)
            messages.append(message)
            
            ttsClient.synthesize(text: output, rate: 0.5)
        }
        text = ""
    }
}

struct MessageView: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.role == "user" {
                Spacer(minLength: 40)
                                
                Text(message.content)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            } else {
                Text(message.content)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(.secondarySystemBackground))
                    .foregroundStyle(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                
                Spacer(minLength: 40)
            }
        }
    }
}

#Preview {
    ContentView()
}
