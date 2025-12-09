//
//  QuestionRowViewModel.swift
//  AINotes
//
//  Created by Simon Sung on 11/25/25.
//

import Foundation
import Combine
import AVFoundation
import CoreData

class QuestionRowViewModel: ObservableObject {
    let question: QuestionsEntity
    @Published var isDetecting = false
    @Published var displayTranscript = ""
    @Published var canSendAudio = false
    @Published var isRecordingStarted = false
    @Published var isSummarizing = false
    @Published var summary = ""
    @Published var isReviewing = false
    @Published var review = ""
    @Published var score: Double = 0.0
    @Published var selectedTab = 0
    
    private let wsManager = WebSocketManager()
    private let recordingManager = RecordingManager()
    private let summarizeManager = SummarizeManager()
    private let reviewManager = ReviewManager()
    private var cancellables = Set<AnyCancellable>()
    
    init(question: QuestionsEntity) {
        self.question = question
        print("QuestionRowViewModel: init for question \(question.id?.uuidString ?? "unknown")")

        if let savedAnswer = question.answer, !savedAnswer.isEmpty {
            self.displayTranscript = savedAnswer
            print("QuestionRowViewModel: Init loaded answer (len: \(savedAnswer.count))")
        } else {
            print("QuestionRowViewModel: Init found NO saved answer")
        }

        if let savedSummary = question.summary, !savedSummary.isEmpty {
            self.summary = savedSummary
        }

        if let savedReview = question.review, !savedReview.isEmpty {
            self.review = savedReview

            if let savedScore = question.value(forKey: "score") as? Double {
                self.score = savedScore
            } else if let savedScore = question.value(forKey: "score") as? Int16 {
                self.score = Double(savedScore)
            } else {
                self.score = 0.0
            }
        }
        setupObservers()
    }
    
    deinit {
        print("QuestionRowViewModel: deinit for question \(question.id?.uuidString ?? "unknown")")
    }
    
    private func setupObservers() {

        wsManager.$transcript
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newTranscript in
                guard let self = self else { return }

                if newTranscript.isEmpty && self.wsManager.fullTranscript.isEmpty && !self.isDetecting && !self.displayTranscript.isEmpty {
                    return
                }
                self.updateDisplayTranscript()
            }
            .store(in: &cancellables)
        
        wsManager.$fullTranscript
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newFullTranscript in
                guard let self = self else { return }

