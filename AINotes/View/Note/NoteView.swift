//
//  NoteView.swift
//  AINotes
//
//  Created by Simon Sung on 9/30/25.
//
import SwiftUI

struct NoteView: View {
    @StateObject var viewModel = NoteViewModel()
    
    var body: some View {
        NavigationStack {
            ZStack {
                if !viewModel.isEditing {
                    if viewModel.note.isEmpty {
                        Text("Tap to edit this note...")
                            .onTapGesture {
                                viewModel.isEditing = true
                            }
                    } else {
                        Text(viewModel.note)
                            .onTapGesture {
                                viewModel.isEditing = true
                            }
                    }
                        
                } else {
                    TextField("New Note", text: $viewModel.note)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        
                    }) {
                        Text("Save")
                    }
                }
            }
        }
    }
}
