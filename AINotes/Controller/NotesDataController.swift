//
//  NoteDataController.swift
//  AINotes
//
//  Created by Simon Sung on 11/13/25.
//

import Combine
import CoreData
import Foundation

class NotesDataController: ObservableObject {
    
    static let shared = {
        let persistenceController = PersistenceController.shared
        return NotesDataController(container: persistenceController.container)
    }()

    private init(container: NSPersistentContainer) {
        self.container = container
        self.viewContext = container.viewContext
        fetchNotes()
    }
    
    let container: NSPersistentContainer
    let viewContext: NSManagedObjectContext
    
    @Published var savedNotes: [NotesEntity] = []
    
    private var isFetching = false
    
    func fetchNotes() {
        guard !isFetching else {
            print("NotesDataController: Skipping fetch, already fetching")
            return
        }
        isFetching = true
        
        let request = NSFetchRequest<NotesEntity>(entityName: "NotesEntity")
        request.sortDescriptors = [NSSortDescriptor(key: "modifiedDate", ascending: false)]
        request.relationshipKeyPathsForPrefetching = ["content"]
        request.returnsObjectsAsFaults = false
        
        do {
            viewContext.processPendingChanges()
            
            self.savedNotes = try viewContext.fetch(request)
            print("NotesDataController: Fetched \(self.savedNotes.count) notes")
            
        } catch let error {
            print("Error fetching notes: \(error)")
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isFetching = false
        }
    }
    
    
    func saveContext(withFetch: Bool = true) {
        guard viewContext.hasChanges else { return }
        do {
            try viewContext.save()
            viewContext.processPendingChanges()
            
            if withFetch {
                DispatchQueue.main.async { [weak self] in
                    self?.fetchNotes()
                }
            }
        } catch {
            print("Failed to save context: \(error.localizedDescription)")
        }
    }
    
    func addNote(title: String, shouldSave: Bool = true) -> NotesEntity? {
        guard !title.isEmpty else { return nil }
        
        let newNote = NotesEntity(context: viewContext)
        newNote.id = UUID()
        newNote.title = title
        newNote.createdDate = Date()
        newNote.modifiedDate = Date()
        
        if shouldSave {
            saveContext()
        }
        return newNote
    }
    
    func deleteNotes(offsets: IndexSet) {
        offsets.map { self.savedNotes[$0] }.forEach(viewContext.delete)
        saveContext()
    }
    
    func delete(note: NotesEntity, withFetch: Bool = true, shouldSave: Bool = true) {
        viewContext.delete(note)
        if shouldSave {
            saveContext(withFetch: withFetch)
        }
    }
    
    func addQuestion(to parentNote: NotesEntity, questionText: String = "", answer: String = "", withFetch: Bool = true, shouldSave: Bool = true) -> QuestionsEntity {
        let newQuestion = QuestionsEntity(context: viewContext)
        newQuestion.id = UUID()
        newQuestion.question = questionText
        newQuestion.answer = answer
        newQuestion.parentNote = parentNote
        
        parentNote.modifiedDate = Date()
        
        if shouldSave {
            saveContext(withFetch: withFetch)
        }
        return newQuestion
    }

    func deleteQuestions(questions: [QuestionsEntity]) {
        questions.forEach(viewContext.delete)
        saveContext()
    }
}
