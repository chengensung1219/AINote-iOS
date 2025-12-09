//
//  QuestionRowView.swift
//  AINotes
//
//  Created by Simon Sung on 11/25/25.
//

import SwiftUI
import CoreData

struct QuestionRowView: View {
    let question: QuestionsEntity
    @StateObject private var viewModel: QuestionRowViewModel
    @State private var isExpanded = false
    @State private var showRedetectAlert = false
    
    init(question: QuestionsEntity) {
        self.question = question
        _viewModel = StateObject(wrappedValue: QuestionRowViewModel(question: question))
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button(action: {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundColor(.secondary)
                        .frame(width: 20, height: 20)
                }
                
                Text(question.question ?? "")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        withAnimation {
                            isExpanded.toggle()
                        }
                    }
                
                Button(action: {
                    if viewModel.isDetecting {
                        // 目前正在偵測時，直接停止即可
                        viewModel.toggleDetection()
                    } else {
                        // 尚未偵測，但已經有 transcript / summary / review，其一非空時，先詢問是否重新偵測
                        if !viewModel.displayTranscript.isEmpty || !viewModel.summary.isEmpty || !viewModel.review.isEmpty {
                            showRedetectAlert = true
                        } else {
                            viewModel.toggleDetection()
                        }
                    }
                }) {
                    Image(systemName: viewModel.isDetecting ? "stop.circle.fill" : "person.wave.2.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(viewModel.isDetecting ? .red : .blue)
                }
            }
            .padding()
            .background(Color.blue.opacity(0.2))
            .cornerRadius(8)
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Transcript:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    let transcriptText = viewModel.isDetecting 
                        ? (viewModel.displayTranscript.isEmpty ? "Listening..." : viewModel.displayTranscript)
                        : (viewModel.displayTranscript.isEmpty ? "Not detected or recorded yet." : viewModel.displayTranscript)
                    
                    Text(transcriptText)
                        .font(.subheadline)
                        .foregroundColor(viewModel.displayTranscript.isEmpty && !viewModel.isDetecting ? .secondary : .primary)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                }
                .padding(.horizontal)
                
                Picker("Select View", selection: $viewModel.selectedTab) {
                    Text("Summary").tag(0)
                    Text("Review").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                
                if viewModel.selectedTab == 0 {
                    if viewModel.isSummarizing {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Summarizing...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                        .padding(.horizontal)
                    } else {
                        let summaryText = viewModel.summary.isEmpty ? "No summary available yet." : viewModel.summary
                        ScrollView {
                            Text(summaryText)
                                .font(.subheadline)
                                .foregroundColor(viewModel.summary.isEmpty ? .secondary : .primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: 200)
                        .padding(8)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(6)
                        .padding(.horizontal)
                    }
                }

                else if viewModel.selectedTab == 1 {
                    if viewModel.isReviewing {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Analyzing answer...")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                        .padding(.horizontal)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Score:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                if viewModel.review.isEmpty {
                                    Text("--/10")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                } else {
                                    Text(String(format: "%.1f/10", viewModel.score))
                                        .font(.headline)
                                        .foregroundColor(viewModel.score >= 7 ? .green : (viewModel.score >= 4 ? .orange : .red))
                                }
                            }
                            
                            Text("Feedback:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            let reviewText = viewModel.review.isEmpty ? "No review available yet." : viewModel.review
                            
                            ScrollView {
                                Text(reviewText)
                                    .font(.subheadline)
                                    .foregroundColor(viewModel.review.isEmpty ? .secondary : .primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: 200)
                        }
                        .padding(8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                        .padding(.horizontal)
                    }
                }
            }
        }
        .onAppear {
            if let savedAnswer = question.answer, !savedAnswer.isEmpty {
                viewModel.displayTranscript = savedAnswer
            }
            if let savedSummary = question.summary, !savedSummary.isEmpty {
                viewModel.summary = savedSummary
            }
            if let savedReview = question.review, !savedReview.isEmpty {
                viewModel.review = savedReview
                if let savedScore = question.value(forKey: "score") as? Double {
                    viewModel.score = savedScore
                } else {
                    viewModel.score = 0.0
                }
            }
            
            if !viewModel.displayTranscript.isEmpty || !viewModel.summary.isEmpty || !viewModel.review.isEmpty {
                isExpanded = true
            }
        }
        .onChange(of: viewModel.isDetecting) { _, isDetecting in
            if isDetecting {
                withAnimation {
                    isExpanded = true
                }
            }
        }
        .alert("Re-detect this answer?", isPresented: $showRedetectAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Re-detect", role: .destructive) {
                // 清除舊資料並重新開始偵測
                viewModel.restartDetectionAfterReset()
            }
        } message: {
            Text("Existing transcript, summary, and review will be cleared. Do you want to record again for this question?")
        }
        .onDisappear {
            print("QuestionRowView: onDisappear, saving context (without fetch)...")
            NotesDataController.shared.saveContext(withFetch: false)
        }
        .id(question.id?.uuidString ?? UUID().uuidString)
    }
}
