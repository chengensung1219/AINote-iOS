//
//  Note.swift
//  AINotes
//
//  Created by Simon Sung on 10/2/25.
//

import Foundation

struct Note: Identifiable {
    let id = UUID()
    var title: String
    var content: String
    var dateCreated: Date = Date()
}
