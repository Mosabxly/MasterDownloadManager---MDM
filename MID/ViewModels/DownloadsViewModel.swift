//
//  DownloadsViewModel.swift
//  MID
//
//  Created by mosab abudeeb on 05/02/2026.
//

import Foundation
import Combine

@MainActor
final class DownloadsViewModel: ObservableObject {
    @Published private(set) var downloads: [DownloadItem] = []

    let saveLocationManager: SaveLocationManager

    private let engine: DownloadEngine
    private let maxConcurrentDownloads = 3

    private var metricsByID: [UUID: Metrics] = [:]
    private var resumeAfterPauseIDs: Set<UUID> = []
    private var generationByID: [UUID: UInt64] = [:]

    private struct Metrics {
        var lastUpdateTime: TimeInterval
        var lastBytesWritten: Int64
        var emaSpeed: Double
    }

    init(saveLocationManager: SaveLocationManager = SaveLocationManager()) {
        self.saveLocationManager = saveLocationManager

        self.engine = DownloadEngine(
            callbacks: .init(
                onProgress: { [weak self] id, totalBytesWritten, expected in
                    Task { @MainActor in
                        self?.handleProgress(id: id, totalBytesWritten: totalBytesWritten, expectedBytes: expected)
                    }
                },
                onSuggestedFilename: { [weak self] id, suggested in
                    Task { @MainActor in
                        self?.handleSuggestedFilename(id: id, suggested: suggested)
                    }
                },
                onPaused: { [weak self] id, resumeData in
                    Task { @MainActor in
                        self?.handlePaused(id: id, resumeData: resumeData)
                    }
                },
                onFinished: { [weak self] id, tempLocation in
                    Task { @MainActor in
                        self?.handleFinished(id: id, tempLocation: tempLocation)
                    }
                },
                onError: { [weak self] id, error in
                    Task { @MainActor in
                        self?.handleError(id: id, error: error)
                    }
                }
            )
        )
    }

    func addDownload(url: URL, saveFolder: URL?) {
        let location: SaveLocation
        if let saveFolder {
            location = (try? saveLocationManager.makeLocation(for: saveFolder)) ?? saveLocationManager.defaultLocation
        } else {
            location = saveLocationManager.defaultLocation
        }

        let fallback = FileNameSanitizer.fallbackName(extension: url.pathExtension.isEmpty ? nil : url.pathExtension)
        let initialName = FileNameSanitizer.sanitize(url.lastPathComponent, fallback: fallback)

        let item = DownloadItem(
            url: url,
            fileName: initialName,
            saveLocation: location,
            state: .queued,
            progress: 0,
            bytesWritten: 0,
            totalBytesExpected: nil,
            speedBytesPerSecond: 0,
            etaSeconds: nil,
            resumeData: nil
        )

        downloads.insert(item, at: 0)
        startNextIfPossible()
    }

    func pause(id: UUID) {
        guard let index = indexOf(id) else { return }

        switch downloads[index].state {
        case .downloading:
            downloads[index].state = .pausing
            resumeAfterPauseIDs.remove(id)
            engine.pause(id: id)
        case .queued:
            downloads[index].state = .paused
        case .pausing, .paused, .finishing, .completed, .failed, .canceled:
            break
        }
    }

    func resume(id: UUID) {
        guard let index = indexOf(id) else { return }

        switch downloads[index].state {
        case .paused:
            downloads[index].state = .queued
            startNextIfPossible()
        case .pausing:
            resumeAfterPauseIDs.insert(id)
        case .failed:
            downloads[index].resumeData = nil
            downloads[index].bytesWritten = 0
            downloads[index].totalBytesExpected = nil
            downloads[index].progress = 0
            downloads[index].state = .queued
            startNextIfPossible()
        case .queued, .downloading, .finishing, .completed, .canceled:
            break
        }
    }

    func cancel(id: UUID) {
        guard let index = indexOf(id) else { return }

        bumpGeneration(for: id)

        switch downloads[index].state {
        case .downloading, .pausing:
            engine.cancel(id: id)
        case .queued, .paused, .failed, .finishing, .completed, .canceled:
            break
        }

        downloads[index].state = .canceled
        downloads[index].speedBytesPerSecond = 0
        downloads[index].etaSeconds = nil

        metricsByID[id] = nil
        resumeAfterPauseIDs.remove(id)

        startNextIfPossible()
    }

    // MARK: - Engine callbacks

