//
//  ASRClient.swift
//  LocalSpokenDialogue
//
//  Created by Kosuke Mori on 2026/03/20.
//

import Foundation
import Speech
import AVFAudio
import Combine

@MainActor
final class ASRClient: ObservableObject {
    @Published var transcript: String = ""
    @Published var finalTranscript: String = ""
    @Published var useOnDeviceRecognition: Bool = false
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    init() {
        useOnDeviceRecognition = speechRecognizer?.supportsOnDeviceRecognition ?? false
    }
    
    func requestAuthorization() {
        
        Task {
            let speechStatus = await requestSpeechRecognitionAuthorization()
            guard speechStatus == .authorized else {
                return
            }
            
            let microphoneStatus = await requestMicrophoneAuthorization()
            guard microphoneStatus else {
                return
            }
        }
    }
    
    private func requestSpeechRecognitionAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }
    
    private func requestMicrophoneAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
    
    func start() {
        
        stop()
        
        guard let speechRecognizer else {
            return
        }
        
        guard speechRecognizer.isAvailable else {
            return
        }
        
        // recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest else {
            return
        }
        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = useOnDeviceRecognition
        
        // recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, _ in
            guard let self else { return }
            
            if let result {
                self.transcript = result.bestTranscription.formattedString
            }
            
            if result?.isFinal == true {
                self.finalTranscript = self.transcript
                stop()
            }
        }
    }
    
    func stop() {
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.finish()
        recognitionTask = nil

    }
    
    func clear() {
        transcript = ""
        finalTranscript = ""
    }
    
    func append(_ buffer: AVAudioPCMBuffer) {
        recognitionRequest?.append(buffer)
    }
}
