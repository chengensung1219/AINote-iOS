//
//  NoteViewModel.swift
//  AINotes
//
//  Created by Simon Sung on 10/2/25.
//

import Foundation
import Combine
import SwiftUI
import CoreData

class NoteViewModel: ObservableObject {
    let dataController = NotesDataController.shared
    private var cancellables = Set<AnyCancellable>()
    
    @Published var currentNote: NotesEntity?
    @Published var noteTitle: String = ""
    @Published var notes: [NotesEntity] = []
    
    init() {
        dataController.$savedNotes
            .assign(to: &$notes)
    }
    
    func deleteNotes(at offsets: IndexSet) {
        dataController.deleteNotes(offsets: offsets)
    }
    
    func createNewNote() {
        let title = noteTitle.isEmpty ? "New Note" : noteTitle
        currentNote = dataController.addNote(title: title, shouldSave: false)
    }
    
    func saveContext() {
        dataController.saveContext(withFetch: false)
    }
    
    func updateNoteTitle(_ note: NotesEntity, title: String) {
        note.title = title
        note.modifiedDate = Date()
        dataController.saveContext(withFetch: false)
    }
    
    func discardCurrentNote() {
        guard let note = currentNote else { return }
        dataController.delete(note: note, withFetch: false, shouldSave: false)
        currentNote = nil
    }
    
    func saveAndNavigate(completion: @escaping (NotesEntity) -> Void) {
        guard let note = currentNote else { return }
        saveContext()
        completion(note)
    }
    
    func handleNoteSave(note: NotesEntity, completion: @escaping (NavigationDestination?) -> Void) {

        dataController.viewContext.processPendingChanges()
        
        dataController.saveContext(withFetch: false)

        dataController.fetchNotes()

        DispatchQueue.main.async {
            if let noteId = note.id {
                completion(.note(noteId))
            } else {
                completion(nil)
            }
        }
    }
    
    func refreshNotesIfNeeded(navigationPathCount: Int, previousPathCount: inout Int) {
        if navigationPathCount < previousPathCount {
            dataController.fetchNotes()
        }
        previousPathCount = navigationPathCount
    }
}
