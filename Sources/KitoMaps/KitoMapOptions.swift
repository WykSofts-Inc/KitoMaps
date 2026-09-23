//
//  KitoMapOptions.swift
//  KitoMaps
//
//  Created by Wycliff on 9/23/26.
//  Copyright © 2026 wyksoftsinc.com. All rights reserved.
//

import SwiftUI
import CoreLocation
import Observation

/// The floating buttons a map shows.
public struct KitoMapControls: OptionSet, Sendable {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }

    /// Centre on the user (asks for location permission the first time).
    public static let userLocation = KitoMapControls(rawValue: 1 << 0)
    /// A menu of map styles.
    public static let styleSwitcher = KitoMapControls(rawValue: 1 << 1)
    /// Tilt into 3D and back.
    public static let pitch = KitoMapControls(rawValue: 1 << 2)
    /// Frame every pin again.
    public static let fitAll = KitoMapControls(rawValue: 1 << 3)

    public static let all: KitoMapControls = [.userLocation, .styleSwitcher, .pitch, .fitAll]
}

/// Where the camera goes.
public enum KitoMapCamera: Sendable {
    /// Frame every pin, clear of the controls and cards.
    case fitPins
    /// Frame these coordinates.
    case fit([CLLocationCoordinate2D])
    /// Centre on a coordinate at a zoom level (about 3 = a continent, 11 = a city, 16 = streets).
    case center(CLLocationCoordinate2D, zoom: Double)
    /// Centre on the user, if location is allowed.
    case userLocation(zoom: Double)
}

/// Settings shared by every provider's map view. Set them with the modifiers on
/// `KitoMapConfigurable` — `.clustering()`, `.overlays(_:)`, `.controls(_:)` and friends.
public struct KitoMapOptions: Equatable, Sendable {
    public var clusterer: KitoClusterer? = nil
    public var overlays: [KitoMapOverlay] = []
    public var showsUserLocation = false
    public var controls: KitoMapControls = [.userLocation, .fitAll]
    /// Extra room around fitted pins; the card carousel's height is added to the bottom.
    public var fitPadding = EdgeInsets(top: 72, leading: 48, bottom: 48, trailing: 64)
    /// Pan to the selected pin when the selection changes.
    public var followsSelection = true
    /// Start tilted in 3D.
    public var startsIn3D = false

    public init() {}

    public static func == (lhs: KitoMapOptions, rhs: KitoMapOptions) -> Bool {
        lhs.clusterer == rhs.clusterer && lhs.overlays == rhs.overlays && lhs.showsUserLocation == rhs.showsUserLocation
            && lhs.controls == rhs.controls && lhs.fitPadding == rhs.fitPadding
            && lhs.followsSelection == rhs.followsSelection && lhs.startsIn3D == rhs.startsIn3D
    }
}

/// The modifiers every Kito map view shares, so switching provider is a one-line change.
public protocol KitoMapConfigurable {
    var options: KitoMapOptions { get set }
}

public extension KitoMapConfigurable {
    /// Merge nearby pins into count bubbles that split apart as you zoom in.
    func clustering(_ enabled: Bool = true, cellSize: Double = 64) -> Self {
        var copy = self
        copy.options.clusterer = enabled ? KitoClusterer(cellSize: cellSize) : nil
        return copy
    }

    /// Routes, trails and circles drawn under the pins.
    func overlays(_ overlays: [KitoMapOverlay]) -> Self {
        var copy = self
        copy.options.overlays = overlays
        return copy
    }

    /// Show the blue user-location dot. Needs `NSLocationWhenInUseUsageDescription`.
    func showsUserLocation(_ shows: Bool = true) -> Self {
        var copy = self
        copy.options.showsUserLocation = shows
        return copy
    }

    /// The floating buttons. Defaults to `[.userLocation, .fitAll]`; `[]` hides them.
    func controls(_ controls: KitoMapControls) -> Self {
        var copy = self
        copy.options.controls = controls
        return copy
    }

    /// Room kept clear around fitted pins.
    func fitPadding(_ padding: EdgeInsets) -> Self {
        var copy = self
        copy.options.fitPadding = padding
        return copy
    }

    /// Whether the camera pans to a newly selected pin (default `true`).
    func followsSelection(_ follows: Bool) -> Self {
        var copy = self
        copy.options.followsSelection = follows
        return copy
    }

    /// Start tilted in 3D.
    func startsIn3D(_ enabled: Bool = true) -> Self {
        var copy = self
        copy.options.startsIn3D = enabled
        return copy
    }
}

/// Moves a map's camera from outside and reports where it is.
///
/// ```swift
/// @State private var map = KitoMapController()
/// KitoMapView(pins: pins, controller: map)
/// Button("Show all") { map.move(to: .fitPins) }
/// ```
@MainActor
@Observable
public final class KitoMapController {
    /// The centre of the map, updated as it moves.
    public private(set) var center: CLLocationCoordinate2D?
    /// The zoom level (256-point tiles), updated as it moves.
    public private(set) var zoom: Double = 0

    private var pending: KitoCameraRequest?
    private var nextID = 0

    /// The latest camera move asked for; map views watch it.
    @_spi(KitoMapsProvider) public var request: KitoCameraRequest? { pending }

    public init() {}

    /// Animates to `camera` (instantly when Reduce Motion is on).
    public func move(to camera: KitoMapCamera, animated: Bool = true) {
        nextID += 1
        pending = KitoCameraRequest(id: nextID, camera: camera, animated: animated)
    }

    /// Centres on a pin.
    public func focus(on pin: KitoMapPin, zoom: Double = 16) {
        move(to: .center(pin.coordinate, zoom: zoom))
    }

    @_spi(KitoMapsProvider) public func report(center: CLLocationCoordinate2D, zoom: Double) {
        self.center = center
        self.zoom = zoom
    }
}

@_spi(KitoMapsProvider)
public struct KitoCameraRequest: Sendable, Equatable {
    public let id: Int
    public let camera: KitoMapCamera
    public let animated: Bool

    public static func == (lhs: KitoCameraRequest, rhs: KitoCameraRequest) -> Bool { lhs.id == rhs.id }
}

/// A provider's map style, listed in the style switcher.
public protocol KitoMapStyleOption: Hashable, Sendable {
    /// The styles offered in the switcher.
    static var presets: [Self] { get }
    var title: String { get }
    var systemImage: String { get }
}
