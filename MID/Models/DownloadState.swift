//
//  DownloadState.swift
//  MID
//
//  Created by mosab abudeeb on 05/02/2026.
//

import Foundation

enum DownloadState: Equatable {
    case queued
    case downloading
    case pausing
    case paused
    case finishing
    case completed
    case failed(message: String)
    case canceled
}

extension DownloadState {
    var isTerminal: Bool {
        switch self {
        case .completed, .failed, .canceled:
            return true
        case .queued, .downloading, .pausing, .paused, .finishing:
            return false
        }
    }

    var displayText: String {
        switch self {
        case .queued: "Queued"
        case .downloading: "Downloading"
        case .pausing: "Pausing"
        case .paused: "Paused"
        case .finishing: "Finishing"
        case .completed: "Completed"
        case .failed: "Failed"
        case .canceled: "Canceled"
        }
    }
}
