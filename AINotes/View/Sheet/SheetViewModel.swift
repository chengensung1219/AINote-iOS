//
//  SheetViewModel.swift
//  AINotes
//
//  Created by Simon Sung on 9/30/25.
//
import Foundation
import Combine
import SwiftUI

class SheetViewModel: ObservableObject {
    @Published var hardcoded = ["Simon", "Christy", "Seth", "Ivan", "Karan"]
    
    func delete(at offsets: IndexSet) {
        hardcoded.remove(atOffsets: offsets)
    }


}
