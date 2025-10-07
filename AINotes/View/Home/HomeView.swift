//
//  HomeView.swift
//  AINotes
//
//  Created by Simon Sung on 9/30/25.
//
import SwiftUI

struct HomeView: View {
    @State private var isPresented: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack {
                NoteView()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        isPresented.toggle()
                    }) {
                        Image(systemName: "line.3.horizontal.decrease")
                    }
                }
            }
        }
        .sheet(isPresented: $isPresented) {
            SheetView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }
}


#Preview {
    HomeView()
}
