//
//  KitoRoutePath.swift
//  KitoMaps
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import CoreLocation

/// A path you can walk along: where you are after a distance, which way you face, and what's
/// behind and ahead. Used by `KitoLiveTracker`.
public struct KitoRoutePath: Sendable {
    public let coordinates: [CLLocationCoordinate2D]
    /// Distance from the start to each vertex, in metres.
    public let cumulativeDistances: [CLLocationDistance]

    public init(_ coordinates: [CLLocationCoordinate2D]) {
        self.coordinates = coordinates
        var running: CLLocationDistance = 0
        var distances: [CLLocationDistance] = coordinates.isEmpty ? [] : [0]
        for (a, b) in zip(coordinates, coordinates.dropFirst()) {
            running += KitoMapGeometry.distance(from: a, to: b)
            distances.append(running)
        }
        cumulativeDistances = distances
    }

    /// Length in metres.
    public var length: CLLocationDistance { cumulativeDistances.last ?? 0 }

    /// The position and heading `distance` metres from the start (clamped to the path).
    public func position(atDistance distance: CLLocationDistance) -> (coordinate: CLLocationCoordinate2D, bearing: Double)? {
        guard let first = coordinates.first else { return nil }
        guard coordinates.count > 1 else { return (first, 0) }
        let target = min(max(distance, 0), length)
        let segment = segmentIndex(containing: target)
        let a = coordinates[segment], b = coordinates[segment + 1]
        let start = cumulativeDistances[segment], span = cumulativeDistances[segment + 1] - start
        let fraction = span > 0 ? (target - start) / span : 0
        return (KitoMapGeometry.interpolate(from: a, to: b, fraction: fraction), KitoMapGeometry.bearing(from: a, to: b))
    }

    /// The position and heading at `fraction` (0…1) of the length.
    public func position(atFraction fraction: Double) -> (coordinate: CLLocationCoordinate2D, bearing: Double)? {
        position(atDistance: length * min(max(fraction, 0), 1))
    }

    /// The path up to `fraction` and the path after it; both include the split point.
    public func split(atFraction fraction: Double) -> (travelled: [CLLocationCoordinate2D], remaining: [CLLocationCoordinate2D]) {
        guard coordinates.count > 1, let point = position(atFraction: fraction)?.coordinate else { return (coordinates, coordinates) }
        let target = length * min(max(fraction, 0), 1)
        let segment = segmentIndex(containing: target)
        return (Array(coordinates[...segment]) + [point], [point] + Array(coordinates[(segment + 1)...]))
    }

    private func segmentIndex(containing distance: CLLocationDistance) -> Int {
        var low = 0, high = cumulativeDistances.count - 2
        while low < high {
            let mid = (low + high + 1) / 2
            if cumulativeDistances[mid] <= distance { low = mid } else { high = mid - 1 }
        }
        return max(0, low)
    }
}
