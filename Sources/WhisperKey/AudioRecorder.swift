import AVFoundation

/// Captures microphone audio and accumulates it as 16 kHz mono Float32
/// samples — the format Whisper expects.
final class AudioRecorder {
    /// Reports a rough input level (0...1) for the recording indicator.
    var onLevel: ((Float) -> Void)?

    private let engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private var samples: [Float] = []
    private let lock = NSLock()

    static let sampleRate: Double = 16_000

    var isRecording: Bool { engine.isRunning }

    func start() throws {
        lock.lock()
        samples.removeAll(keepingCapacity: true)
        lock.unlock()

        let input = engine.inputNode
        let inputFormat = input.outputFormat(forBus: 0)

        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw WhisperKeyError.noMicrophone
        }

        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: Self.sampleRate,
            channels: 1,
            interleaved: false
        ), let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw WhisperKeyError.audioSetupFailed
        }
        self.converter = converter

        input.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
            self?.process(buffer: buffer, targetFormat: targetFormat)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            throw WhisperKeyError.audioSetupFailed
        }
    }

    /// Stops capture and returns everything recorded since `start()`.
    func stop() -> [Float] {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        converter = nil

        lock.lock()
        defer { lock.unlock() }
        return samples
    }

    /// Stops capture and discards the audio.
    func cancel() {
        _ = stop()
        lock.lock()
        samples.removeAll()
        lock.unlock()
    }

    private func process(buffer: AVAudioPCMBuffer, targetFormat: AVAudioFormat) {
        guard let converter else { return }

        let ratio = targetFormat.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 16
        guard let out = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: capacity) else { return }

        var consumed = false
        let inputBlock: AVAudioConverterInputBlock = { _, outStatus in
            if consumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return buffer
        }

        var conversionError: NSError?
        converter.convert(to: out, error: &conversionError, withInputFrom: inputBlock)
        guard conversionError == nil, let channelData = out.floatChannelData else { return }

        let frameCount = Int(out.frameLength)
        guard frameCount > 0 else { return }
        let chunk = Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))

        lock.lock()
        samples.append(contentsOf: chunk)
        lock.unlock()

        // RMS level, scaled so normal speech fills most of the meter.
        let sumOfSquares = chunk.reduce(Float(0)) { $0 + $1 * $1 }
        let rms = (sumOfSquares / Float(frameCount)).squareRoot()
        let level = min(1, rms * 12)
        DispatchQueue.main.async { [weak self] in
            self?.onLevel?(level)
        }
    }
}

enum WhisperKeyError: LocalizedError {
    case noMicrophone
    case audioSetupFailed
    case modelNotLoaded

    var errorDescription: String? {
        switch self {
        case .noMicrophone: return "No microphone found"
        case .audioSetupFailed: return "Couldn't start audio capture"
        case .modelNotLoaded: return "Speech model isn't loaded yet"
        }
    }
}
