//
//  CoreData.swift
//  AINotes
//
//  Created by Simon Sung on 11/11/25.
//
import Foundation
import CoreData

class PersistenceController {
    static let shared = PersistenceController()
    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        
        container = NSPersistentContainer(name: "NotesContainer")
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
    }
}

extension NotesEntity {
    var questionsArray: [QuestionsEntity] {
        let set = content as? Set<QuestionsEntity> ?? []
        return set.sorted { 
            let id0 = $0.id?.uuidString ?? ""
            let id1 = $1.id?.uuidString ?? ""
            return id0 < id1
        }
    }
}
