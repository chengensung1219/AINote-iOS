//
//  AINotesApp.swift
//  AINotes
//
//  Created by Simon Sung on 9/30/25.
//

import SwiftUI
import CoreData

@main
struct AINotesApp: App {
    @StateObject var dataController = NotesDataController.shared
        
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                NoteListView()
            }
        }
    }
}
