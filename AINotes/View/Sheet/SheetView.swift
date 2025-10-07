//
//  SheetView.swift
//  AINotes
//
//  Created by Simon Sung on 9/30/25.
//
import SwiftUI

struct SheetView: View {
    @StateObject var viewModel = SheetViewModel()
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.hardcoded, id: \.self) { hardcoded in
                    Text(hardcoded)
                }
                .onDelete(perform: viewModel.delete)
            }
            .navigationTitle("List")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    SheetView()
}
