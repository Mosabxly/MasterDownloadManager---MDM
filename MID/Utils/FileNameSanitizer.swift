//
//  FileNameSanitizer.swift
//  MID
//
//  Created by mosab abudeeb on 05/02/2026.
//

import Foundation

enum FileNameSanitizer {
    static func sanitize(_ fileName: String, fallback: String) -> String {
        let trimmed = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? fallback : trimmed

        let invalidCharacters = CharacterSet(charactersIn: "/:\\").union(.controlCharacters)
        let cleaned = base
            .components(separatedBy: invalidCharacters)
            .filter { !$0.isEmpty }
            .joined(separator: "_")

        let collapsed = cleaned.replacingOccurrences(of: "__", with: "_")
        let final = collapsed.isEmpty ? fallback : collapsed

        // Keep a conservative length to avoid filesystem/path issues.
        return String(final.prefix(180))
    }

    static func fallbackName(extension ext: String? = nil) -> String {
        let ts = Int(Date().timeIntervalSince1970)
        if let ext, !ext.isEmpty {
            return "download-\(ts).\(ext)"
        }
        return "download-\(ts)"
    }
}