    private func handleSuggestedFilename(id: UUID, suggested: String) {
        guard let index = indexOf(id) else { return }

        let fallback = FileNameSanitizer.fallbackName(extension: downloads[index].url.pathExtension.isEmpty ? nil : downloads[index].url.pathExtension)
        let sanitized = FileNameSanitizer.sanitize(suggested, fallback: fallback)
        downloads[index].fileName = sanitized
    }

    private func handleProgress(id: UUID, totalBytesWritten: Int64, expectedBytes: Int64?) {
        guard let index = indexOf(id) else { return }
        guard downloads[index].state == .downloading else { return }

        let now = Date().timeIntervalSince1970
        var metrics = metricsByID[id] ?? Metrics(lastUpdateTime: now, lastBytesWritten: totalBytesWritten, emaSpeed: 0)

        let dt = now - metrics.lastUpdateTime
        let bytesDelta = totalBytesWritten - metrics.lastBytesWritten

        // Throttle updates to reduce UI churn.
        guard dt >= 0.2 else { return }

        downloads[index].bytesWritten = totalBytesWritten
        downloads[index].totalBytesExpected = expectedBytes

        if let expectedBytes, expectedBytes > 0 {
            let p = min(1, max(0, Double(totalBytesWritten) / Double(expectedBytes)))
            downloads[index].progress = p
        } else {
            downloads[index].progress = nil
        }

        if dt > 0, bytesDelta > 0 {
            let instantaneous = Double(bytesDelta) / dt
            let previous = metrics.emaSpeed > 0 ? metrics.emaSpeed : instantaneous
            let alpha = 0.25
            let smoothed = (alpha * instantaneous) + ((1 - alpha) * previous)
            metrics.emaSpeed = smoothed
            downloads[index].speedBytesPerSecond = smoothed

            if let expectedBytes, expectedBytes > 0, smoothed > 1 {
                let remaining = max(0, Double(expectedBytes - totalBytesWritten))
                downloads[index].etaSeconds = remaining / smoothed
            } else {
                downloads[index].etaSeconds = nil
            }
        }

        metrics.lastUpdateTime = now
        metrics.lastBytesWritten = totalBytesWritten
        metricsByID[id] = metrics
    }

    private func handlePaused(id: UUID, resumeData: Data?) {
        guard let index = indexOf(id) else { return }
        guard downloads[index].state == .pausing || downloads[index].state == .downloading else { return }

        downloads[index].resumeData = resumeData
        downloads[index].speedBytesPerSecond = 0
        downloads[index].etaSeconds = nil

        let shouldResume = resumeAfterPauseIDs.contains(id)
        resumeAfterPauseIDs.remove(id)

        if shouldResume {
            downloads[index].state = .queued
        } else {
            downloads[index].state = .paused
        }

        startNextIfPossible()
    }

