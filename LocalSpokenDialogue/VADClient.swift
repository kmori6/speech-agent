//
//  VADClient.swift
//  LocalSpokenDialogue
//
//  Created by Kosuke Mori on 2026/03/24.
//

import Foundation
import OnnxRuntimeBindings

final class VADClient {
    private var session: ORTSession?
    private var state: [Float] = Array(repeating: 0, count: 2 * 1 * 128)

    func load() throws {
        let modelURL = Bundle.main.url(
            forResource: "silero_vad_op18_ifless",
            withExtension: "onnx"
        )!
        
        let env = try ORTEnv(loggingLevel: .warning)
        let options = try ORTSessionOptions()
        try options.setIntraOpNumThreads(1)
        session = try ORTSession(
            env: env,
            modelPath: modelURL.path,
            sessionOptions: options
        )
    }

    func reset() {
        state = Array(repeating: 0, count: 2 * 1 * 128)
    }
}
