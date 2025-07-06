//
//  HomeView.swift
//  AINotes
//
//  Created by Simon Sung on 7/1/25.
//

import SwiftUI
import AVKit

struct HomeView: View {
    @StateObject private var audioManager = AudioManager()
    @State private var showList: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack {
                Spacer()
                Button(action: {
                    if !audioManager.isRecording {
                        audioManager.startRecording()
                    } else {
                        audioManager.stopRecording()
                    }
                }) {
                    Image(systemName: audioManager.isRecording ? "stop.circle.fill" : "mic.circle.fill")
                        .resizable()
                        .frame(width: 60, height: 60)
                        .foregroundStyle(audioManager.isRecording ? .red : .blue)
                }
                .padding()
                
                Text(audioManager.isRecording ? "Recording..." : "Tap to Start Speech Recognition")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(maxWidth: 200)
                
                Spacer()
                Button(action: {
                    showList.toggle()
                }) {
                    Text("Show List")
                }
            }
            .padding()
            .sheet(isPresented: $showList) {
                SheetView()
                    .presentationCornerRadius(30)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .presentationContentInteraction(.scrolls)
            }
        }
    }
}

#Preview {
    HomeView()
}