    private func handleFinished(id: UUID, tempLocation: URL) {
        guard let index = indexOf(id) else { return }
        guard downloads[index].state == .downloading else { return }

        downloads[index].state = .finishing
        downloads[index].speedBytesPerSecond = 0
        downloads[index].etaSeconds = nil

        startNextIfPossible()

        let generation = bumpGeneration(for: id)
        let saveLocation = downloads[index].saveLocation
        let fileName = downloads[index].fileName
        let fallback = FileNameSanitizer.fallbackName(extension: downloads[index].url.pathExtension.isEmpty ? nil : downloads[index].url.pathExtension)

        let folderURL = saveLocation.folder
        let bookmarkData = saveLocation.bookmarkData

        Task(priority: .utility) { @MainActor [weak self] in
            do {
                let result = try await DownloadFinalizer.finalize(
                    tempLocation: tempLocation,
                    fileName: fileName,
                    fallbackName: fallback,
                    folderURL: folderURL,
                    bookmarkData: bookmarkData
                )

                guard let self else { return }
                guard self.generationByID[id] == generation else { return }
                guard let idx = self.indexOf(id) else { return }

                if let refreshedBookmarkData = result.refreshedBookmarkData {
                    self.downloads[idx].saveLocation = SaveLocation(folder: result.resolvedFolderURL, bookmarkData: refreshedBookmarkData)
                } else {
                    self.downloads[idx].saveLocation = SaveLocation(folder: result.resolvedFolderURL, bookmarkData: bookmarkData)
                }

                self.downloads[idx].state = .completed
                self.downloads[idx].progress = 1
                self.downloads[idx].resumeData = nil
                self.downloads[idx].speedBytesPerSecond = 0
                self.downloads[idx].etaSeconds = nil

                self.metricsByID[id] = nil
                self.startNextIfPossible()
            } catch {
                guard let self else { return }
                guard self.generationByID[id] == generation else { return }
                guard let idx = self.indexOf(id) else { return }
                self.downloads[idx].state = .failed(message: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
                self.downloads[idx].speedBytesPerSecond = 0
                self.downloads[idx].etaSeconds = nil
                self.metricsByID[id] = nil
                self.startNextIfPossible()
            }
        }
    }

    private func handleError(id: UUID, error: Error) {
        guard let index = indexOf(id) else { return }
        if downloads[index].state.isTerminal { return }

        let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        downloads[index].state = .failed(message: message)
        downloads[index].speedBytesPerSecond = 0
        downloads[index].etaSeconds = nil

        metricsByID[id] = nil
        resumeAfterPauseIDs.remove(id)

        startNextIfPossible()
    }

    // MARK: - Queue

    private func startNextIfPossible() {
        let activeCount = downloads.filter {
            switch $0.state {
            case .downloading, .pausing:
                return true
            case .queued, .paused, .finishing, .completed, .failed, .canceled:
                return false
            }
        }.count

        guard activeCount < maxConcurrentDownloads else { return }
        var availableSlots = maxConcurrentDownloads - activeCount

        for index in downloads.indices where availableSlots > 0 {
            guard downloads[index].state == .queued else { continue }
            beginDownload(at: index)
            availableSlots -= 1
        }
    }

    private func beginDownload(at index: Int) {
        let id = downloads[index].id
        let url = downloads[index].url
        let resumeData = downloads[index].resumeData

        downloads[index].state = .downloading
        downloads[index].speedBytesPerSecond = 0
        downloads[index].etaSeconds = nil

        let now = Date().timeIntervalSince1970
        metricsByID[id] = Metrics(lastUpdateTime: now, lastBytesWritten: downloads[index].bytesWritten, emaSpeed: 0)

        if let resumeData {
            engine.resume(id: id, resumeData: resumeData)
        } else {
            engine.start(id: id, url: url)
        }
    }

    private func indexOf(_ id: UUID) -> Int? {
        downloads.firstIndex(where: { $0.id == id })
    }

    @discardableResult
    private func bumpGeneration(for id: UUID) -> UInt64 {
        let next = (generationByID[id] ?? 0) &+ 1
        generationByID[id] = next
        return next
    }
}

private enum DownloadFinalizer {
    struct Result: Sendable {
        let resolvedFolderURL: URL
        let refreshedBookmarkData: Data?
    }

    static func finalize(
        tempLocation: URL,
        fileName: String,
        fallbackName: String,
        folderURL: URL,
        bookmarkData: Data?
    ) async throws -> Result {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                do {
                    let (resolvedFolder, refreshedBookmarkData) = try resolveFolderAndBookmark(
                        folderURL: folderURL,
                        bookmarkData: bookmarkData
                    )

                    let moveWork: () throws -> Void = {
                        try FileSystem.ensureDirectoryExists(resolvedFolder)
                        let safeName = FileNameSanitizer.sanitize(fileName, fallback: fallbackName)
                        let destination = FileSystem.uniqueDestinationURL(in: resolvedFolder, fileName: safeName)
                        try FileSystem.moveItemReplacingIfNeeded(from: tempLocation, to: destination)
                    }

                    if bookmarkData != nil {
                        _ = try SecurityScopedBookmark.withAccess(to: resolvedFolder) {
                            try moveWork()
                        }
                    } else {
                        try moveWork()
                    }

                    continuation.resume(returning: Result(resolvedFolderURL: resolvedFolder, refreshedBookmarkData: refreshedBookmarkData))
                } catch {
                    try? FileManager.default.removeItem(at: tempLocation)
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private static func resolveFolderAndBookmark(
        folderURL: URL,
        bookmarkData: Data?
    ) throws -> (resolvedFolderURL: URL, refreshedBookmarkData: Data?) {
        guard let bookmarkData else {
            return (folderURL, nil)
        }

        if let resolution = SecurityScopedBookmark.resolve(bookmarkData) {
            return (resolution.url, resolution.refreshedBookmarkData)
        }

        return (folderURL, nil)
    }
}
