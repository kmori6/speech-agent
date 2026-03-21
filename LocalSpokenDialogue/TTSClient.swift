//
//  TTSClient.swift
//  SpeechAgent
//
//  Created by Kosuke Mori on 2026/03/20.
//

import Foundation
import Combine
import AVFAudio

final class TTSClient {
    private let synthesizer = AVSpeechSynthesizer()
    
    func synthesize(text: String, rate: Float) {
        
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: .duckOthers)
            try session.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print(error)
        }
        
        // https://developer.apple.com/documentation/avfoundation/speech-synthesis
        let utt = AVSpeechUtterance(string: text)
        utt.rate = rate
        
        let voice = AVSpeechSynthesisVoice(language: "ja-JP")
        utt.voice = voice
        synthesizer.speak(utt)
    }
}
