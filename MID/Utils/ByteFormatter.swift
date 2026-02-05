//
//  ByteFormatter.swift
//  MID
//
//  Created by mosab abudeeb on 05/02/2026.
//

import Foundation

enum ByteFormatter {
    private static let formatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowsNonnumericFormatting = false
        return f
    }()

    static func speed(_ bytesPerSecond: Double) -> String {
        guard bytesPerSecond.isFinite, bytesPerSecond > 0 else { return "—" }
        let bytes = Int64(bytesPerSecond)
        return formatter.string(fromByteCount: bytes) + "/s"
    }
}

