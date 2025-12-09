//
//  WebSocketManager.swift
//  AINotes
//
//  Created by Simon Sung on 11/25/25.
//

@preconcurrency import Foundation
import Combine

class WebSocketManager: ObservableObject {
    private var webSocketTask: URLSessionWebSocketTask?
    
    private var silenceWorkItem: DispatchWorkItem?
    private var clientSilenceMs: Int = 1200
    
    private var cancellables = Set<AnyCancellable>()
    private let session: URLSession
    
    private static let firebaseFunctionURL = "https://us-central1-ai-detector-ios-51c4c.cloudfunctions.net/getAssemblyRealtimeToken"
    
    @Published var transcript: String = ""
    @Published var fullTranscript: String = ""
    @Published var isConnected: Bool = false
    
    init() {
        let config = URLSessionConfiguration.default
        self.session = URLSession(configuration: config)
    }
    
    func connect() {
        disconnect()
        
        fetchToken { [weak self] result in
            guard let self = self else { return }
            switch result {
            case .success(let tokenResponse):

                if let url = URL(string: tokenResponse.websocket_url) {
                    self.connectToWebSocket(url: url, apiKey: tokenResponse.api_key)
                } else {
                    print("WebSocket: Invalid URL")
                }
            case .failure(let error):
                print("WebSocket: Failed to fetch token: \(error.localizedDescription)")
            }
        }
    }

    private func fetchToken(completion: @escaping (Result<TokenResponse, Error>) -> Void) {
        let urlString = Self.firebaseFunctionURL
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "WebSocketManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("WebSocket: fetchToken network error: \(error)")
                completion(.failure(error))
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                print("WebSocket: fetchToken HTTP status: \(httpResponse.statusCode)")
                if httpResponse.statusCode != 200 {

                    var errorMessage = "HTTP \(httpResponse.statusCode)"
                    if let data = data, let responseString = String(data: data, encoding: .utf8) {
                        print("WebSocket: fetchToken error response: \(responseString)")

                        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                           let error = json["error"] as? String {
                            errorMessage = error
                        } else {
                            errorMessage = responseString
                        }
                    }
                    let statusError = NSError(domain: "WebSocketManager", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
                    print("WebSocket: fetchToken HTTP error: \(statusError)")
                    completion(.failure(statusError))
                    return
                }
            }
            
            guard let data = data else {
                print("WebSocket: fetchToken - No data received")
                completion(.failure(NSError(domain: "WebSocketManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "No data received"])))
                return
            }
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("WebSocket: fetchToken raw response: \(responseString)")
            }

            Task.detached {
                do {

                    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                        print("WebSocket: fetchToken - Failed to parse JSON")
                        throw NSError(domain: "WebSocketManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse JSON"])
                    }
                    
                    print("WebSocket: fetchToken parsed JSON: \(json)")
                    

                    if let errorMessage = json["error"] as? String {
                        print("WebSocket: fetchToken - Server error: \(errorMessage)")
                        throw NSError(domain: "WebSocketManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Server error: \(errorMessage)"])
                    }
                    
                    guard let websocket_url = json["websocket_url"] as? String,
                          let api_key = json["api_key"] as? String,
                          let sample_rate = json["sample_rate"] as? Int else {
                        print("WebSocket: fetchToken - Missing required fields. JSON keys: \(json.keys)")
                        throw NSError(domain: "WebSocketManager", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid response format - missing required fields"])
                    }
                    
                    print("WebSocket: fetchToken - Success! websocket_url: \(websocket_url)")
                    let tokenResponse = TokenResponse(websocket_url: websocket_url, sample_rate: sample_rate, api_key: api_key)
                    await MainActor.run {
                        completion(.success(tokenResponse))
                    }
                } catch {
                    print("WebSocket: fetchToken - Parse error: \(error)")
                    await MainActor.run {
                        completion(.failure(error))
                    }
                }
            }
        }.resume()
    }
    
    private func connectToWebSocket(url: URL, apiKey: String) {
        print("WebSocket: Connecting to \(url) with API key")
        
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        
        print("WebSocket: Setting Authorization header with API key (first 10 chars): \(String(apiKey.prefix(10)))...")
        
        let task = session.webSocketTask(with: request)
        self.webSocketTask = task
        
        task.resume()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.isConnected = true
            print("WebSocket: isConnected set to true")
        }
        print("WebSocket: Starting to receive messages...")
        receiveMessage()
    }
    
    func disconnect() {

        silenceWorkItem?.cancel()
        silenceWorkItem = nil
        
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil

        DispatchQueue.main.async {
            self.isConnected = false
            self.transcript = ""
        }
        print("WebSocket: Disconnected.")
    }
    
    private func scheduleSilenceTimeout() {

        silenceWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            let buffered = self.transcript.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !buffered.isEmpty else { return }
            DispatchQueue.main.async {
                
                self.fullTranscript.append(buffered + " ")
                self.transcript = ""
            }
        }
        silenceWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(clientSilenceMs), execute: work)
    }
    
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            switch result {
            case .failure(let error):
                print("WebSocket receive error: \(error)")
                self?.disconnect()
            case .success(let message):
                switch message {
                case .data(let data):
                    self?.handleIncomingData(data)
                case .string(let text):
                    self?.handleIncomingText(text)
                @unknown default:
                    break
                }

                self?.receiveMessage()
            }
        }
    }
    
    private func handleIncomingText(_ text: String) {
        print("WebSocket Received Text: \(text)")
        
        guard let data = text.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            print("WebSocket: Failed to parse JSON")
            return
        }
        
        if let transcript = extractTranscript(from: text) {
            DispatchQueue.main.async {
                self.transcript = transcript
                
                if let endOfTurn = dict["end_of_turn"] as? Bool, endOfTurn,
                   let isFormatted = dict["turn_is_formatted"] as? Bool, isFormatted {

                    self.fullTranscript.append(transcript + " ")
                    self.transcript = ""
                    self.silenceWorkItem?.cancel()
                } else {
                    
                    self.scheduleSilenceTimeout()
                }
            }
        }
    }
    
    private func handleIncomingData(_ data: Data) {

        print("WebSocket Received Data: \(data)")
    }
    

    func sendAudioChunk(_ data: Data) {
        guard let task = webSocketTask else { return }
        let message = URLSessionWebSocketTask.Message.data(data)
        task.send(message) { error in
            if let error = error {
                print("WebSocket send error: \(error)")
            }
        }
    }

    private func extractTranscript(from text: String) -> String? {
        guard let data = text.data(using: .utf8) else { return nil }
        guard let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        
        if let transcript = dict["transcript"] as? String, !transcript.isEmpty {
            return transcript
        }

        else if let words = dict["words"] as? [[String: Any]] {

            let wordTexts = words.compactMap { $0["text"] as? String }
            if !wordTexts.isEmpty {

                return wordTexts.joined(separator: " ")
            }
        }

        if let messageType = dict["message_type"] as? String,
           (messageType == "PartialTranscript" || messageType == "FinalTranscript"),
           let transcript = dict["text"] as? String {
            return transcript
        }
        return nil
    }
    
    private func getFullTranscript() -> String {
        return self.fullTranscript
    }
    
    func resetFullTranscript() {
        self.transcript = ""
        silenceWorkItem?.cancel()
    }
}
