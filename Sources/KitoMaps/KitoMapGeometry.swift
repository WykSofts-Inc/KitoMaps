//
//  KitoMapGeometry.swift
//  KitoMaps
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import CoreLocation
import MapKit

/// Map maths shared by every provider: distances, bearings, zoom levels and camera fitting.
///
/// Zoom levels follow the 256-point tile convention used by Google Maps (MapLibre's `zoomLevel`
/// is one less for the same scale).
public enum KitoMapGeometry {
    /// Mean Earth radius in metres.
    public static let earthRadius: Double = 6_371_008.8

    // MARK: Distance and direction

    /// Great-circle distance in metres.
    public static func distance(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> CLLocationDistance {
        let lat1 = a.latitude.radians, lat2 = b.latitude.radians
        let dLat = (b.latitude - a.latitude).radians, dLon = (b.longitude - a.longitude).radians
        let h = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2)
        return 2 * earthRadius * asin(min(1, sqrt(h)))
    }

    /// Initial compass bearing from `a` to `b`, 0…360 degrees clockwise from north.
    public static func bearing(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D) -> Double {
        let lat1 = a.latitude.radians, lat2 = b.latitude.radians
        let dLon = (b.longitude - a.longitude).radians
        let y = sin(dLon) * cos(lat2)
        let x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon)
        return normalizedDegrees(atan2(y, x).degrees)
    }

    /// The point `fraction` (0…1) of the way from `a` to `b`, interpolated linearly.
    public static func interpolate(from a: CLLocationCoordinate2D, to b: CLLocationCoordinate2D, fraction: Double) -> CLLocationCoordinate2D {
        let t = min(max(fraction, 0), 1)
        return CLLocationCoordinate2D(latitude: a.latitude + (b.latitude - a.latitude) * t,
                                      longitude: a.longitude + (b.longitude - a.longitude) * t)
    }

    /// Interpolates between two headings the short way round, e.g. 350° → 10° passes 0°.
    public static func interpolateAngle(from a: Double, to b: Double, fraction: Double) -> Double {
        var delta = (b - a).truncatingRemainder(dividingBy: 360)
        if delta > 180 { delta -= 360 }
        if delta < -180 { delta += 360 }
        return normalizedDegrees(a + delta * min(max(fraction, 0), 1))
    }

    /// Wraps any angle into 0..<360.
    public static func normalizedDegrees(_ degrees: Double) -> Double {
        let value = degrees.truncatingRemainder(dividingBy: 360)
        return value < 0 ? value + 360 : value
    }

    /// Total length of a path in metres.
    public static func length(of path: [CLLocationCoordinate2D]) -> CLLocationDistance {
        zip(path, path.dropFirst()).reduce(0) { $0 + distance(from: $1.0, to: $1.1) }
    }

    /// A closed ring approximating a circle, for providers that draw circles as polygons.
    public static func circle(center: CLLocationCoordinate2D, radius: CLLocationDistance, segments: Int = 64) -> [CLLocationCoordinate2D] {
        let count = max(segments, 8)
        let angular = radius / earthRadius
        let lat1 = center.latitude.radians, lon1 = center.longitude.radians
        return (0...count).map { index in
            let bearing = Double(index) / Double(count) * 2 * .pi
            let lat2 = asin(sin(lat1) * cos(angular) + cos(lat1) * sin(angular) * cos(bearing))
            let lon2 = lon1 + atan2(sin(bearing) * sin(angular) * cos(lat1), cos(angular) - sin(lat1) * sin(lat2))
            return CLLocationCoordinate2D(latitude: lat2.degrees, longitude: lon2.degrees)
        }
    }

    // MARK: Zoom

    /// The zoom level that shows `longitudeDelta` degrees across `width` points.
    public static func zoom(longitudeDelta: Double, width: Double) -> Double {
        guard longitudeDelta > 0, width > 0 else { return 0 }
        return log2(360 * width / (256 * longitudeDelta))
    }

    /// The longitude span visible across `width` points at `zoom`.
    public static func longitudeDelta(zoom: Double, width: Double) -> Double {
        360 * max(width, 1) / (256 * pow(2, zoom))
    }

    /// A region centred on `center` at `zoom` for a view of `size`.
    public static func region(center: CLLocationCoordinate2D, zoom: Double, size: CGSize) -> MKCoordinateRegion {
        let lonDelta = min(longitudeDelta(zoom: zoom, width: Double(size.width)), 360)
        let aspect = size.width > 0 ? Double(size.height / size.width) : 1
        let latDelta = min(lonDelta * aspect * max(cos(center.latitude.radians), 0.01), 180)
        return MKCoordinateRegion(center: center, span: MKCoordinateSpan(latitudeDelta: latDelta, longitudeDelta: lonDelta))
    }

    // MARK: Projection

    /// Web Mercator position in points of a world `worldSize` points wide, origin top-left.
    public static func project(_ coordinate: CLLocationCoordinate2D, worldSize: Double) -> CGPoint {
        let lat = min(max(coordinate.latitude, -85.05112878), 85.05112878).radians
        let x = (coordinate.longitude + 180) / 360 * worldSize
        let y = (1 - log(tan(lat) + 1 / cos(lat)) / .pi) / 2 * worldSize
        return CGPoint(x: x, y: y)
    }

    // MARK: Fitting

    /// A region that contains every coordinate, grown by `paddingFactor` (1.2 = 20% larger), and at
    /// least `minimumSpan` degrees tall and wide. `nil` for no coordinates.
    public static func region(fitting coordinates: [CLLocationCoordinate2D], paddingFactor: Double = 1.25, minimumSpan: Double = 0.01) -> MKCoordinateRegion? {
        guard let first = coordinates.first else { return nil }
        var minLat = first.latitude, maxLat = first.latitude, minLon = first.longitude, maxLon = first.longitude
        for coordinate in coordinates.dropFirst() {
            minLat = min(minLat, coordinate.latitude); maxLat = max(maxLat, coordinate.latitude)
            minLon = min(minLon, coordinate.longitude); maxLon = max(maxLon, coordinate.longitude)
        }
        let factor = max(paddingFactor, 1)
        let span = MKCoordinateSpan(latitudeDelta: min(max((maxLat - minLat) * factor, minimumSpan), 180),
                                    longitudeDelta: min(max((maxLon - minLon) * factor, minimumSpan), 360))
        return MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: (minLat + maxLat) / 2, longitude: (minLon + maxLon) / 2), span: span)
    }

    /// A map rect with the view's aspect ratio that shows every coordinate inside the part of a
    /// `size` view left clear by `padding` — e.g. above a card carousel. `nil` for no coordinates.
    public static func mapRect(fitting coordinates: [CLLocationCoordinate2D], in size: CGSize, padding: EdgeInsets,
                               minimumSize: Double = 1_500) -> MKMapRect? {
        guard !coordinates.isEmpty, size.width > 0, size.height > 0 else { return nil }
        let points = coordinates.map(MKMapPoint.init)
        let minX = points.map(\.x).min() ?? 0, maxX = points.map(\.x).max() ?? 0
        let minY = points.map(\.y).min() ?? 0, maxY = points.map(\.y).max() ?? 0
        let minimum = minimumSize * MKMapPointsPerMeterAtLatitude(coordinates[0].latitude)
        let contentWidth = max(maxX - minX, minimum), contentHeight = max(maxY - minY, minimum)
        let availableWidth = max(Double(size.width - padding.leading - padding.trailing), 1)
        let availableHeight = max(Double(size.height - padding.top - padding.bottom), 1)
        let scale = max(contentWidth / availableWidth, contentHeight / availableHeight)
        let midX = (minX + maxX) / 2, midY = (minY + maxY) / 2
        let originX = midX - (Double(padding.leading) + availableWidth / 2) * scale
        let originY = midY - (Double(padding.top) + availableHeight / 2) * scale
        return MKMapRect(x: originX, y: originY, width: Double(size.width) * scale, height: Double(size.height) * scale)
    }
}

extension Double {
    var radians: Double { self * .pi / 180 }
    var degrees: Double { self * 180 / .pi }
}
