//
//  Date.swift
//  AINotes
//
//  Created by Simon Sung on 10/9/25.
//

import Foundation

extension Date {
    var monthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: self)
    }
    
    var yearName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: self)
    }
}
