//
//  NoteViewModel.swift
//  AINotes
//
//  Created by Simon Sung on 10/2/25.
//

import Foundation
import Combine

class NoteViewModel: ObservableObject {
    @Published var isEditing: Bool = false
    @Published var note: String = ""
    
//    init(note: Note) {
//        self.note = note
//    }
    
    func doneEditing() {
        isEditing.toggle()
        
    }
}
