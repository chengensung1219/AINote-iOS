//
//  NoteView.swift
//  AINotes
//
//  Created by Simon Sung on 10/10/25.
//

import SwiftUI
import CoreData

struct NoteView: View {
    @StateObject var viewModel = NoteViewModel()
    let note: NotesEntity
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading) {
                ZStack(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 15.5) {
                        Text(note.title ?? "Untitled")
                            .font(.title2.bold())
                        ForEach(note.questionsArray, id: \.id) { question in
                            QuestionRowView(question: question)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
            }
        }
        .navigationTitle(note.title ?? "Untitled")
        .navigationBarTitleDisplayMode(.inline)
    }
}