                if newFullTranscript.isEmpty && self.wsManager.transcript.isEmpty && !self.isDetecting && !self.displayTranscript.isEmpty {
                    return
                }
                self.updateDisplayTranscript()
            }
            .store(in: &cancellables)
        
        wsManager.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                print("QuestionRowViewModel: isConnected changed to \(connected)")
                self?.handleConnectionChange(connected: connected)
            }
            .store(in: &cancellables)
        
        summarizeManager.$isSummarizing
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] isSummarizing in
                guard let self = self else { return }
                print("QuestionRowViewModel: Received isSummarizing update: \(isSummarizing) (current: \(self.isSummarizing))")
                if self.isSummarizing != isSummarizing {
                    self.isSummarizing = isSummarizing
                    print("QuestionRowViewModel: Set isSummarizing to: \(self.isSummarizing)")
                    self.objectWillChange.send()
                }
            }
            .store(in: &cancellables)
        
        summarizeManager.$summary
            .receive(on: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] summary in
                guard let self = self else { return }
                print("QuestionRowViewModel: Received summary update (length: \(summary.count), current: \(self.summary.count))")
                
                if summary.isEmpty && !self.summary.isEmpty {
                    print("QuestionRowViewModel: Ignoring empty summary update (preserving existing data)")
                    return
                }
                
                if self.summary != summary {
                    self.summary = summary
                    print("QuestionRowViewModel: Set summary to: '\(self.summary)'")
                    
                    if !summary.isEmpty {
                        print("QuestionRowViewModel: Saving summary to Core Data...")
                        self.question.summary = summary
                        self.question.parentNote?.modifiedDate = Date()
                        
                    do {
                        if NotesDataController.shared.viewContext.hasChanges {
                            print("QuestionRowViewModel: Context has changes, saving...")
                            try NotesDataController.shared.viewContext.save()
                            NotesDataController.shared.viewContext.processPendingChanges()
                            print("QuestionRowViewModel: Summary saved successfully.")
                        } else {
                            print("QuestionRowViewModel: No changes detected when saving summary.")
                        }
                    } catch {
                        print("QuestionRowViewModel: Failed to save summary: \(error)")
                        print("QuestionRowViewModel: Error details: \(error.localizedDescription)")
                    }
                    }
                    
                    self.objectWillChange.send()
                }
            }
            .store(in: &cancellables)

        reviewManager.$isReviewing
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isReviewing in
                self?.isReviewing = isReviewing
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
            
        reviewManager.$review
            .receive(on: DispatchQueue.main)
            .sink { [weak self] review in
                guard let self = self else { return }
                
                if review.isEmpty && !self.review.isEmpty {
                    print("QuestionRowViewModel: Ignoring empty review update (preserving existing data)")
                    return
                }
                
                self.review = review
                if !review.isEmpty {
                    self.question.review = review

                    self.question.setValue(self.reviewManager.score, forKey: "score")
                    self.score = self.reviewManager.score
                    
                    do {
                        if NotesDataController.shared.viewContext.hasChanges {
                            print("QuestionRowViewModel: Context has changes, saving review...")
                            try NotesDataController.shared.viewContext.save()
                            NotesDataController.shared.viewContext.processPendingChanges()
                            print("QuestionRowViewModel: Review saved successfully.")
                        } else {
                            print("QuestionRowViewModel: No changes detected when saving review.")
                        }
                    } catch {
                         print("QuestionRowViewModel: Failed to save review: \(error)")
                         print("QuestionRowViewModel: Error details: \(error.localizedDescription)")
                    }
                }
                self.objectWillChange.send()
            }
            .store(in: &cancellables)
            
        reviewManager.$score
            .receive(on: DispatchQueue.main)
            .sink { [weak self] score in
                guard let self = self else { return }
                
                if score == 0 && self.reviewManager.review.isEmpty && self.score != 0 {
                     print("QuestionRowViewModel: Ignoring initial score update (preserving existing score)")
                     return
                }
                
                self.score = score
                self.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
    
    func updateDisplayTranscript() {
        let combined = (wsManager.fullTranscript + wsManager.transcript).trimmingCharacters(in: .whitespacesAndNewlines)
        displayTranscript = combined
    }
    
    func toggleDetection() {
        if isDetecting {
            stopDetection()
        } else {
            startDetection()
        }
    }

    /// 清除已存的 transcript / summary / review / score，並保存到 Core Data
    func clearStoredDetectionData() {
        print("QuestionRowViewModel: Clearing stored detection data for question \(question.id?.uuidString ?? "unknown")")
        
        // 清空 Core Data 屬性
        question.answer = nil
        question.summary = nil
        question.review = nil
        question.setValue(0.0, forKey: "score")
        question.parentNote?.modifiedDate = Date()
        
        // 清空本地狀態
        displayTranscript = ""
        summary = ""
        review = ""
        score = 0.0
        
        let context = NotesDataController.shared.viewContext
        do {
            if context.hasChanges {
                print("QuestionRowViewModel: Context has changes, saving cleared detection data...")
                try context.save()
                context.processPendingChanges()
                print("QuestionRowViewModel: Cleared detection data saved successfully.")
            } else {
                print("QuestionRowViewModel: No changes detected when clearing detection data.")
            }
        } catch {
            print("QuestionRowViewModel: Failed to save cleared detection data: \(error)")
        }
    }

    /// 用於「重新偵測」：先清除舊資料，再開始新的偵測
    func restartDetectionAfterReset() {
        clearStoredDetectionData()
        startDetection()
    }
    
    func startDetection() {
        AVAudioApplication.requestRecordPermission { [weak self] allowed in
            guard allowed, let self = self else {
                print("Microphone permission denied")
                return
            }
            
            DispatchQueue.main.async {
                print("QuestionRowViewModel: Starting detection")
                self.isDetecting = true
                self.isRecordingStarted = false
                self.displayTranscript = ""
                self.canSendAudio = false
                self.wsManager.resetFullTranscript()
                self.summarizeManager.reset()
                self.reviewManager.reset()
                self.summary = ""
                self.review = ""
                self.score = 0.0
                
                self.wsManager.connect()

                self.updateDisplayTranscript()
            }
        }
    }
    
    func stopDetection() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.isDetecting = false
            self.isRecordingStarted = false
            self.canSendAudio = false
            self.recordingManager.stopRecording()
            
            let finalTranscript = (self.wsManager.fullTranscript + self.wsManager.transcript).trimmingCharacters(in: .whitespacesAndNewlines)
            
            print("QuestionRowViewModel: stopDetection - finalTranscript: '\(finalTranscript)' (length: \(finalTranscript.count))")
            
            self.wsManager.disconnect()
            
            self.displayTranscript = finalTranscript
            print("QuestionRowViewModel: displayTranscript set to '\(self.displayTranscript)'")
            
            if !finalTranscript.isEmpty {
                self.question.answer = finalTranscript
                self.question.parentNote?.modifiedDate = Date()
                
                do {
                    if NotesDataController.shared.viewContext.hasChanges {
                         print("QuestionRowViewModel: Context has changes, saving transcript...")
                         try NotesDataController.shared.viewContext.save()
                         NotesDataController.shared.viewContext.processPendingChanges()
                         print("QuestionRowViewModel: Transcript saved successfully.")
                    } else {
                        print("QuestionRowViewModel: No changes detected when saving transcript.")
                    }
                } catch {
                    print("QuestionRowViewModel: Failed to save transcript: \(error)")
                    print("QuestionRowViewModel: Error details: \(error.localizedDescription)")
                }

                print("QuestionRowViewModel: Calling summarizeTranscript...")
                self.summarizeManager.summarizeTranscript(finalTranscript)

                if let questionText = self.question.question, !questionText.isEmpty {
                    self.reviewManager.reviewAnswer(question: questionText, transcript: finalTranscript)
                }
            } else {
                print("QuestionRowViewModel: stopDetection - finalTranscript is empty, skipping summarization")
            }
        }
    }
    
    private func handleConnectionChange(connected: Bool) {
        if connected {
            print("QuestionRowViewModel: WebSocket connected, starting recording...")
            canSendAudio = true
            updateDisplayTranscript()
            if isDetecting && !isRecordingStarted {
                print("QuestionRowViewModel: Starting recording...")
                isRecordingStarted = true
                recordingManager.startRecording { [weak self] audioData in
                    guard let self = self else { return }
                    if self.canSendAudio {
                        print("QuestionRowViewModel: Sending audio chunk, size: \(audioData.count) bytes")
                        self.wsManager.sendAudioChunk(audioData)
                    }
                }
                print("QuestionRowViewModel: Recording started")
            } else {
                print("QuestionRowViewModel: Not starting recording - isDetecting: \(isDetecting), isRecordingStarted: \(isRecordingStarted)")
            }
        } else {
            print("QuestionRowViewModel: WebSocket disconnected")
            canSendAudio = false
        }
    }
}
