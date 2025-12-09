//
//  ReviewManager.swift
//  AINotes
//
//  Created by Simon Sung on 12/4/25.
//

import Foundation
import Combine

class ReviewManager: ObservableObject {
    @Published var isReviewing = false
    @Published var review = ""
    @Published var score: Double = 0.0
    
    private static let reviewFunctionURL = "https://us-central1-ai-detector-ios-51c4c.cloudfunctions.net/reviewAnswer"
    
    private var timeoutWorkItem: DispatchWorkItem?
    
    func reviewAnswer(question: String, transcript: String) {
        guard !transcript.isEmpty, !question.isEmpty else {
            print("ReviewManager: Cannot review empty transcript or question")
            return
        }
        
        guard let url = URL(string: Self.reviewFunctionURL) else {
            print("ReviewManager: Invalid review URL")
            return
        }
        
        timeoutWorkItem?.cancel()
        
        DispatchQueue.main.async {
            self.isReviewing = true
            self.review = ""
            self.score = 0
        }
        
        let timeoutWork = DispatchWorkItem { [weak self] in
            guard let self = self, self.isReviewing else { return }
            print("ReviewManager: Timeout reached, stopping review")
            DispatchQueue.main.async {
                self.isReviewing = false
            }
        }
        timeoutWorkItem = timeoutWork
        DispatchQueue.main.asyncAfter(deadline: .now() + 30, execute: timeoutWork)
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 25
        
        let requestBody: [String: Any] = [
            "question": question,
            "transcript": transcript
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            print("ReviewManager: Failed to create request body")
            timeoutWorkItem?.cancel()
            DispatchQueue.main.async {
                self.isReviewing = false
            }
            return
        }
        request.httpBody = jsonData
        
        print("ReviewManager: Sending request for review")
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in

            self?.timeoutWorkItem?.cancel()
            
            guard let self = self else { return }
            
            if let error = error {
                print("ReviewManager: Network error: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isReviewing = false
                }
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("ReviewManager: Invalid response type")
                DispatchQueue.main.async {
                    self.isReviewing = false
                }
                return
            }
            
            print("ReviewManager: HTTP Status Code: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200, let data = data else {
                print("ReviewManager: Request failed with status \(httpResponse.statusCode)")
                if let data = data, let errorBody = String(data: data, encoding: .utf8) {
                    print("ReviewManager: Error body: \(errorBody)")
                }
                DispatchQueue.main.async {
                    self.isReviewing = false
                }
                return
            }
            
            if let rawString = String(data: data, encoding: .utf8) {
                print("ReviewManager: Raw response: \(rawString)")
            }
            
            do {
                guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    print("ReviewManager: Failed to parse JSON")
                    DispatchQueue.main.async {
                        self.isReviewing = false
                    }
                    return
                }
                
                let reviewText = json["review"] as? String ?? ""
                let scoreValue = json["score"] as? Int ?? 0
                
                print("ReviewManager: Review extracted successfully")
                
                DispatchQueue.main.async {
                    self.review = reviewText
                    self.score = Double(scoreValue)
                    self.isReviewing = false
                    self.objectWillChange.send()
                }
            } catch {
                print("ReviewManager: JSON parsing error: \(error)")
                DispatchQueue.main.async {
                    self.isReviewing = false
                }
            }
        }.resume()
    }
    
    func reset() {
        timeoutWorkItem?.cancel()
        timeoutWorkItem = nil
        isReviewing = false
        review = ""
        score = 0.0
    }
}

