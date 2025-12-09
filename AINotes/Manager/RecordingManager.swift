//
//  RecordingManager.swift
//  AINotes
//
//  Created by Simon Sung on 10/20/25.
//

import SwiftUI
import AVFoundation
import Combine

class RecordingManager: NSObject, ObservableObject {
    
    @Published var isRecording: Bool = false

    private var audioEngine: AVAudioEngine?
    private var audioFormat: AVAudioFormat?
    private var inputNode: AVAudioInputNode?
    private var audioBufferHandler: ((Data) -> Void)?
    
    func startRecording(_ bufferHandler: @escaping (Data) -> Void) {
        stopRecording()
        
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.record, mode: .default)
            try session.setActive(true)
        } catch {
            print("Failed to set up AVAudioSession: \(error)")
            return
        }
        
        let engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        
        do {
            try engine.start()
            print("AVAudioEngine started for streaming.")
        } catch {
            print("Failed to start AVAudioEngine: \(error)")
            return
        }
        
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self = self else { return }
            
            if let pcmData = self.convertBufferToPCM16Mono16k(buffer: buffer, inputFormat: format) {
                bufferHandler(pcmData)
            }
        }
        
        self.audioEngine = engine
        self.inputNode = input
        self.audioFormat = format
        self.audioBufferHandler = bufferHandler
        self.isRecording = true
    }
    
    func stopRecording() {
        if let input = inputNode {
            input.removeTap(onBus: 0)
        }
        
        audioEngine?.stop()
        
        audioEngine = nil
        inputNode = nil
        audioFormat = nil
        audioBufferHandler = nil
        
        self.isRecording = false
        
        print("AVAudioEngine stopped.")
    }
    
    func getFormat() -> AVAudioFormat? {
        return self.audioFormat
    }
    
    func convertBufferToPCM16Mono16k(buffer: AVAudioPCMBuffer, inputFormat: AVAudioFormat) -> Data? {

        guard let targetFormat = AVAudioFormat(commonFormat: .pcmFormatInt16,
                                               sampleRate: 16000,
                                               channels: 1,
                                               interleaved: true) else { return nil }
        
        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else { return nil }
        
        guard let outBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: AVAudioFrameCount(CGFloat(buffer.frameLength) * 16000.0 / inputFormat.sampleRate)) else { return nil }
        
        var error: NSError?
        
        let status = converter.convert(to: outBuffer, error: &error) { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }
        
        guard status == .haveData || status == .inputRanDry else { return nil }
        
        let audioBuffer = outBuffer.int16ChannelData![0]
        let audioData = Data(bytes: audioBuffer, count: Int(outBuffer.frameLength) * 2)
        return audioData
    }
}
