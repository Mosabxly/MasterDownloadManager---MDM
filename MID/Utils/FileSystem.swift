//
//  FileSystem.swift
//  MID
//
//  Created by mosab abudeeb on 05/02/2026.
//

import Foundation

enum FileSystem {
    static func ensureDirectoryExists(_ folder: URL) throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: nil)
    }

    static func uniqueDestinationURL(in folder: URL, fileName: String) -> URL {
        let baseURL = folder.appendingPathComponent(fileName)
        if !FileManager.default.fileExists(atPath: baseURL.path) {
            return baseURL
        }

        let ext = baseURL.pathExtension
        let stem = baseURL.deletingPathExtension().lastPathComponent

        for i in 1...999 {
            let candidateName = ext.isEmpty ? "\(stem) (\(i))" : "\(stem) (\(i)).\(ext)"
            let candidate = folder.appendingPathComponent(candidateName)
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }

        let suffix = ext.isEmpty ? "" : ".\(ext)"
        return folder.appendingPathComponent(UUID().uuidString + suffix)
    }

    static func moveItemReplacingIfNeeded(from source: URL, to destination: URL) throws {
        if FileManager.default.fileExists(atPath: destination.path) {
            _ = try FileManager.default.replaceItemAt(destination, withItemAt: source)
            return
        }
        try FileManager.default.moveItem(at: source, to: destination)
    }
}

