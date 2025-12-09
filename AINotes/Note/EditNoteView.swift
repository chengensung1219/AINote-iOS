//
//  EditNoteView.swift
//  AINotes
//
//  Created by Simon Sung on 11/13/25.
//

import SwiftUI
import CoreData

struct EditNoteView: View {
    @ObservedObject var note: NotesEntity
    @StateObject private var dataController = NotesDataController.shared
    @FocusState private var focusedQuestionId: UUID?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Title")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.secondary)
                    TextField("Enter note title", text: Binding(
                        get: { note.title ?? "" },
                        set: { 
                            note.title = $0
                            note.modifiedDate = Date()
                        }
                    ))
                    .font(.system(size: 18, weight: .medium))
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray6))
                    )
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Questions")
                            .font(.system(size: 18, weight: .semibold))
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    
                    ForEach(note.questionsArray, id: \.id) { question in
                        let questionNumber = (note.questionsArray.firstIndex(where: { $0.id == question.id }) ?? 0) + 1
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(
                                            LinearGradient(
                                                gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.blue]),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .frame(width: 32, height: 32)
                                    
                                    Text("\(questionNumber)")
                                        .font(.system(size: 14, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                
                                Text("Question \(questionNumber)")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Button(action: {
                                    withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                                    dataController.viewContext.delete(question)
                                }
                                }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.red)
                                        .padding(8)
                                        .background(Color.red.opacity(0.1))
                                        .clipShape(Circle())
                                }
                                .buttonStyle(.plain)
                            }
                            
                            TextEditor(text: Binding(
                                get: { question.question ?? "" },
                                set: { 
                                    question.question = $0
                                    question.parentNote?.modifiedDate = Date()
                                }
                            ))
                            .focused($focusedQuestionId, equals: question.id)
                            .font(.system(size: 15))
                            .foregroundColor(.primary)
                            .padding(12)
                            .frame(minHeight: 100)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white)
                                    .shadow(color: focusedQuestionId == question.id ? Color.blue.opacity(0.2) : Color.black.opacity(0.05), 
                                           radius: focusedQuestionId == question.id ? 8 : 4, 
                                           x: 0, 
                                           y: 2)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(focusedQuestionId == question.id ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 2)
                            )
                        }
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.08), radius: 8, x: 0, y: 4)
                        )
                        .padding(.horizontal, 20)
                    }

                    Button(action: {
                        _ = dataController.addQuestion(to: note, questionText: "", withFetch: false, shouldSave: false)
                        if let newQuestion = note.questionsArray.last {
                            focusedQuestionId = newQuestion.id
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 18, weight: .medium))
                            Text("Add Question")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.blue, Color.blue.opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 8)
            }
            .padding(.bottom, 20)
        }
    }
}


