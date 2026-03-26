//
//  ContentView.swift
//  LocalSpokenDialogue
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
    @State private var messages: [Message] = []
    @StateObject private var asrClient: ASRClient
    @StateObject private var audioClient: AudioClient
    @StateObject private var llmClient = LLMClient()
    private let ttsClient = TTSClient()
    
    init() {
        let asr = ASRClient()
        _asrClient = StateObject(wrappedValue: asr)
        _audioClient = StateObject(wrappedValue: AudioClient(asrClient: asr))
    }
    
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
                    .onChange(of: messages.count) {
                        if let lastID = messages.last?.id {
                            withAnimation {
                                proxy.scrollTo(lastID, anchor: .bottom)
                            }
                        }
                    }
                }
                
                HStack(alignment: .bottom, spacing: 8) {
                    TextField("Input message", text: $asrClient.transcript, axis: .vertical)
                        .lineLimit(1...4)
                    
                    Button(action: {
                        if audioClient.isRecording {
                            audioClient.stop()
                        } else {
                            Task {
                                do {
                                    try await audioClient.start()
                                } catch {
                                    print(error)
                                }
                            }
                        }
                    }) {
                        Image(systemName: audioClient.isRecording ? "stop.fill" : "mic.fill")
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
        .onAppear {
            asrClient.requestAuthorization()
            Task {
                await llmClient.load()
            }
        }
        .onDisappear {
            audioClient.stop()
        }
        .onChange(of: asrClient.finalTranscript) { _, newValue in
            let text = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return }
            messages.append(Message(role: "user", content: text))
            asrClient.clear()
            
            Task {
                let message = await llmClient.generate(text: text)
                messages.append(message)
                ttsClient.synthesize(text: message.content, rate: 0.5)
            }
        }
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
