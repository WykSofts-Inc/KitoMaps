//
//  KitoRouteService.swift
//  KitoMaps
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import MapKit

/// A route between two places: the line to draw, how far and how long.
public struct KitoMapRoute: Sendable {
    public var coordinates: [CLLocationCoordinate2D]
    /// Metres.
    public var distance: CLLocationDistance
    /// Seconds.
    public var expectedTravelTime: TimeInterval
    public var name: String

    public init(coordinates: [CLLocationCoordinate2D], distance: CLLocationDistance? = nil,
                expectedTravelTime: TimeInterval, name: String = "") {
        self.coordinates = coordinates
        self.distance = distance ?? KitoMapGeometry.length(of: coordinates)
        self.expectedTravelTime = expectedTravelTime
        self.name = name
    }

    /// "1.2 km"
    public var formattedDistance: String { KitoMapFormat.distance(distance) }
    /// "12 min"
    public var formattedTravelTime: String { KitoMapFormat.duration(expectedTravelTime) }
}

/// How you're travelling.
public enum KitoTransport: Sendable {
    case automobile, walking, transit

    var mapKit: MKDirectionsTransportType {
        switch self {
        case .automobile: return .automobile
        case .walking: return .walking
        case .transit: return .transit
        }
    }
}

/// Directions from Apple Maps.
///
/// ```swift
/// let route = try await KitoRouteService.route(from: shop, to: home)
/// Text(route.formattedTravelTime)      // "12 min"
/// map.overlays([.route(route)])
/// ```
public enum KitoRouteService {
    public enum Failure: Error, Sendable {
        /// Apple Maps returned no route between these places.
        case noRoute
    }

    /// The fastest route, or the first of `alternatives` if asked for.
    public static func route(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D,
                             transport: KitoTransport = .automobile) async throws -> KitoMapRoute {
        guard let first = try await routes(from: origin, to: destination, transport: transport, alternatives: false).first else {
            throw Failure.noRoute
        }
        return first
    }

    /// Every route Apple Maps suggests, fastest first.
    public static func routes(from origin: CLLocationCoordinate2D, to destination: CLLocationCoordinate2D,
                              transport: KitoTransport = .automobile, alternatives: Bool = true) async throws -> [KitoMapRoute] {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: origin))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: destination))
        request.transportType = transport.mapKit
        request.requestsAlternateRoutes = alternatives
        let response = try await MKDirections(request: request).calculate()
        return response.routes
            .sorted { $0.expectedTravelTime < $1.expectedTravelTime }
            .map { KitoMapRoute(coordinates: $0.polyline.coordinates, distance: $0.distance,
                                expectedTravelTime: $0.expectedTravelTime, name: $0.name) }
    }
}

extension MKMultiPoint {
    /// Every point of the line as coordinates.
    var coordinates: [CLLocationCoordinate2D] {
        var result = [CLLocationCoordinate2D](repeating: kCLLocationCoordinate2DInvalid, count: pointCount)
        getCoordinates(&result, range: NSRange(location: 0, length: pointCount))
        return result
    }
}
