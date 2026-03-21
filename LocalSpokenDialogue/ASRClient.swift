//
//  ASRClient.swift
//  SpeechAgent
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
    @Published var isRecording: Bool = false
    
    @Published var useOnDeviceRecognition: Bool = false
    @Published var supportsOnDeviceRecognition: Bool = false
    
    private let audioEngine = AVAudioEngine()
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    
    init() {
        supportsOnDeviceRecognition = speechRecognizer?.supportsOnDeviceRecognition ?? false
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
    
    func startRecognition() {
        
        stopRecognition()
        
        guard let speechRecognizer else {
            return
        }
        
        guard speechRecognizer.isAvailable else {
            return
        }
        
        do {
            // record session
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
            // recognition request
            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest else {
                return
            }
            recognitionRequest.shouldReportPartialResults = true
            recognitionRequest.requiresOnDeviceRecognition = useOnDeviceRecognition
            
            // input node
            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }
            
            // recognition task
            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, _ in
                guard let self else { return }
                
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                }
                
                if result?.isFinal == true {
                    self.finalTranscript = self.transcript
                    stopRecognition()
                }
            }
            
            // start audioEngine
            audioEngine.prepare()
            try audioEngine.start()
            
            isRecording = true
            
        } catch {
            stopRecognition()
        }
    }
    
    func stopRecognition() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.finish()
        recognitionTask = nil
        
        isRecording = false
        
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            return
        }
    }
    
    func clearTranscript() {
        transcript = ""
        finalTranscript = ""
    }
}
