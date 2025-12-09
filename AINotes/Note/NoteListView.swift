//
//  NoteListView.swift
//  AINotes
//
//  Created by Simon Sung on 10/10/25.
//

import SwiftUI
import CoreData

enum NavigationDestination: Hashable {
    case newNote
    case note(UUID)
}

struct NoteRowView: View {
    let note: NotesEntity
    
    private var questions: [QuestionsEntity] {
        note.questionsArray
    }
    
    var body: some View {
        if let noteId = note.id {
            NavigationLink(value: NavigationDestination.note(noteId)) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(note.title ?? "Untitled")
                        .font(.headline)
                    if !questions.isEmpty {
                        ForEach(questions.prefix(3), id: \.id) { question in
                            if let questionText = question.question, !questionText.isEmpty {
                                Text(questionText)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
                .onAppear {
                    _ = note.questionsArray
                }
            }
        }
    }
}

struct NoteListView: View {
    @StateObject var viewModel = NoteViewModel()
    @State private var navigationPath = NavigationPath()
    @State private var previousPathCount = 0
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                ForEach(viewModel.notes, id: \.id) { note in
                    NoteRowView(note: note)
                }
                .onDelete { indexSet in
                    viewModel.deleteNotes(at: indexSet)
                }
            }
            .navigationTitle("Detection Files")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Spacer()
                    Button(action: {
                        navigationPath.append(NavigationDestination.newNote)
                    }) {
                        Image(systemName: "document.badge.plus")
                    }
                }
            }
            .navigationDestination(for: NavigationDestination.self) { destination in
                switch destination {
                case .newNote:
                    NewNoteView(onSave: { note in
                        viewModel.handleNoteSave(note: note) { destination in
                            if let destination = destination {
                                navigationPath.removeLast()
                                
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    navigationPath.append(destination)
                                }
                            }
                        }
                    })
                case .note(let noteId):
                    if let note = viewModel.notes.first(where: { $0.id == noteId }) {
                        NoteView(note: note)
                    }
                }
            }
            .onAppear {
                viewModel.dataController.fetchNotes()
                previousPathCount = navigationPath.count
            }
            .onChange(of: navigationPath.count) { oldCount, newCount in
                previousPathCount = newCount
            }
        }
    }
}
