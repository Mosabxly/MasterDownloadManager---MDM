//
//  DownloadEngineError.swift
//  MID
//
//  Created by mosab abudeeb on 05/02/2026.
//

import Foundation

enum DownloadEngineError: LocalizedError, Equatable {
    case httpStatus(code: Int)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .httpStatus(let code):
            return "HTTP error \(code)"
        case .invalidResponse:
            return "Invalid response"
        }
    }
}

