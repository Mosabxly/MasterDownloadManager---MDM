//
//  DownloadEngine.swift
//  MID
//
//  Created by mosab abudeeb on 05/02/2026.
//

import Foundation

final class DownloadEngine: NSObject {
    struct Callbacks {
        var onProgress: (UUID, Int64, Int64?) -> Void
        var onSuggestedFilename: (UUID, String) -> Void
        var onPaused: (UUID, Data?) -> Void
        var onFinished: (UUID, URL) -> Void
        var onError: (UUID, Error) -> Void
    }

    private let callbacks: Callbacks
    private let stateQueue = DispatchQueue(label: "DownloadEngine.state")

    private var sessionStorage: URLSession?
    private var session: URLSession {
        if let sessionStorage { return sessionStorage }

        let config = URLSessionConfiguration.default
        config.waitsForConnectivity = true
        config.requestCachePolicy = .reloadIgnoringLocalAndRemoteCacheData
        config.urlCache = nil

        let delegateQueue = OperationQueue()
        delegateQueue.name = "DownloadEngine.delegate"
        delegateQueue.maxConcurrentOperationCount = 1

        let s = URLSession(configuration: config, delegate: self, delegateQueue: delegateQueue)
        sessionStorage = s
        return s
    }

    private var activeByID: [UUID: URLSessionDownloadTask] = [:]
    private var idByTaskIdentifier: [Int: UUID] = [:]
    private var pausingIDs: Set<UUID> = []

    init(callbacks: Callbacks) {
        self.callbacks = callbacks
        super.init()
    }

    deinit {
        sessionStorage?.invalidateAndCancel()
    }

    func start(id: UUID, url: URL) {
        stateQueue.async {
            guard self.activeByID[id] == nil else { return }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData

            let task = self.session.downloadTask(with: request)
            self.activeByID[id] = task
            self.idByTaskIdentifier[task.taskIdentifier] = id
            task.resume()
        }
    }

    func resume(id: UUID, resumeData: Data) {
        stateQueue.async {
            guard self.activeByID[id] == nil else { return }
            let task = self.session.downloadTask(withResumeData: resumeData)
            self.activeByID[id] = task
            self.idByTaskIdentifier[task.taskIdentifier] = id
            task.resume()
        }
    }

    func pause(id: UUID) {
        stateQueue.async {
            guard let task = self.activeByID[id] else { return }
            self.pausingIDs.insert(id)

            task.cancel(byProducingResumeData: { resumeData in
                self.stateQueue.async {
                    self.activeByID[id] = nil
                    self.idByTaskIdentifier[task.taskIdentifier] = nil
                    self.pausingIDs.remove(id)
                }

                Task { @MainActor in
                    self.callbacks.onPaused(id, resumeData)
                }
            })
        }
    }

    func cancel(id: UUID) {
        stateQueue.async {
            guard let task = self.activeByID[id] else { return }
            task.cancel()
            self.activeByID[id] = nil
            self.idByTaskIdentifier[task.taskIdentifier] = nil
            self.pausingIDs.remove(id)
        }
    }
}

extension DownloadEngine: URLSessionDownloadDelegate {
    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didReceive response: URLResponse,
        completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
    ) {
        let id: UUID? = stateQueue.sync {
            idByTaskIdentifier[downloadTask.taskIdentifier]
        }

        guard let id else {
            completionHandler(.cancel)
            return
        }

        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            stateQueue.async {
                self.activeByID[id] = nil
                self.idByTaskIdentifier[downloadTask.taskIdentifier] = nil
                self.pausingIDs.remove(id)
            }

            Task { @MainActor in
                self.callbacks.onError(id, DownloadEngineError.httpStatus(code: http.statusCode))
            }
            downloadTask.cancel()
            completionHandler(.cancel)
            return
        }

        if let suggested = response.suggestedFilename, !suggested.isEmpty {
            Task { @MainActor in
                self.callbacks.onSuggestedFilename(id, suggested)
            }
        }

        completionHandler(.allow)
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let id: UUID? = stateQueue.sync {
            idByTaskIdentifier[downloadTask.taskIdentifier]
        }

        guard let id else { return }

        let expected: Int64? = totalBytesExpectedToWrite > 0 ? totalBytesExpectedToWrite : nil

        Task { @MainActor in
            self.callbacks.onProgress(id, totalBytesWritten, expected)
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        let id: UUID? = stateQueue.sync {
            idByTaskIdentifier[downloadTask.taskIdentifier]
        }

        guard let id else { return }

        stateQueue.async {
            self.activeByID[id] = nil
            self.idByTaskIdentifier[downloadTask.taskIdentifier] = nil
            self.pausingIDs.remove(id)
        }

        if let http = downloadTask.response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            try? FileManager.default.removeItem(at: location)
            Task { @MainActor in
                self.callbacks.onError(id, DownloadEngineError.httpStatus(code: http.statusCode))
            }
            return
        }

        Task { @MainActor in
            self.callbacks.onFinished(id, location)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }

        let id: UUID? = stateQueue.sync {
            idByTaskIdentifier[task.taskIdentifier]
        }

        guard let id else { return }

        let isPausing = stateQueue.sync { pausingIDs.contains(id) }
        if isPausing { return }

        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain, nsError.code == NSURLErrorCancelled {
            return
        }

        stateQueue.async {
            self.activeByID[id] = nil
            self.idByTaskIdentifier[task.taskIdentifier] = nil
            self.pausingIDs.remove(id)
        }

        Task { @MainActor in
            self.callbacks.onError(id, error)
        }
    }
}
