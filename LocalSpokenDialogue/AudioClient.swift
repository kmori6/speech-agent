//
//  AudioClient.swift
//  LocalSpokenDialogue
//
//  Created by Kosuke Mori on 2026/03/25.
//

import Foundation
import AVFoundation
import Combine

final class AudioClient: ObservableObject {

    private let engine = AVAudioEngine()
    private let audioQueue = DispatchQueue(label: "vad.audio.queue")
    
    private let vadClient = VADClient()
    private let asrClient: ASRClient
    
    private var vadConverter: AVAudioConverter?
    private let vadOutputFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 16_000,
        channels: 1,
        interleaved: false
    )!
    
    private var vadInputBuffer: [Float] = []
    private var consecutiveSilenceCount = 0
    private let endCount = 6  // 32 * 6 = 192ms
    private let startThreshold: Float = 0.5
    private let endThreshold: Float = 0.35
    
    // state
    private var isSpeaking = false
    @Published private(set) var isRecording = false
    
    init(asrClient: ASRClient) {
        self.asrClient = asrClient
    }

    func start() async throws {
        guard !isRecording else { return }

        try vadClient.load()

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(
            .playAndRecord,
            mode: .measurement,
            options: [.defaultToSpeaker]
        )
        try session.setPreferredSampleRate(16_000)
        try session.setActive(true)
        
        let inputNode = engine.inputNode
        let inputFormat = inputNode.outputFormat(forBus: 0)
        vadConverter = AVAudioConverter(from: inputFormat, to: vadOutputFormat)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }

            audioQueue.async {
                self.process(buffer)
            }
        }

        do {
            try engine.start()
            isRecording = true
        } catch {
            inputNode.removeTap(onBus: 0)
            vadConverter = nil
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            throw error
        }
    }
    
    func stop() {
        guard isRecording else { return }

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        vadClient.reset()
        vadConverter = nil
        vadInputBuffer.removeAll()
        isSpeaking = false
        consecutiveSilenceCount = 0
        isRecording = false

        Task { @MainActor [asrClient] in
            asrClient.stop()
        }

        do {
            try AVAudioSession.sharedInstance().setActive(
                false,
                options: .notifyOthersOnDeactivation
            )
        } catch {
            return
        }
    }

    private func process(_ buffer: AVAudioPCMBuffer) {
        let vadSamples = convertTo16kMonoFloatArray(buffer)
        guard !vadSamples.isEmpty else { return }

        vadInputBuffer.append(contentsOf: vadSamples)

        var latestProb: Float?

        while vadInputBuffer.count >= 512 {
            let chunk = Array(vadInputBuffer.prefix(512))
            vadInputBuffer.removeFirst(512)

            do {
                latestProb = try vadClient.predict(audio: chunk)
            } catch {
                return
            }
        }

        guard let prob = latestProb else { return }

        var shouldStartRecognition = false
        var shouldStopRecognition = false

        if prob >= startThreshold {
            // silence -> utt
            if !isSpeaking {
                shouldStartRecognition = true
            }
            isSpeaking = true
            consecutiveSilenceCount = 0
        } else if prob <= endThreshold {
            consecutiveSilenceCount += 1
        }
        
        // utt -> silence
        if isSpeaking && consecutiveSilenceCount >= endCount {
            isSpeaking = false
            consecutiveSilenceCount = 0
            shouldStopRecognition = true
        }

        if shouldStopRecognition {
            Task { @MainActor [asrClient] in
                asrClient.stop()
            }
            return
        }
        
        // push pcm buffer to asr
        if isSpeaking {
            Task { @MainActor [asrClient] in
                if shouldStartRecognition {
                    asrClient.start()
                }
                asrClient.append(buffer)
            }
        }
    }
    
    private func convertTo16kMonoFloatArray(_ buffer: AVAudioPCMBuffer) -> [Float] {
        guard buffer.frameLength > 0 else { return [] }

        if buffer.format.sampleRate == 16_000,
            buffer.format.channelCount == 1,
            buffer.format.commonFormat == .pcmFormatFloat32,
            !buffer.format.isInterleaved,
            let ptr = buffer.floatChannelData?.pointee {
                return Array(UnsafeBufferPointer(start: ptr, count: Int(buffer.frameLength)))
            }

          guard let vadConverter else { return [] }

          let outFrameCapacity = AVAudioFrameCount(
              ceil(Double(buffer.frameLength) * 16_000 / buffer.format.sampleRate)
          )

          guard let outBuffer = AVAudioPCMBuffer(
              pcmFormat: vadOutputFormat,
              frameCapacity: outFrameCapacity
          ) else {
              return []
          }

          var supplied = false
          var error: NSError?
          let status = vadConverter.convert(to: outBuffer, error: &error) { _, outStatus in
              if supplied {
                  outStatus.pointee = .noDataNow
                  return nil
              }
              supplied = true
              outStatus.pointee = .haveData
              return buffer
          }

          guard error == nil,
                status != .error,
                outBuffer.frameLength > 0,
                let ptr = outBuffer.floatChannelData?.pointee else {
              return []
          }

          return Array(UnsafeBufferPointer(start: ptr, count: Int(outBuffer.frameLength)))
      }
}
