//
//  SheetView.swift
//  AINotes
//
//  Created by Simon Sung on 7/5/25.
//

import SwiftUI

struct SheetView: View {
    @StateObject var audioManager = AudioManager()
    
    var body: some View {
        NavigationView {
            if audioManager.audios.isEmpty {
                VStack(spacing: 20) {
                    Text("No Audio Files")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Record some audio and then come back to see them here.")
                        .font(.caption)
                        .frame(maxWidth: 200)
                        .multilineTextAlignment(.center)
                }
            } else {
                
                List(audioManager.audios, id: \.self) { url in
                    HStack {
                        Text(url.lastPathComponent)
                            .lineLimit(1)
                        Spacer()
                        Button(action: {
                            audioManager.play(url: url)
                        }) {
                            Image(systemName: "play")
                        }
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role:.destructive, action: {
                            audioManager.delete(url: url)
                        }) {
                            Text("Delete")
                        }
                    }
                    
                }
                .listStyle(.insetGrouped)
            }
        }
        .onAppear {
            audioManager.fetchAudioFiles()
        }
    }
}
