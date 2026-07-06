import Foundation
import WhisperKit

/// Wraps WhisperKit: loads a model (downloading it on first use) and turns
/// 16 kHz mono float audio into text. Everything runs on-device.
actor Transcriber {
    private var whisperKit: WhisperKit?
    private var loadedModelID: String?

    var isReady: Bool { whisperKit != nil }

    /// Loads the given model variant, downloading it from the WhisperKit
    /// model repo the first time. No-op if it's already loaded.
    func load(modelID: String) async throws {
        if loadedModelID == modelID, whisperKit != nil { return }

        // Release the old model before loading the new one.
        whisperKit = nil
        loadedModelID = nil

        let config = WhisperKitConfig(
            model: modelID,
            verbose: false,
            prewarm: true
        )
        let pipeline = try await WhisperKit(config)
        whisperKit = pipeline
        loadedModelID = modelID
    }

    func unload() {
        whisperKit = nil
        loadedModelID = nil
    }

    func transcribe(_ audio: [Float]) async throws -> String {
        guard let whisperKit else { throw WhisperKeyError.modelNotLoaded }
        let results = try await whisperKit.transcribe(audioArray: audio)
        return results.map(\.text).joined(separator: " ")
    }
}
