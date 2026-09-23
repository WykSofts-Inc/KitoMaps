//
//  KitoClusterer.swift
//  KitoMaps
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import CoreLocation
import SwiftUI

/// One thing to draw: a single pin, or a cluster of nearby pins.
public struct KitoMapCluster: Identifiable, Equatable, Sendable {
    /// A single pin keeps its own id; a cluster is named after its first member, so it keeps its
    /// identity while pins join or leave.
    public let id: String
    public let coordinate: CLLocationCoordinate2D
    /// Members, sorted by id.
    public let pins: [KitoMapPin]

    public var count: Int { pins.count }
    /// The pin, when this is not a cluster.
    public var pin: KitoMapPin? { pins.count == 1 ? pins.first : nil }
    public var isCluster: Bool { pins.count > 1 }

    public init(pins: [KitoMapPin]) {
        let sorted = pins.sorted { $0.id < $1.id }
        self.pins = sorted
        if sorted.count == 1, let only = sorted.first {
            id = only.id
            coordinate = only.coordinate
        } else {
            id = "cluster:" + (sorted.first?.id ?? "")
            let count = Double(max(sorted.count, 1))
            coordinate = CLLocationCoordinate2D(latitude: sorted.reduce(0) { $0 + $1.coordinate.latitude } / count,
                                                longitude: sorted.reduce(0) { $0 + $1.coordinate.longitude } / count)
        }
    }

    public static func == (lhs: KitoMapCluster, rhs: KitoMapCluster) -> Bool {
        lhs.id == rhs.id && lhs.pins == rhs.pins
    }
}

/// Groups pins that would overlap at a zoom level. Deterministic: the grid is anchored to the
/// world, not the screen, so panning never reshuffles clusters, and the zoom is floored so they
/// only change when you cross a zoom level.
public struct KitoClusterer: Equatable, Sendable {
    /// Grid cell size in points. Pins sharing a cell merge.
    public var cellSize: Double
    /// The fewest pins that form a cluster.
    public var minimumClusterSize: Int
    /// At and beyond this zoom nothing clusters.
    public var maximumZoom: Double

    public init(cellSize: Double = 64, minimumClusterSize: Int = 2, maximumZoom: Double = 18) {
        self.cellSize = max(cellSize, 1)
        self.minimumClusterSize = max(minimumClusterSize, 2)
        self.maximumZoom = maximumZoom
    }

    /// Clusters `pins` at `zoom` (256-point tiles). `excluding` stays a single pin — use it for
    /// the selected pin so it is always visible. Output is sorted by id.
    public func clusters(for pins: [KitoMapPin], zoom: Double, excluding excludedID: String? = nil) -> [KitoMapCluster] {
        let level = floor(max(zoom, 0))
        guard level < maximumZoom else { return pins.map { KitoMapCluster(pins: [$0]) }.sorted { $0.id < $1.id } }
        let worldSize = 256 * pow(2, level)
        var cells: [Cell: [KitoMapPin]] = [:]
        var result: [KitoMapCluster] = []
        for pin in pins {
            if pin.id == excludedID { result.append(KitoMapCluster(pins: [pin])); continue }
            let point = KitoMapGeometry.project(pin.coordinate, worldSize: worldSize)
            cells[Cell(x: Int(floor(Double(point.x) / cellSize)), y: Int(floor(Double(point.y) / cellSize))), default: []].append(pin)
        }
        for members in cells.values {
            if members.count >= minimumClusterSize {
                result.append(KitoMapCluster(pins: members))
            } else {
                result.append(contentsOf: members.map { KitoMapCluster(pins: [$0]) })
            }
        }
        return result.sorted { $0.id < $1.id }
    }

    /// For each item in `new`, the coordinate of the bigger cluster it split out of in `old`, so
    /// the view can fly it out from there. Items that didn't come from a cluster are absent.
    public static func splitOrigins(from old: [KitoMapCluster], to new: [KitoMapCluster]) -> [String: CLLocationCoordinate2D] {
        var parent: [String: KitoMapCluster] = [:]
        for cluster in old where cluster.isCluster {
            for pin in cluster.pins { parent[pin.id] = cluster }
        }
        var origins: [String: CLLocationCoordinate2D] = [:]
        for item in new {
            guard let lead = item.pins.first, let from = parent[lead.id], from.count > item.count else { continue }
            origins[item.id] = from.coordinate
        }
        return origins
    }

    private struct Cell: Hashable { let x: Int; let y: Int }
}

/// What changed between two clusterings, with where things fly from and to — used by the
/// Google Maps and MapLibre views to animate splits and merges.
@_spi(KitoMapsProvider)
public struct KitoClusterDiff {
    /// Items that are new, in id order.
    public let inserted: [KitoMapCluster]
    /// Items that went away.
    public let removed: [KitoMapCluster]
    /// Items present before and after (their new version).
    public let kept: [KitoMapCluster]
    /// Inserted item id → the cluster it split out of.
    public let origins: [String: CLLocationCoordinate2D]
    /// Removed item id → the cluster it merged into.
    public let mergeTargets: [String: CLLocationCoordinate2D]

    public init(from old: [KitoMapCluster], to new: [KitoMapCluster]) {
        let oldIDs = Set(old.map(\.id)), newIDs = Set(new.map(\.id))
        inserted = new.filter { !oldIDs.contains($0.id) }
        kept = new.filter { oldIDs.contains($0.id) }
        removed = old.filter { !newIDs.contains($0.id) }
        origins = KitoClusterer.splitOrigins(from: old, to: inserted)
        var parent: [String: KitoMapCluster] = [:]
        for cluster in new where cluster.isCluster {
            for pin in cluster.pins { parent[pin.id] = cluster }
        }
        var targets: [String: CLLocationCoordinate2D] = [:]
        for item in removed {
            guard let lead = item.pins.first, let into = parent[lead.id], into.count > item.count else { continue }
            targets[item.id] = into.coordinate
        }
        mergeTargets = targets
    }
}

extension KitoMapCluster {
    /// Changes whenever the item needs a new image.
    @_spi(KitoMapsProvider) public func visualKey(selected: Bool) -> String {
        guard let pin else {
            let tint = pins.first?.tint.map { "\($0)" } ?? "-"
            return "cluster|\(count)|\(pins.allSatisfy { $0.tint == pins.first?.tint } ? tint : "-")"
        }
        let heading = pin.heading.map { "\(Int(($0 / 3).rounded()) * 3)" } ?? "-"
        return [pin.title, "\(pin.style)", pin.tint.map { "\($0)" } ?? "-", pin.badge ?? "-", pin.systemImage ?? "-", heading,
                selected ? "s" : "n"].joined(separator: "|")
    }

    /// The members' tint when they all share one.
    @_spi(KitoMapsProvider) public var sharedTint: Color? {
        guard let first = pins.first?.tint, pins.allSatisfy({ $0.tint == first }) else { return nil }
        return first
    }
}
