//
//  NewNoteView.swift
//  AINotes
//
//  Created by Simon Sung on 11/4/25.
//

import SwiftUI
import CoreData

struct NewNoteView: View {
    var onSave: ((NotesEntity) -> Void)?
    @Environment(\.dismiss) var dismiss
    @StateObject var viewModel = NoteViewModel()
    @State private var hasSaved = false
    
    init(onSave: ((NotesEntity) -> Void)? = nil) {
        self.onSave = onSave
    }
    
    var body: some View {
        VStack {
            if let note = viewModel.currentNote {
                EditNoteView(note: note)
            } else {
                Text("Creating note...")
                    .onAppear {
                        viewModel.createNewNote()
                    }
            }
        }
        .navigationTitle("New Note")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(action: {
                    viewModel.saveAndNavigate { note in
                        hasSaved = true
                        onSave?(note)
                    }
                }) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                }
            }
        }
        .onDisappear {
            guard !hasSaved else { return }
            viewModel.discardCurrentNote()
        }
    }
}
