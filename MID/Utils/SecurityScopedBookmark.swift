//
//  SecurityScopedBookmark.swift
//  MID
//
//  Created by mosab abudeeb on 05/02/2026.
//

import Foundation

enum SecurityScopedBookmark {
    struct Resolution {
        let url: URL
        let refreshedBookmarkData: Data?
    }

    static func create(for url: URL) throws -> Data {
        try url.standardizedFileURL.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
    }

    static func resolve(_ bookmarkData: Data) -> Resolution? {
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )

            if isStale {
                let refreshed = try create(for: url)
                return Resolution(url: url, refreshedBookmarkData: refreshed)
            }

            return Resolution(url: url, refreshedBookmarkData: nil)
        } catch {
            return nil
        }
    }

    static func withAccess<T>(to url: URL, _ work: () throws -> T) rethrows -> T {
        let didStart = url.startAccessingSecurityScopedResource()
        defer { if didStart { url.stopAccessingSecurityScopedResource() } }
        return try work()
    }

    static func withAccess<T>(
        to location: SaveLocation,
        _ work: (URL) throws -> T
    ) rethrows -> (result: T, refreshedLocation: SaveLocation?) {
        guard let data = location.bookmarkData else {
            let value = try work(location.folder)
            return (value, nil)
        }

        guard let resolution = resolve(data) else {
            let value = try work(location.folder)
            return (value, nil)
        }

        let value = try withAccess(to: resolution.url) {
            try work(resolution.url)
        }

        if let refreshed = resolution.refreshedBookmarkData {
            return (value, SaveLocation(folder: resolution.url, bookmarkData: refreshed))
        }

        return (value, nil)
    }
}

