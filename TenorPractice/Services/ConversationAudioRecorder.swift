@preconcurrency import AVFoundation
import Foundation
@preconcurrency import LiveKitWebRTC

/// Mixes local and remote WebRTC PCM into one AAC file, preserving pauses
/// between turns. The practice mic is gated, so the two sides rarely overlap.
final class ConversationAudioRecorder: NSObject, LKRTCAudioRenderer, @unchecked Sendable {
    let fileURL: URL

    private let queue = DispatchQueue(label: "logos.conversation.recorder")
    private var file: AVAudioFile?
    private var startedAt: Date?
    private var converter: AVAudioConverter?
    private var converterInputFormat: AVAudioFormat?
    private var didWriteAudio = false

    override init() {
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("logos-\(UUID().uuidString).m4a")
        super.init()

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 24_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 64_000
        ]

        file = try? AVAudioFile(
            forWriting: fileURL,
            settings: settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false
        )
    }

    func render(pcmBuffer: AVAudioPCMBuffer) {
        queue.async { [weak self] in
            self?.append(pcmBuffer)
        }
    }

    func finish() -> URL? {
        queue.sync {
            file = nil
            converter = nil
            guard didWriteAudio, FileManager.default.fileExists(atPath: fileURL.path) else {
                try? FileManager.default.removeItem(at: fileURL)
                return nil
            }
            return fileURL
        }
    }

    private func append(_ incoming: AVAudioPCMBuffer) {
        guard let file, incoming.frameLength > 0 else { return }
        guard let converted = convert(incoming), converted.frameLength > 0 else { return }

        if startedAt == nil { startedAt = Date() }
        guard let startedAt else { return }

        let sampleRate = file.processingFormat.sampleRate
        let targetFrame = AVAudioFramePosition(Date().timeIntervalSince(startedAt) * sampleRate)
            - AVAudioFramePosition(converted.frameLength)
        let gap = targetFrame - file.framePosition
        if gap > 240 {
            let cap = AVAudioFramePosition(sampleRate * 12)
            writeSilence(frameCount: AVAudioFrameCount(min(gap, cap)), to: file)
        }

        do {
            try file.write(from: converted)
            didWriteAudio = true
        } catch {
            return
        }
    }

    private func convert(_ incoming: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let file else { return nil }
        let target = file.processingFormat
        if formatsMatch(incoming.format, target) { return incoming }

        if converter == nil || converterInputFormat.map({ !formatsMatch($0, incoming.format) }) == true {
            converter = AVAudioConverter(from: incoming.format, to: target)
            converterInputFormat = incoming.format
        }
        guard let converter else { return nil }

        let ratio = target.sampleRate / incoming.format.sampleRate
        let capacity = AVAudioFrameCount(Double(incoming.frameLength) * ratio) + 64
        guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: max(capacity, 1)) else {
            return nil
        }

        var error: NSError?
        var consumed = false
        let status = converter.convert(to: output, error: &error) { _, outStatus in
            if consumed {
                outStatus.pointee = .noDataNow
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return incoming
        }
        guard status != .error, error == nil else { return nil }
        return output
    }

    private func writeSilence(frameCount: AVAudioFrameCount, to file: AVAudioFile) {
        guard frameCount > 0 else { return }
        let chunkSize: AVAudioFrameCount = 4_800
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: chunkSize) else {
            return
        }
        var remaining = frameCount
        while remaining > 0 {
            let count = min(remaining, chunkSize)
            buffer.frameLength = count
            if let channels = buffer.floatChannelData {
                for channel in 0..<Int(buffer.format.channelCount) {
                    memset(channels[channel], 0, Int(count) * MemoryLayout<Float>.size)
                }
            }
            try? file.write(from: buffer)
            remaining -= count
        }
    }

    private func formatsMatch(_ lhs: AVAudioFormat, _ rhs: AVAudioFormat) -> Bool {
        lhs.sampleRate == rhs.sampleRate
            && lhs.channelCount == rhs.channelCount
            && lhs.commonFormat == rhs.commonFormat
            && lhs.isInterleaved == rhs.isInterleaved
    }
}