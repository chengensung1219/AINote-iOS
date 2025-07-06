//
//  AudioManager.swift
//  AINotes
//
//  Created by Simon Sung on 7/5/25.
//

import SwiftUI
import AVFoundation
import Combine

class AudioManager: NSObject, ObservableObject, AVAudioRecorderDelegate {
    
    @Published var isRecording: Bool = false
    @Published var audios: [URL] = []
    
    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    
    private var recordingsFolder: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default)
            try session.setActive(true)
            
            let filename = "Record_\(audios.count + 1).m4a"
            let url = recordingsFolder.appendingPathComponent(filename)
            
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 12000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.delegate = self
            audioRecorder?.record()
            isRecording = true
        } catch {
            print("Error: \(error)")
        }
    }
    
    func stopRecording() {
        audioRecorder?.stop()
        isRecording = false
        fetchAudioFiles()
    }
    
    func fetchAudioFiles() {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: recordingsFolder, includingPropertiesForKeys: nil)
            audios = contents
                .filter { $0.pathExtension == "m4a" }
                .sorted(by: { $0.lastPathComponent > $1.lastPathComponent })
        } catch {
            print("Error: \(error)")
        }
    }
    
    func play(url: URL) {
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {
            print("Error: \(error)")
        }
    }
    
    func delete(url: URL) {
        do {
            try FileManager.default.removeItem(at: url)
            fetchAudioFiles()
        } catch {
            print("Error: \(error)")
        }
    }
}

