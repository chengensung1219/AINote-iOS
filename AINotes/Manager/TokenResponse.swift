//
//  TokenResponse.swift
//  AINotes
//
//  Created by Simon Sung on 11/25/25.
//

import Foundation

struct TokenResponse: Decodable, Sendable {
    let websocket_url: String
    let sample_rate: Int
    let api_key: String
}

