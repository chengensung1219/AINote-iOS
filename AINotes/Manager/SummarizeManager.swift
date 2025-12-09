//
//  SummarizeManager.swift
//  AINotes
//
//  Created by Simon Sung on 12/4/25.
//

import Foundation
import Combine

class SummarizeManager: ObservableObject {
    @Published var isSummarizing = false
    @Published var summary = ""
    
    private static let summarizeFunctionURL = "https://us-central1-ai-detector-ios-51c4c.cloudfunctions.net/summarizeTranscript"
    
    private var timeoutWorkItem: DispatchWorkItem?
    
    func summarizeTranscript(_ transcript: String) {
        guard !transcript.isEmpty else {
            print("SummarizeManager: Cannot summarize empty transcript")
            return
        }
        
        guard let url = URL(string: Self.summarizeFunctionURL) else {
            print("SummarizeManager: Invalid summarize URL")
            return
        }
        
        timeoutWorkItem?.cancel()
        
        isSummarizing = true
        summary = ""
        
        let timeoutWork = DispatchWorkItem { [weak self] in
            guard let self = self, self.isSummarizing else { return }
            print("SummarizeManager: Timeout reached, stopping summarization")
            DispatchQueue.main.async {
                self.isSummarizing = false
            }
        }
        timeoutWorkItem = timeoutWork
        DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: timeoutWork)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 25
        
        let requestBody: [String: Any] = ["transcript": transcript]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            print("SummarizeManager: Failed to create request body")
            timeoutWorkItem?.cancel()
            isSummarizing = false
            return
        }
        request.httpBody = jsonData
        
        print("SummarizeManager: Sending transcript for summarization (length: \(transcript.count))")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in

            self?.timeoutWorkItem?.cancel()
            guard let self = self else { 
                print("SummarizeManager: self is nil in completion handler")
                return 
            }
            
            if let error = error {
                print("SummarizeManager: Network error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isSummarizing = false
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("SummarizeManager: Invalid response type")
                DispatchQueue.main.async {
                    self.isSummarizing = false
                }
                return
            }
            
            print("SummarizeManager: HTTP status code: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                print("SummarizeManager: Summarization failed with status: \(httpResponse.statusCode)")
                if let data = data, let errorString = String(data: data, encoding: .utf8) {
                    print("SummarizeManager: Error response body: \(errorString)")
                }
                DispatchQueue.main.async {
                    self.isSummarizing = false
                }
                return
            }
            
            guard let data = data else {
                print("SummarizeManager: No data received")
                DispatchQueue.main.async {
                    self.isSummarizing = false
                }
                return
            }
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("SummarizeManager: Raw response: \(responseString)")
            }
            
            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    print("SummarizeManager: Failed to parse JSON - not a dictionary")
                    DispatchQueue.main.async {
                        self.isSummarizing = false
                    }
                    return
                }
                
                print("SummarizeManager: Parsed JSON keys: \(json.keys)")
                
                guard let summaryText = json["summary"] as? String else {
                    print("SummarizeManager: 'summary' key not found or not a string. JSON: \(json)")
                    DispatchQueue.main.async {
                        self.isSummarizing = false
                    }
                    return
                }
                
                print("SummarizeManager: Summary extracted successfully (length: \(summaryText.count))")
                
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    print("SummarizeManager: Setting summary on main thread")
                    
                    self.summary = summaryText
                    print("SummarizeManager: Summary set to: '\(self.summary)'")
                    
                    self.isSummarizing = false
                    print("SummarizeManager: isSummarizing set to: \(self.isSummarizing)")
                    
                    self.objectWillChange.send()
                }
            } catch {
                print("SummarizeManager: JSON parsing error: \(error)")
                DispatchQueue.main.async {
                    self.isSummarizing = false
                }
            }
        }.resume()
    }
    
    func reset() {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        isSummarizing = false
        summary = ""
    }
}

