//
//  KitoMapOverlay.swift
//  KitoMaps
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import CoreLocation

/// A line or a circle drawn under the pins: a route, a trail, a delivery radius or a geofence.
///
/// ```swift
/// .overlays([
///     .route(route, color: .blue),
///     .circle(center: store, radius: 2_000, color: .green),
/// ])
/// ```
public struct KitoMapOverlay: Identifiable, Equatable, Sendable {
    public enum Shape: Equatable, Sendable {
        case polyline([CLLocationCoordinate2D])
        case circle(center: CLLocationCoordinate2D, radius: CLLocationDistance)

        public static func == (lhs: Shape, rhs: Shape) -> Bool {
            switch (lhs, rhs) {
            case let (.polyline(a), .polyline(b)):
                return a.count == b.count && zip(a, b).allSatisfy { $0.latitude == $1.latitude && $0.longitude == $1.longitude }
            case let (.circle(c1, r1), .circle(c2, r2)):
                return c1.latitude == c2.latitude && c1.longitude == c2.longitude && r1 == r2
            default:
                return false
            }
        }
    }

    public var id: String
    public var shape: Shape
    public var color: Color
    public var lineWidth: CGFloat
    public var isDashed: Bool

    public init(id: String, shape: Shape, color: Color, lineWidth: CGFloat = 5, isDashed: Bool = false) {
        self.id = id
        self.shape = shape
        self.color = color
        self.lineWidth = lineWidth
        self.isDashed = isDashed
    }

    /// A line through `coordinates`.
    public static func polyline(_ coordinates: [CLLocationCoordinate2D], id: String = "polyline",
                                color: Color = .blue, lineWidth: CGFloat = 5, dashed: Bool = false) -> KitoMapOverlay {
        KitoMapOverlay(id: id, shape: .polyline(coordinates), color: color, lineWidth: lineWidth, isDashed: dashed)
    }

    /// A route from `KitoRouteService`.
    public static func route(_ route: KitoMapRoute, id: String = "route", color: Color = .blue, lineWidth: CGFloat = 6) -> KitoMapOverlay {
        .polyline(route.coordinates, id: id, color: color, lineWidth: lineWidth)
    }

    /// A filled circle with an outline, `radius` metres around `center`.
    public static func circle(center: CLLocationCoordinate2D, radius: CLLocationDistance, id: String = "circle",
                              color: Color = .blue, lineWidth: CGFloat = 2) -> KitoMapOverlay {
        KitoMapOverlay(id: id, shape: .circle(center: center, radius: radius), color: color, lineWidth: lineWidth)
    }
}
