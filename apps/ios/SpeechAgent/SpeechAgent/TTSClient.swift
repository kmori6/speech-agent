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
        // https://developer.apple.com/documentation/avfoundation/speech-synthesis
        let utt = AVSpeechUtterance(string: text)
        utt.rate = rate
        
        let voice = AVSpeechSynthesisVoice(language: "ja-JP")
        utt.voice = voice
        synthesizer.speak(utt)
    }
}
