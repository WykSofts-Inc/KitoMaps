//
//  KitoMapFormat.swift
//  KitoMaps
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import Foundation

/// Short, glanceable distance and time strings: "850 m", "1.2 km", "12 min", "1 h 5 min".
public enum KitoMapFormat {
    public enum Units: Sendable { case metric, imperial }

    /// A rounded distance. Metric: "45 m", "850 m", "1.2 km", "12 km". Imperial: "300 ft", "0.5 mi", "12 mi".
    public static func distance(_ meters: Double, units: Units = .metric) -> String {
        let meters = max(meters, 0)
        switch units {
        case .metric:
            if meters < 100 { return "\(Int((meters / 5).rounded() * 5)) m" }
            if meters < 995 { return "\(Int((meters / 10).rounded() * 10)) m" }
            let km = meters / 1000
            return km < 9.95 ? "\(oneDecimal(km)) km" : "\(Int(km.rounded())) km"
        case .imperial:
            let feet = meters * 3.28084
            if feet < 1000 { return "\(Int((feet / 10).rounded() * 10)) ft" }
            let miles = meters / 1609.344
            return miles < 9.95 ? "\(oneDecimal(miles)) mi" : "\(Int(miles.rounded())) mi"
        }
    }

    /// A travel time rounded up to the minute: "1 min", "12 min", "1 h", "1 h 5 min".
    public static func duration(_ seconds: TimeInterval) -> String {
        let minutes = max(1, Int((max(seconds, 0) / 60).rounded(.up)))
        if minutes < 60 { return "\(minutes) min" }
        let hours = minutes / 60, rest = minutes % 60
        return rest == 0 ? "\(hours) h" : "\(hours) h \(rest) min"
    }

    /// A mm:ss countdown, or h:mm:ss past an hour: "04:05", "1:02:03".
    public static func countdown(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.up)))
        let h = total / 3600, m = (total % 3600) / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }

    /// The clock time after `seconds` from `now`, e.g. "14:32" or "2:32 PM" depending on `locale`.
    public static func arrivalTime(after seconds: TimeInterval, from now: Date = Date(),
                                   locale: Locale = .current, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: now.addingTimeInterval(max(seconds, 0)))
    }

    /// "1.2 km · 12 min".
    public static func summary(distance meters: Double, duration seconds: TimeInterval, units: Units = .metric) -> String {
        "\(distance(meters, units: units)) · \(duration(seconds))"
    }

    private static func oneDecimal(_ value: Double) -> String {
        let tenths = Int((value * 10).rounded())
        return "\(tenths / 10).\(tenths % 10)"
    }
}
