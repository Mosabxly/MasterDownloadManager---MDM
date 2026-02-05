//
//  SaveLocationManager.swift
//  MID
//
//  Created by mosab abudeeb on 05/02/2026.
//

import Foundation
import Combine

@MainActor
final class SaveLocationManager: ObservableObject {
    @Published private(set) var defaultLocation: SaveLocation

    private let defaultBookmarkKey = "SaveLocationManager.defaultFolderBookmark"

    init() {
        if let data = UserDefaults.standard.data(forKey: defaultBookmarkKey),
           let resolved = SecurityScopedBookmark.resolve(data) {
            self.defaultLocation = SaveLocation(folder: resolved.url, bookmarkData: resolved.refreshedBookmarkData ?? data)

            if let refreshed = resolved.refreshedBookmarkData {
                UserDefaults.standard.set(refreshed, forKey: defaultBookmarkKey)
            }
        } else {
            self.defaultLocation = SaveLocation(folder: Self.defaultDownloadsFolder(), bookmarkData: nil)
        }
    }

    func setDefaultFolder(_ folder: URL) throws {
        let location = try makeLocation(for: folder)
        if let data = location.bookmarkData {
            UserDefaults.standard.set(data, forKey: defaultBookmarkKey)
        } else {
            UserDefaults.standard.removeObject(forKey: defaultBookmarkKey)
        }
        defaultLocation = location
    }

    func makeLocation(for folder: URL) throws -> SaveLocation {
        let standardized = folder.standardizedFileURL

        // For app-internal folders, a security-scoped bookmark is unnecessary.
        if Self.isAppWritableWithoutBookmark(standardized) {
            return SaveLocation(folder: standardized, bookmarkData: nil)
        }

        let bookmark = try SecurityScopedBookmark.create(for: standardized)
        return SaveLocation(folder: standardized, bookmarkData: bookmark)
    }

    func withSecurityScopedAccess<T>(
        to location: SaveLocation,
        _ work: (URL) throws -> T
    ) rethrows -> (result: T, refreshedLocation: SaveLocation?) {
        try SecurityScopedBookmark.withAccess(to: location, work)
    }

    private static func defaultDownloadsFolder() -> URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let bundleID = Bundle.main.bundleIdentifier ?? "MID"
        return (appSupport ?? FileManager.default.temporaryDirectory)
            .appendingPathComponent(bundleID, isDirectory: true)
            .appendingPathComponent("Downloads", isDirectory: true)
    }

    private static func isAppWritableWithoutBookmark(_ url: URL) -> Bool {
        let container = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        guard let container else { return false }
        return url.standardizedFileURL.path.hasPrefix(container.standardizedFileURL.path)
    }

    // Bookmark resolution handled by SecurityScopedBookmark.
}
