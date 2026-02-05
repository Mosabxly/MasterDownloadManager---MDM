//
//  TimeFormatter.swift
//  MID
//
//  Created by mosab abudeeb on 05/02/2026.
//

import Foundation

enum TimeFormatter {
    static func compact(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "—" }

        var remaining = Int(seconds.rounded(.toNearestOrAwayFromZero))
        let hours = remaining / 3600
        remaining %= 3600
        let minutes = remaining / 60
        let secs = remaining % 60

        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes > 0 { return "\(minutes)m \(secs)s" }
        return "\(secs)s"
    }
}

