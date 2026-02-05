//
//  DownloadItem.swift
//  MID
//
//  Created by mosab abudeeb on 05/02/2026.
//

import Foundation

struct DownloadItem: Identifiable, Equatable {
    let id: UUID
    let url: URL
    let createdAt: Date

    var fileName: String
    var saveLocation: SaveLocation

    var state: DownloadState

    var progress: Double?
    var bytesWritten: Int64
    var totalBytesExpected: Int64?

    var speedBytesPerSecond: Double
    var etaSeconds: Double?

    var resumeData: Data?

    init(
        id: UUID = UUID(),
        url: URL,
        fileName: String,
        saveLocation: SaveLocation,
        state: DownloadState = .queued,
        progress: Double? = 0,
        bytesWritten: Int64 = 0,
        totalBytesExpected: Int64? = nil,
        speedBytesPerSecond: Double = 0,
        etaSeconds: Double? = nil,
        resumeData: Data? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.url = url
        self.fileName = fileName
        self.saveLocation = saveLocation
        self.state = state
        self.progress = progress
        self.bytesWritten = bytesWritten
        self.totalBytesExpected = totalBytesExpected
        self.speedBytesPerSecond = speedBytesPerSecond
        self.etaSeconds = etaSeconds
        self.resumeData = resumeData
        self.createdAt = createdAt
    }
}

