//
//  KitoPolyline.swift
//  KitoMaps
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import CoreLocation

/// The encoded polyline format used by Google, OSRM, Mapbox and most routing APIs.
///
/// ```swift
/// let path = KitoPolyline.decode(response.overviewPolyline)   // [CLLocationCoordinate2D]
/// ```
public enum KitoPolyline {
    /// Decodes an encoded polyline. `precision` is 5 for Google, 6 for OSRM/Valhalla `polyline6`.
    /// Returns `nil` for a malformed string.
    public static func decode(_ encoded: String, precision: Int = 5) -> [CLLocationCoordinate2D]? {
        let bytes = Array(encoded.utf8)
        let factor = pow(10, Double(precision))
        var index = 0, lat = 0, lon = 0
        var coordinates: [CLLocationCoordinate2D] = []

        func next() -> Int? {
            var result = 0, shift = 0
            while index < bytes.count {
                let byte = Int(bytes[index]) - 63
                index += 1
                guard byte >= 0, shift < 32 else { return nil }
                result |= (byte & 0x1F) << shift
                shift += 5
                if byte < 0x20 { return (result & 1) != 0 ? ~(result >> 1) : (result >> 1) }
            }
            return nil
        }

        while index < bytes.count {
            guard let dLat = next(), let dLon = next() else { return nil }
            lat += dLat
            lon += dLon
            coordinates.append(CLLocationCoordinate2D(latitude: Double(lat) / factor, longitude: Double(lon) / factor))
        }
        return coordinates
    }

    /// Encodes coordinates as a polyline string.
    public static func encode(_ coordinates: [CLLocationCoordinate2D], precision: Int = 5) -> String {
        let factor = pow(10, Double(precision))
        var output = ""
        var lastLat = 0, lastLon = 0

        func append(_ value: Int) {
            var v = value < 0 ? ~(value << 1) : (value << 1)
            while v >= 0x20 {
                output.unicodeScalars.append(Unicode.Scalar(UInt8((0x20 | (v & 0x1F)) + 63)))
                v >>= 5
            }
            output.unicodeScalars.append(Unicode.Scalar(UInt8(v + 63)))
        }

        for coordinate in coordinates {
            let lat = Int((coordinate.latitude * factor).rounded()), lon = Int((coordinate.longitude * factor).rounded())
            append(lat - lastLat)
            append(lon - lastLon)
            lastLat = lat
            lastLon = lon
        }
        return output
    }
}
